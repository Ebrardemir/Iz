using Iz.Domain.Sync;

namespace Iz.Application.Sync;

/// <summary>
/// Bir senkronizasyon türünün gövde ↔ satır çevirisi.
/// </summary>
/// <remarks>
/// HER TÜR İÇİN ELLE YAZILI, YANSIMAYLA DEĞİL. Yansıma çekiciydi: on dört
/// tip, aynı adlandırma kuralı. Ama o zaman istemcinin gönderdiği HER alan
/// adı sunucuda bir sütun aramaya başlardı ve <c>owner_id</c>, <c>version</c>
/// gibi SUNUCUNUN KARAR VERDİĞİ alanlar da gövdeden yazılabilirdi. İstemci
/// bugün <c>owner_id: "local"</c> gönderiyor (hesap yükseltmesi henüz
/// yazılmadı); yansımalı bir eşleyici o değeri okumaya çalışırdı.
///
/// Elle yazmanın ikinci faydası: <see cref="Apply"/> yalnız İÇERİK
/// sütunlarına dokunuyor. Kimlik, sahiplik, sürüm ve tombstone sütunlarını
/// <c>PushChangesHandler</c> belirliyor — istemci onları etkileyemiyor.
///
/// Yeni bir sütun eklenip burada unutulursa <c>SyncPayloadTests</c>'teki
/// gidiş-dönüş testi kırmızıya döner: sütun sunucuda var ama gövdeden
/// okunmuyor demektir ve o alan sessizce hiç senkronize olmaz.
/// </remarks>
public abstract class SyncEntityMapper
{
    /// <summary>Bkz. <see cref="SyncEntityTypes"/>.</summary>
    public abstract string EntityType { get; }

    /// <summary>
    /// Bağ tablolarında kimliği oluşturan iki sütunun adı; ana kayıtlarda
    /// <c>null</c>.
    /// </summary>
    /// <remarks>
    /// SIRA <c>SyncId</c> İLE AYNI OLMAK ZORUNDA
    /// (<see cref="SyncEntityTypes.LinkId"/>'ye verilen sıra). Ters
    /// yazılırsa aynı bağ iki farklı kimlikle günlüğe düşer ve ikinci
    /// cihazda iki ayrı satır olur.
    ///
    /// Bağ satırları gövdede ANA KAYDIN İÇİNDE geliyor ve kendi
    /// <c>entityId</c>'leri yok; kimliklerini bu iki sütundan okuyoruz.
    /// </remarks>
    public abstract (string Parent, string Child)? LinkColumns { get; }

    /// <summary>
    /// Bileşik anahtarlı bir bağ mı?
    /// </summary>
    /// <remarks>
    /// <see cref="SyncEntityKey"/> kimliği buna bakarak ayrıştırıyor. TÜRDEN
    /// okunuyor, gövdeden değil: istemcinin "bu bir bağdır" demesine
    /// güvenseydik tür ile kimlik biçimi ayrışabilirdi.
    /// </remarks>
    public bool IsLink => LinkColumns is not null;

    /// <summary>
    /// Bir bağ satırının kimliğini kendi sütunlarından çözer.
    /// </summary>
    /// <remarks>
    /// Kimlik ayrıştırması SIKI: iki sütundan biri okunamıyorsa o bağ
    /// ATLANIYOR. Bağı varsayılan bir kimlikle yazmak, kullanıcının anısını
    /// tanımadığı bir kişiye bağlamak olurdu.
    /// </remarks>
    public bool TryReadLinkKey(SyncRow row, out SyncEntityKey key)
    {
        key = default;

        if (LinkColumns is not { } columns)
        {
            return false;
        }

        if (row.NullableGuid(columns.Parent) is not { } parent ||
            row.NullableGuid(columns.Child) is not { } child)
        {
            return false;
        }

        key = new SyncEntityKey(parent, child);
        return true;
    }

    /// <summary>
    /// Sunucuda karşılığı olmayan bir kayıt için boş iskelet üretir.
    /// </summary>
    /// <remarks>
    /// İÇERİK BURADA DOLMUYOR — hemen ardından <see cref="Apply"/> çağrılıyor.
    /// İkisini ayırmak, içerik eşlemesinin TEK bir yerde durmasını sağlıyor:
    /// oluşturma ile güncelleme farklı alanlar yazarsa, bir kaydın ilk hâli
    /// ile ikinci hâli sessizce ayrışırdı.
    ///
    /// <c>CreatedAt</c> gövdeden okunuyor çünkü <c>init</c>: kullanıcının
    /// kaydı gerçekten oluşturduğu an korunuyor, sunucuya ulaştığı an değil.
    /// </remarks>
    public abstract ISyncable Create(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now);

    /// <summary>İçerik sütunlarını gövdeden yazar.</summary>
    /// <remarks>
    /// EKSİK ALANIN İKİ ANLAMI VAR ve ayrımı sütunun null'lanabilirliği
    /// belirliyor:
    ///   • null'lanabilir sütun → alan yoksa <c>null</c> yazılır (temizleme).
    ///     İstemci satırın TAMAMINI gönderiyor, dolayısıyla yokluk gerçekten
    ///     "bu alan boş" demek.
    ///   • null'lanamaz sütun → alan yoksa mevcut değer KORUNUR. Zorla bir
    ///     varsayılan yazmak, okunamayan tek bir alan yüzünden kullanıcının
    ///     başlığını silmek olurdu.
    /// </remarks>
    public abstract void Apply(ISyncable entity, SyncRow row);
}

/// <inheritdoc/>
/// <typeparam name="TEntity">Eşlenen varlık.</typeparam>
/// <remarks>
/// Tipli ara katman yalnız cast'i tek yere topluyor; alt sınıflar
/// <see cref="ISyncable"/> ile uğraşmıyor.
/// </remarks>
public abstract class SyncEntityMapper<TEntity> : SyncEntityMapper
    where TEntity : class, ISyncable
{
    public sealed override ISyncable Create(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => CreateCore(key, ownerId, row, now);

    public sealed override void Apply(ISyncable entity, SyncRow row) =>
        ApplyCore((TEntity)entity, row);

    protected abstract TEntity CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now);

    protected abstract void ApplyCore(TEntity entity, SyncRow row);
}

/// <summary>
/// Tür adı → eşleyici sözlüğü.
/// </summary>
/// <remarks>
/// SÖZLÜĞÜN <see cref="SyncEntityTypes.All"/> İLE BİREBİR OLMASI ZORUNLU:
/// eşleyicisi olmayan bir tür push'ta tanınır ama YAZILAMAZ, ve o
/// kullanıcının kuyruğu o satırda takılır. <c>SyncPayloadTests</c> iki
/// listeyi karşılıklı denetliyor.
/// </remarks>
public static class SyncEntityMappers
{
    private static readonly SyncEntityMapper[] Mappers =
    [
        new MemoryMapper(),
        new JournalEntryMapper(),
        new PersonMapper(),
        new CategoryMapper(),
        new CollectionMapper(),
        new RitualMapper(),
        new LocationMapper(),
        new MediaItemMapper(),
        new MemoryPersonMapper(),
        new MemoryCollectionMapper(),
        new MemoryRitualMapper(),
        new MemoryMediaMapper(),
        new RitualPersonMapper(),
        new JournalMediaMapper(),
    ];

    private static readonly Dictionary<string, SyncEntityMapper> ByType =
        Mappers.ToDictionary(m => m.EntityType, StringComparer.Ordinal);

    public static IReadOnlyCollection<SyncEntityMapper> All => Mappers;

    /// <summary>Tanımadığımız tür için <c>null</c> — istisna değil.</summary>
    /// <remarks>
    /// Tanınmayan tür o DEĞİŞİKLİĞİ reddediyor, isteği değil: eski bir
    /// istemcinin gönderdiği tek bir bilinmeyen satır, batch'teki geri kalan
    /// her şeyi engellememeli.
    /// </remarks>
    public static SyncEntityMapper? Find(string? entityType) =>
        entityType is not null && ByType.TryGetValue(entityType, out var mapper)
            ? mapper
            : null;
}
