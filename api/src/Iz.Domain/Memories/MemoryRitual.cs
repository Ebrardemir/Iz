using Iz.Domain.Sync;

namespace Iz.Domain.Memories;

/// <summary>
/// Anı ↔ seri bağı, hangi yılın tekrarı olduğu bilgisiyle (BR-012).
/// Deseni <see cref="MemoryPerson"/>daki notta.
/// </summary>
public sealed class MemoryRitual : ISyncable
{
    public required Guid MemoryId { get; init; }

    public required Guid RitualId { get; init; }

    public required Guid OwnerId { get; init; }

    /// <summary>FR-076'daki "yılları yan yana karşılaştırma" buna dayanıyor.</summary>
    public required int OccurrenceYear { get; set; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.MemoryRituals;

    public string SyncId => SyncEntityTypes.LinkId(MemoryId, RitualId);
}
