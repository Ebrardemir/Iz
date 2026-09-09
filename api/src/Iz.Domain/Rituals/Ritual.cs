using Iz.Domain.Sync;

namespace Iz.Domain.Rituals;

/// <summary>Tekrar eden an — "seri" (FR-064).</summary>
public sealed class Ritual : ISyncable
{
    public required Guid Id { get; init; }

    public required string Title { get; set; }

    /// <summary><c>yearly</c> · <c>monthly</c> · <c>weekly</c> · <c>custom</c>.</summary>
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
    public string RecurrenceType { get; set; } = "yearly";

    /// <summary>Yıllık serinin sabitlendiği ay/gün. Opsiyonel.</summary>
    public int? AnchorMonth { get; set; }

    public int? AnchorDay { get; set; }

    public string IconKey { get; set; } = "ritual";

    public required Guid OwnerId { get; init; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.Ritual;

    public string SyncId => Id.ToString();
}
