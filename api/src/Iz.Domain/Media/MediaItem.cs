using Iz.Domain.Sync;

namespace Iz.Domain.Media;

/// <summary>
/// Fotoğraf/video ÜSTVERİSİ — dosyanın kendisi değil.
/// </summary>
/// <remarks>
/// ⚠️ DOSYA SENKRONİZE OLMUYOR (ADR-B07): medya yükleme bu haritanın
/// dışında. Senkronize olan yalnız bu satır. İkinci cihaz "burada bir
/// fotoğraf vardı" bilgisini alıyor ve yer tutucu gösteriyor.
///
/// CİHAZA ÖZGÜ ALANLAR BURADA YOK: <c>localPreviewPath</c> ve
/// <c>galleryAssetId</c> istemcide var ama sunucuya HİÇ gelmiyor
/// (yol haritası §4.6). Başka bir cihazda anlamsız, hatta yanıltıcı —
/// var olmayan bir dosya yolunu gerçek sanmak, "medyan kayıp" demekten
/// daha kötü.
/// </remarks>
public sealed class MediaItem : ISyncable
{
    public required Guid Id { get; init; }

    /// <summary><c>photo</c> · <c>video</c> · <c>audio</c>.</summary>
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
    public required string Type { get; set; }

    /// <summary>
    /// Buluttaki nesne anahtarı. 1.x'te HER ZAMAN <c>null</c>.
    /// </summary>
    /// <remarks>
    /// Sütun şimdiden duruyor (ADR-B07: "medya bu haritanın dışında, şema
    /// hazır"). Medya yükleme geldiğinde eklenecek olan bir migration
    /// değil, doldurulacak bir sütun olsun.
    /// </remarks>
    public string? CloudObjectKey { get; set; }

    /// <summary>TR-M4-12 — orijinal hâlâ duruyor mu (istemcinin gördüğü).</summary>
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
    public string OriginalStatus { get; set; } = "unknown";

    public string? MimeType { get; set; }

    public int? Width { get; set; }

    public int? Height { get; set; }

    public int? DurationMs { get; set; }

    public long? SizeBytes { get; set; }

    public required Guid OwnerId { get; init; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.MediaItem;

    public string SyncId => Id.ToString();
}
