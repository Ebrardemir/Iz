using Iz.Domain.Sync;

namespace Iz.Domain.Memories;

/// <summary>
/// Anı — uygulamanın merkezî kaydı (FR-010).
/// </summary>
/// <remarks>
/// İstemcideki <c>Memories</c> tablosunun (features/memories/data/tables)
/// birebir karşılığı. Alan adları ve anlamları AYNI kalmak zorunda: iki
/// tarafın modeli ayrıştığı gün push/pull bir çeviri katmanı gerektirir ve o
/// katman bir gün bir alanı sessizce düşürür (yol haritası §3).
///
/// SUNUCU BU KAYDIN ÜZERİNDE İŞ KURALI ÇALIŞTIRMIYOR. Doğrunun kaynağı
/// kullanıcının cihazı; sunucunun işi aynalamak ve çakışmada hakemlik etmek.
/// Bu yüzden burada doğrulama yok, hesaplanan alan yok — sütunlar ve
/// senkronizasyon alanları var.
/// </remarks>
public sealed class Memory : ISyncable
{
    /// <summary>İstemcinin ürettiği UUID v7 (TR-C-40).</summary>
    /// <remarks>
    /// Sunucu YENİ KİMLİK ÜRETMİYOR. Üretseydi kullanıcı çevrimdışıyken
    /// oluşturduğu anıyı senkronizasyondan sonra başka bir kimlikle bulurdu
    /// ve o kimliğe bağlı yerel bağların hepsi kopardı.
    /// </remarks>
    public required Guid Id { get; init; }

    public required Guid OwnerId { get; init; }

    public string? Title { get; set; }

    public string? Note { get; set; }

    /// <summary>Anının YAŞANDIĞI an — kaydedildiği an değil.</summary>
    public required DateTimeOffset OccurredAt { get; set; }

    /// <summary>
    /// Tarihin parçaları ayrı sütunlarda.
    /// </summary>
    /// <remarks>
    /// TÜRETİLEBİLİR AMA SAKLANIYOR: "bugünün izi" (FR-080) ve yıl
    /// karşılaştırması (FR-076) ay/gün üzerinden sorguluyor.
    /// <c>EXTRACT(...)</c> ile hesaplasaydık indeks kullanılamaz, sorgu tam
    /// tarama olurdu. İstemcide de aynı sebeple ayrı duruyorlar.
    /// </remarks>
    public required int OccurredYear { get; set; }

    public required int OccurredMonth { get; set; }

    public required int OccurredDay { get; set; }

    public Guid? CategoryId { get; set; }

    public Guid? LocationId { get; set; }

    public Guid? CoverMediaId { get; set; }

    public bool IsFavorite { get; set; }

    public bool IsArchived { get; set; }

    /// <summary>
    /// FR-034 — bu anı bir günlük kaydından dönüştürüldüyse kaynağı.
    /// BR-011: bağ kurar, kaynağı silmez.
    /// </summary>
    public Guid? SourceJournalEntryId { get; set; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.Memory;

    public string SyncId => Id.ToString();
}
