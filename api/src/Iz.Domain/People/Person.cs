using Iz.Domain.Sync;

namespace Iz.Domain.People;

/// <summary>Anılarda etiketlenen kişi (FR-060).</summary>
public sealed class Person : ISyncable
{
    public required Guid Id { get; init; }

    public required string Name { get; set; }

    /// <summary><c>human</c> · <c>pet</c> — kişi mi, evcil hayvan mı.</summary>
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
    public string Kind { get; set; } = "human";

    /// <summary>Tanımlı ilişki türü (<c>mother</c>, <c>friend</c>…).</summary>
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
    public string RelationType { get; set; } = "other";

    /// <summary>
    /// Kullanıcının KENDİ YAZDIĞI ilişki adı ("Annem", "Kankam").
    /// </summary>
    /// <remarks>
    /// <see cref="RelationType"/>ın yerine değil ÜSTÜNE geçiyor: tür
    /// çevrilebilir bir etiket, bu ise kullanıcının kelimesi. İstemcide
    /// şema v6 ile eklenmişti.
    /// </remarks>
    public string? RelationLabel { get; set; }

    public DateTimeOffset? BirthDate { get; set; }

    public Guid? AvatarMediaId { get; set; }

    public string? Note { get; set; }

    public bool IsFavorite { get; set; }

    public required Guid OwnerId { get; init; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.Person;

    public string SyncId => Id.ToString();
}
