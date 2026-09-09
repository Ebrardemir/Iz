using Iz.Application.Sync;
using Iz.Domain.Sync;
using Microsoft.EntityFrameworkCore;

namespace Iz.Infrastructure.Persistence;

/// <inheritdoc cref="ISyncStore"/>
/// <remarks>
/// TÜR → TABLO DAĞITIMI ELLE YAZILI. Yansımayla <c>DbSet</c> bulmak
/// mümkündü; yapmadık çünkü bağların anahtar SIRASI (hangi sütun önce)
/// yansımayla görünmüyor ve bir kez ters yazılırsa aynı bağ iki farklı
/// kimlikle aranır — bulunamaz, ikinci bir satır açılır. Sıra burada
/// <c>SyncId</c> ile yan yana duruyor, karşılaştırılabiliyor.
///
/// SORGULARDA <c>IgnoreQueryFilters</c> YOK ve bu bilinçli: global sahiplik
/// süzgeci burada IDOR'a karşı ikinci hat (§7.2). Başka bir kullanıcının
/// kimliğiyle gelen push, kaydı "bulamaz" ve kendi hesabında YENİ bir kayıt
/// açar — kurbanın satırına dokunamaz.
///
/// Tombstone'lar SÜZÜLMÜYOR: silinmiş satırı gizleseydik push onu "yok"
/// sanar, yenisini açardı ve kullanıcının sildiği kayıt geri gelirdi.
/// </remarks>
internal sealed class SyncStore(IzDbContext context) : ISyncStore
{
    public async Task<ISyncable?> FindAsync(
        SyncEntityMapper mapper,
        SyncEntityKey key,
        CancellationToken cancellationToken)
    {
        var parent = key.Primary;
        var child = key.Secondary ?? Guid.Empty;

        return mapper.EntityType switch
        {
            SyncEntityTypes.Memory =>
                await context.Memories
                    .FirstOrDefaultAsync(e => e.Id == parent, cancellationToken),
            SyncEntityTypes.JournalEntry =>
                await context.JournalEntries
                    .FirstOrDefaultAsync(e => e.Id == parent, cancellationToken),
            SyncEntityTypes.Person =>
                await context.People
                    .FirstOrDefaultAsync(e => e.Id == parent, cancellationToken),
            SyncEntityTypes.Category =>
                await context.Categories
                    .FirstOrDefaultAsync(e => e.Id == parent, cancellationToken),
            SyncEntityTypes.Collection =>
                await context.Collections
                    .FirstOrDefaultAsync(e => e.Id == parent, cancellationToken),
            SyncEntityTypes.Ritual =>
                await context.Rituals
                    .FirstOrDefaultAsync(e => e.Id == parent, cancellationToken),
            SyncEntityTypes.Location =>
                await context.Locations
                    .FirstOrDefaultAsync(e => e.Id == parent, cancellationToken),
            SyncEntityTypes.MediaItem =>
                await context.MediaItems
                    .FirstOrDefaultAsync(e => e.Id == parent, cancellationToken),

            // BAĞLARDA SÜTUN SIRASI `SyncId` İLE AYNI olmak zorunda.
            SyncEntityTypes.MemoryPeople =>
                await context.MemoryPeople
                    .FirstOrDefaultAsync(
                        l => l.MemoryId == parent && l.PersonId == child, cancellationToken),
            SyncEntityTypes.MemoryCollections =>
                await context.MemoryCollections
                    .FirstOrDefaultAsync(
                        l => l.MemoryId == parent && l.CollectionId == child, cancellationToken),
            SyncEntityTypes.MemoryRituals =>
                await context.MemoryRituals
                    .FirstOrDefaultAsync(
                        l => l.MemoryId == parent && l.RitualId == child, cancellationToken),
            SyncEntityTypes.MemoryMedia =>
                await context.MemoryMedia
                    .FirstOrDefaultAsync(
                        l => l.MemoryId == parent && l.MediaId == child, cancellationToken),
            SyncEntityTypes.RitualPeople =>
                await context.RitualPeople
                    .FirstOrDefaultAsync(
                        l => l.RitualId == parent && l.PersonId == child, cancellationToken),
            SyncEntityTypes.JournalMedia =>
                await context.JournalMedia
                    .FirstOrDefaultAsync(
                        l => l.JournalEntryId == parent && l.MediaId == child, cancellationToken),

            // Buraya düşmek, sözlükte olup burada olmayan bir tür demek.
            // `SyncPayloadTests` iki listeyi karşılıklı denetliyor; yine de
            // sessizce `null` dönmüyoruz: "kayıt yok" ile "tabloyu
            // tanımıyorum" aynı şey değil ve ilkine düşülürse sunucu her
            // push'ta yeni bir satır açardı.
            _ => throw new InvalidOperationException(
                $"Senkronizasyon türünün tablosu tanımlı değil: {mapper.EntityType}"),
        };
    }

    /// <remarks>
    /// ANA KAYITLAR birincil anahtar listesiyle, BAĞLAR ise ebeveyn kimliği
    /// listesiyle çekilip bellekte süzülüyor. Sebep: bileşik anahtar için
    /// <c>WHERE (a, b) IN ((..),(..))</c> yazmanın EF'te taşınabilir bir
    /// karşılığı yok. Fazla çekilen satır sayısı sayfa başına sınırlı —
    /// istenen bağların ebeveynlerine ait bağlar.
    ///
    /// Sahiplik süzgeci burada da açık: fazla çekilen satırlar bile hep
    /// isteğin kullanıcısına ait.
    /// </remarks>
    public async Task<IReadOnlyDictionary<string, ISyncable>> FindManyAsync(
        SyncEntityMapper mapper,
        IReadOnlyCollection<SyncEntityKey> keys,
        CancellationToken cancellationToken)
    {
        if (keys.Count == 0)
        {
            return new Dictionary<string, ISyncable>(StringComparer.Ordinal);
        }

        var istenen = keys.Select(k => k.Value).ToHashSet(StringComparer.Ordinal);
        var kimlikler = keys.Select(k => k.Primary).Distinct().ToList();

        IReadOnlyList<ISyncable> satirlar = mapper.EntityType switch
        {
            SyncEntityTypes.Memory =>
                await Cek(context.Memories.Where(e => kimlikler.Contains(e.Id))),
            SyncEntityTypes.JournalEntry =>
                await Cek(context.JournalEntries.Where(e => kimlikler.Contains(e.Id))),
            SyncEntityTypes.Person =>
                await Cek(context.People.Where(e => kimlikler.Contains(e.Id))),
            SyncEntityTypes.Category =>
                await Cek(context.Categories.Where(e => kimlikler.Contains(e.Id))),
            SyncEntityTypes.Collection =>
                await Cek(context.Collections.Where(e => kimlikler.Contains(e.Id))),
            SyncEntityTypes.Ritual =>
                await Cek(context.Rituals.Where(e => kimlikler.Contains(e.Id))),
            SyncEntityTypes.Location =>
                await Cek(context.Locations.Where(e => kimlikler.Contains(e.Id))),
            SyncEntityTypes.MediaItem =>
                await Cek(context.MediaItems.Where(e => kimlikler.Contains(e.Id))),

            SyncEntityTypes.MemoryPeople =>
                await Cek(context.MemoryPeople.Where(l => kimlikler.Contains(l.MemoryId))),
            SyncEntityTypes.MemoryCollections =>
                await Cek(context.MemoryCollections.Where(l => kimlikler.Contains(l.MemoryId))),
            SyncEntityTypes.MemoryRituals =>
                await Cek(context.MemoryRituals.Where(l => kimlikler.Contains(l.MemoryId))),
            SyncEntityTypes.MemoryMedia =>
                await Cek(context.MemoryMedia.Where(l => kimlikler.Contains(l.MemoryId))),
            SyncEntityTypes.RitualPeople =>
                await Cek(context.RitualPeople.Where(l => kimlikler.Contains(l.RitualId))),
            SyncEntityTypes.JournalMedia =>
                await Cek(context.JournalMedia.Where(l => kimlikler.Contains(l.JournalEntryId))),

            _ => throw new InvalidOperationException(
                $"Senkronizasyon türünün tablosu tanımlı değil: {mapper.EntityType}"),
        };

        var sonuc = new Dictionary<string, ISyncable>(StringComparer.Ordinal);
        foreach (var satir in satirlar)
        {
            if (istenen.Contains(satir.SyncId))
            {
                sonuc[satir.SyncId] = satir;
            }
        }

        return sonuc;

        async Task<IReadOnlyList<ISyncable>> Cek<T>(IQueryable<T> sorgu)
            where T : class, ISyncable =>
            await sorgu.ToListAsync(cancellationToken);
    }

    public void Add(ISyncable entity) => context.Add(entity);

    /// <remarks>
    /// <c>Entry</c> çağrısı EF'in değişiklik tespitini o kayıt için
    /// tetikliyor, dolayısıyla ayrıca <c>DetectChanges</c> çağırmak
    /// gerekmiyor.
    ///
    /// YENİ EKLENEN KAYIT <c>Modified</c> DEĞİL <c>Added</c>: bu metot onun
    /// için <c>false</c> dönüyor ve doğrusu bu — sürümü zaten 1'e
    /// kurulmuştu, ikinci bir artırma onu 2 yapardı ve istemci hiç var
    /// olmamış bir sürümü beklerdi.
    /// </remarks>
    public bool IsModified(ISyncable entity) =>
        context.Entry(entity).State == EntityState.Modified;

    /// <remarks>
    /// <c>GroupBy(_ => 1)</c> hilesi: EF'e "tek bir grup üzerinde üç toplama
    /// hesapla" dedirtiyor ve tek bir SELECT üretiyor. Üç ayrı sorgu
    /// atsaydık aralarına bir yazma girip yanıtı kendi içinde tutarsız
    /// yapabilirdi.
    ///
    /// Kullanıcının hiç değişikliği yoksa grup OLUŞMUYOR ve sorgu boş
    /// dönüyor; o durumda sıfır/null döndürüyoruz — yeni hesabın doğru
    /// cevabı bu.
    /// </remarks>
    public async Task<SyncStateResult> StateAsync(
        Guid userId,
        long cursor,
        CancellationToken cancellationToken)
    {
        var ozet = await context.ChangeLog
            .Where(e => e.UserId == userId)
            .GroupBy(_ => 1)
            .Select(g => new
            {
                Bas = g.Max(e => (long?)e.Seq),
                Bekleyen = g.Count(e => e.Seq > cursor),
                SonDegisiklik = g.Max(e => (DateTimeOffset?)e.ChangedAt),
            })
            .FirstOrDefaultAsync(cancellationToken);

        return new SyncStateResult(
            ozet?.Bas ?? 0,
            ozet?.Bekleyen ?? 0,
            ozet?.SonDegisiklik);
    }

    public async Task<long> CurrentCursorAsync(Guid userId, CancellationToken cancellationToken) =>
        await context.ChangeLog
            .Where(e => e.UserId == userId)
            .MaxAsync(e => (long?)e.Seq, cancellationToken) ?? 0;

    /// <remarks>
    /// ⚠️ <c>user_id</c> SÜZGECİ ELLE YAZILIYOR ve yazılmak ZORUNDA:
    /// <c>change_log</c>'un global sorgu süzgeci YOK (gerekçesi
    /// <c>ChangeLogEntryConfiguration</c>'da). Buradaki tek satırlık
    /// unutkanlık, bir kullanıcıya başkasının bütün değişiklik geçmişini
    /// döndürürdü.
    ///
    /// Sorgu <c>ix_change_log_user_seq</c> indeksini soldan okuyor:
    /// önce <c>user_id</c> eşitliği, sonra <c>seq</c> üzerinde aralık.
    /// </remarks>
    public async Task<IReadOnlyList<ChangeLogEntry>> ChangesAfterAsync(
        Guid userId,
        long cursor,
        int? limit,
        CancellationToken cancellationToken)
    {
        var sorgu = context.ChangeLog
            .Where(e => e.UserId == userId && e.Seq > cursor)
            .OrderBy(e => e.Seq);

        return limit is { } adet
            ? await sorgu.Take(adet).ToListAsync(cancellationToken)
            : await sorgu.ToListAsync(cancellationToken);
    }
}
