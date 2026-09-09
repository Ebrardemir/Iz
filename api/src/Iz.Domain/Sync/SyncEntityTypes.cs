namespace Iz.Domain.Sync;

/// <summary>
/// <c>change_log.entity_type</c> sözlüğü — sunucu ile istemci arasındaki
/// SÖZLEŞME.
/// </summary>
/// <remarks>
/// Bu değerler DEĞİŞMEZ. Kullanıcının cihazında bekleyen kuyruk satırları ve
/// sunucudaki günlük kayıtları bu adları taşıyor; birini yeniden
/// adlandırmak, uygulama güncellemesinden sağ çıkmış bir kuyruğu okunamaz
/// hâle getirir.
///
/// İstemci tarafındaki karşılıkları DAO'ların başında sabit olarak duruyor
/// (<c>kMemoryEntityType</c> ve kardeşleri). İki listenin aynı kalmasını
/// <c>SyncEntityTypeTests</c> denetliyor.
///
/// BAĞ TABLOLARI DA BİRER TÜR. İstemci onları ana kaydın gövdesinin İÇİNDE
/// gönderiyor (tek push = anı + bağları), ama sunucu her bağı KENDİ SATIRI
/// olarak saklayıp kendi günlük kaydını düşürüyor. Sebep yol haritası
/// §4.4'te: bağlar satır bazlı birleşiyor — silme kazanır, ekleme birikir.
/// Bağı ana kaydın bir parçası saysaydık, iki cihazın aynı anıya FARKLI
/// kişiler eklemesi gereksiz bir çakışma üretirdi.
///
/// Adlar TABLO adları: yol haritası §4.2'deki örnekte tekil (<c>memory_person</c>)
/// yazıyordu; çoğul biçimi seçtik çünkü istemcinin gövdesindeki bağ
/// anahtarları da tablo adı (<c>links: { "memory_people": [...] }</c>) ve tek
/// bir sözlük iki sözlükten iyidir.
/// </remarks>
public static class SyncEntityTypes
{
    // ---- Ana kayıtlar -----------------------------------------------------
    public const string Memory = "memory";
    public const string JournalEntry = "journal_entry";
    public const string Person = "person";
    public const string Category = "category";
    public const string Collection = "collection";
    public const string Ritual = "ritual";
    public const string Location = "location";
    public const string MediaItem = "media_item";

    // ---- Bağlar -----------------------------------------------------------
    public const string MemoryPeople = "memory_people";
    public const string MemoryCollections = "memory_collections";
    public const string MemoryRituals = "memory_rituals";
    public const string MemoryMedia = "memory_media";
    public const string RitualPeople = "ritual_people";
    public const string JournalMedia = "journal_media";

    /// <summary>
    /// Tanınan tüm türler. Push gelen bir <c>entityType</c>'ı buna karşı
    /// doğruluyor: tanımadığımız bir tür sessizce yazılmamalı.
    /// </summary>
    public static readonly IReadOnlySet<string> All = new HashSet<string>(StringComparer.Ordinal)
    {
        Memory, JournalEntry, Person, Category, Collection, Ritual, Location, MediaItem,
        MemoryPeople, MemoryCollections, MemoryRituals, MemoryMedia, RitualPeople, JournalMedia,
    };

    /// <summary>
    /// Bileşik anahtarlı bir bağın <c>change_log.entity_id</c> değeri.
    /// </summary>
    /// <remarks>
    /// Bağın kendi UUID'si YOK — kimliği <c>(anı, kişi)</c> çifti. İki
    /// kimliği iki nokta üst üste ile birleştiriyoruz (yol haritası §4.2
    /// örneğindeki biçim). Ayrı bir UUID vermek aynı çiftin iki kimlikle iki
    /// kez girmesine kapı açardı.
    /// </remarks>
    public static string LinkId(Guid parentId, Guid childId) => $"{parentId}:{childId}";
}
