using Iz.Domain.Sync;

namespace Iz.Domain.Journal;

/// <summary>
/// Günlük ↔ medya bağı (FR-031). Deseni <c>MemoryPerson</c>daki notta.
/// </summary>
public sealed class JournalMedia : ISyncable
{
    public required Guid JournalEntryId { get; init; }

    public required Guid MediaId { get; init; }

    public int SortOrder { get; set; }

    public required Guid OwnerId { get; init; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.JournalMedia;

    public string SyncId => SyncEntityTypes.LinkId(JournalEntryId, MediaId);
}
