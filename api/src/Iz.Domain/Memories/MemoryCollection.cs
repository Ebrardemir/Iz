using Iz.Domain.Sync;

namespace Iz.Domain.Memories;

/// <summary>
/// Anı ↔ koleksiyon bağı (FR-074). Deseni <see cref="MemoryPerson"/>daki notta.
/// </summary>
public sealed class MemoryCollection : ISyncable
{
    public required Guid MemoryId { get; init; }

    public required Guid CollectionId { get; init; }

    public required Guid OwnerId { get; init; }

    /// <summary>
    /// Koleksiyon içi ELLE sıralama — kullanıcının kurduğu anlatı.
    /// </summary>
    /// <remarks>
    /// Çakışmada bu alan "skaler / son yazma kazanır" sınıfında
    /// (yol haritası §4.4): sıranın kaybı bir cümlenin kaybı gibi değil.
    /// </remarks>
    public int SortOrder { get; set; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.MemoryCollections;

    public string SyncId => SyncEntityTypes.LinkId(MemoryId, CollectionId);
}
