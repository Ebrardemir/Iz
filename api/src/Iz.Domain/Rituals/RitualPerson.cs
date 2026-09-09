using Iz.Domain.Sync;

namespace Iz.Domain.Rituals;

/// <summary>
/// Seri ↔ kişi bağı (FR-064). Deseni <c>MemoryPerson</c>daki notta.
/// </summary>
/// <remarks>
/// ⚠️ YOL HARİTASI §3'TEKİ MODELDE YOK — orada seri tekil bir
/// <c>related_person_id</c> taşıyor. O liste istemci şema v7'den ÖNCE
/// yazılmıştı; bir seri birden fazla kişiyle paylaşılıyor ("Aile
/// Yemeklerimiz") ve tekil sütun v7'de bağ tablosuna dönüştü. Sunucu
/// istemciyi izliyor.
/// </remarks>
public sealed class RitualPerson : ISyncable
{
    public required Guid RitualId { get; init; }

    public required Guid PersonId { get; init; }

    public required Guid OwnerId { get; init; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.RitualPeople;

    public string SyncId => SyncEntityTypes.LinkId(RitualId, PersonId);
}
