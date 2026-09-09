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

    public async Task<long> CurrentCursorAsync(Guid userId, CancellationToken cancellationToken) =>
        await context.ChangeLog
            .Where(e => e.UserId == userId)
            .MaxAsync(e => (long?)e.Seq, cancellationToken) ?? 0;

    public async Task<IReadOnlyList<ChangeLogEntry>> ChangesAfterAsync(
        Guid userId,
        long cursor,
        CancellationToken cancellationToken) =>
        await context.ChangeLog
            .Where(e => e.UserId == userId && e.Seq > cursor)
            .OrderBy(e => e.Seq)
            .ToListAsync(cancellationToken);
}
