using Iz.Domain.Sync;

namespace Iz.Domain.Collections;

/// <summary>Anıların elle kurulmuş derlemesi (FR-074).</summary>
public sealed class Collection : ISyncable
{
    public required Guid Id { get; init; }

    public required string Title { get; set; }

    public string? Description { get; set; }

    public Guid? CoverMediaId { get; set; }

    /// <summary>BR-003 — varsayılan <c>private</c>.</summary>
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
    public string Visibility { get; set; } = "private";

    /// <summary>Seyahat/dönem koleksiyonları için opsiyonel aralık.</summary>
    public DateTimeOffset? StartDate { get; set; }

    public DateTimeOffset? EndDate { get; set; }

    public required Guid OwnerId { get; init; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.Collection;

    public string SyncId => Id.ToString();
}
