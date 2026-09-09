using Iz.Domain.Sync;

namespace Iz.Domain.Memories;

/// <summary>
/// Anı ↔ medya bağı, sırasıyla. Deseni <see cref="MemoryPerson"/>daki notta.
/// </summary>
/// <remarks>
/// ⚠️ MEDYANIN KENDİSİ SENKRONİZE OLMUYOR (ADR-B07): dosyalar bu haritanın
/// dışında. Senkronize olan yalnız BAĞ ve <c>media_items</c>'daki üstveri.
/// İkinci cihaz "burada bir fotoğraf vardı" bilgisini alıyor, dosyayı değil.
/// </remarks>
public sealed class MemoryMedia : ISyncable
{
    public required Guid MemoryId { get; init; }

    public required Guid MediaId { get; init; }

    public required Guid OwnerId { get; init; }

    public int SortOrder { get; set; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.MemoryMedia;

    public string SyncId => SyncEntityTypes.LinkId(MemoryId, MediaId);
}
