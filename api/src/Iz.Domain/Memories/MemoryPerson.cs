using Iz.Domain.Sync;

namespace Iz.Domain.Memories;

/// <summary>
/// Anı ↔ kişi bağı (FR-062).
/// </summary>
/// <remarks>
/// BAĞIN KENDİ KİMLİĞİ YOK: birincil anahtar <c>(MemoryId, PersonId)</c>
/// çifti. Ayrıca bir UUID vermek, aynı çiftin iki kimlikle iki kez girmesine
/// kapı açardı. İstemcide de böyle.
///
/// BAĞ DA TOMBSTONE TAŞIYOR ve bu, tüm haritanın en pahalı dersiydi
/// (yol haritası §1.1). Bağı gerçekten silersek ikinci cihaz o satırı hiç
/// görmez, "bende var sende yok" durumunu "sen henüz almamışsın" diye okur
/// ve çıkarılan kişiyi GERİ EKLER. Silmeyi bir satır olarak saklamak bunun
/// tek çaresi.
/// </remarks>
public sealed class MemoryPerson : ISyncable
{
    public required Guid MemoryId { get; init; }

    public required Guid PersonId { get; init; }

    public required Guid OwnerId { get; init; }

    /// <summary>Opsiyonel rol ("fotoğrafı çeken", "doğum günü sahibi").</summary>
    public string? Role { get; set; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.MemoryPeople;

    public string SyncId => SyncEntityTypes.LinkId(MemoryId, PersonId);
}
