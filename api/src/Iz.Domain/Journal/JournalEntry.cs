using Iz.Domain.Sync;

namespace Iz.Domain.Journal;

/// <summary>
/// Belirli bir güne ait günlük kaydı (FR-030).
/// </summary>
/// <remarks>
/// ⚠️ <c>privacyMode == deviceOnly</c> OLAN KAYITLAR BURAYA HİÇ ULAŞMAZ.
/// Süzgeç istemcide, outbox'a yazan noktada (TR-M3-02 / FR-035). Sunucuda
/// ikinci bir kapı YOK ve bu bilinçli: ikisi olsaydı hangisinin gerçek söz
/// olduğu belirsizleşirdi. Kullanıcıya "bu cihazdan çıkmayacak" dediğimiz
/// metnin buraya düşmesi, düzeltilebilir bir hata değil.
///
/// <c>locked</c> kayıtlar ise SENKRONİZE OLUR (yol haritası §4.7): kullanıcı
/// yedeğini istiyor, yalnız açarken biyometri soruluyor. Sunucu için farkı
/// yok.
/// </remarks>
public sealed class JournalEntry : ISyncable
{
    public required Guid Id { get; init; }

    /// <summary>Kaydın ait olduğu GÜN — yazıldığı an değil.</summary>
    public required DateTimeOffset EntryDate { get; set; }

    /// <summary>
    /// Yazının kendisi.
    /// </summary>
    /// <remarks>
    /// Çakışmada "uzun metin" sınıfında (yol haritası §4.4): sunucu sürümü
    /// kazanıyor ama istemcinin sürümü YEREL olarak saklanıp kullanıcıya
    /// gösteriliyor. Hiçbir cümle sessizce silinmiyor.
    /// </remarks>
    public string Content { get; set; } = string.Empty;

    public string? Title { get; set; }

    /// <summary>1..10, <c>null</c> = işaretlenmedi.</summary>
    public int? MoodScore { get; set; }

    public string? MoodKey { get; set; }

    /// <summary>FR-032 — hangi davete cevap verildi. Metin değil SIRA kimliği.</summary>
    public string? PromptId { get; set; }

    /// <summary>FR-035 — <c>standard</c> · <c>locked</c> · <c>deviceOnly</c>.</summary>
    /// <remarks>
    /// METİN, C# enum'u DEĞİL — ve bu, <c>IzPlan</c> ile
    /// <c>DevicePlatform</c>'dan bilinçli bir ayrım.
    ///
    /// Sunucu o ikisine GÖRE KARAR VERİYOR (entitlement kapısı, platform
    /// davranışı), bu yüzden onlar dar tipli. Buradaki değerler ise
    /// sunucunun hiçbir kararına girmiyor; sunucu ayna.
    ///
    /// Dar tip olsaydı istemci yeni bir değer eklediği gün — sunucu
    /// güncellenene kadar — o kaydı okumak istisna atardı ve kullanıcının
    /// TÜM kuyruğu o satırda takılırdı. TR-M13-22'nin ("istemci tanımadığı
    /// alanları korur") sunucu tarafındaki karşılığı bu.
    /// </remarks>
    public string PrivacyMode { get; set; } = "standard";

    public bool IsFavorite { get; set; }

    /// <summary>FR-034 — anıya dönüştürüldüyse hedef. BR-011: bağ kurar, silmez.</summary>
    public Guid? ConvertedMemoryId { get; set; }

    public required Guid OwnerId { get; init; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.JournalEntry;

    public string SyncId => Id.ToString();
}
