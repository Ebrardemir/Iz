using Iz.Domain.Journal;
using Iz.Domain.Memories;
using Iz.Domain.Rituals;
using Iz.Domain.Sync;

namespace Iz.Application.Sync;

/// <summary>
/// Bağ tablolarının eşleyicileri — altı tür.
/// </summary>
/// <remarks>
/// BAĞLARIN GÖVDESİNDE <c>owner_id</c> YOK: istemcide bağ tabloları
/// <c>OwnedTable</c> kullanmıyor, kimliği zaten ana kayda bağlı. Sunucuda
/// sahip sütunu VAR (IDOR süzgeci ve <c>change_log</c> kapsamı için) ve
/// değerini token'dan alıyoruz — gövdeden değil.
///
/// BAĞLAR SÜRÜM ÇAKIŞMASI ÜRETMİYOR (yol haritası §4.4): satır bazlı
/// birleşiyorlar, silme kazanıyor. Gerekçe: iki cihazın aynı anıya FARKLI
/// kişiler eklemesi bir çakışma değil, ikisinin de olması gereken bir
/// birleşme. <c>PushChangesHandler.MergeLink</c> bunu uyguluyor.
/// </remarks>
internal sealed class MemoryPersonMapper : SyncEntityMapper<MemoryPerson>
{
    public override string EntityType => SyncEntityTypes.MemoryPeople;

    public override (string Parent, string Child)? LinkColumns => ("memory_id", "person_id");

    protected override MemoryPerson CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            MemoryId = key.Primary,
            PersonId = key.Secondary!.Value,
            OwnerId = ownerId,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(MemoryPerson entity, SyncRow row) =>
        entity.Role = row.Text("role");
}

internal sealed class MemoryCollectionMapper : SyncEntityMapper<MemoryCollection>
{
    public override string EntityType => SyncEntityTypes.MemoryCollections;

    public override (string Parent, string Child)? LinkColumns => ("memory_id", "collection_id");

    protected override MemoryCollection CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            MemoryId = key.Primary,
            CollectionId = key.Secondary!.Value,
            OwnerId = ownerId,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(MemoryCollection entity, SyncRow row) =>
        entity.SortOrder = row.Int32("sort_order", entity.SortOrder);
}

internal sealed class MemoryRitualMapper : SyncEntityMapper<MemoryRitual>
{
    public override string EntityType => SyncEntityTypes.MemoryRituals;

    public override (string Parent, string Child)? LinkColumns => ("memory_id", "ritual_id");

    protected override MemoryRitual CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            MemoryId = key.Primary,
            RitualId = key.Secondary!.Value,
            OwnerId = ownerId,

            // FR-076'daki "yılları yan yana karşılaştırma" bu alana dayanıyor;
            // gövdede yoksa 0 kalıyor ve ApplyCore hemen üzerine yazıyor.
            OccurrenceYear = 0,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(MemoryRitual entity, SyncRow row) =>
        entity.OccurrenceYear = row.Int32("occurrence_year", entity.OccurrenceYear);
}

internal sealed class MemoryMediaMapper : SyncEntityMapper<MemoryMedia>
{
    public override string EntityType => SyncEntityTypes.MemoryMedia;

    public override (string Parent, string Child)? LinkColumns => ("memory_id", "media_id");

    protected override MemoryMedia CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            MemoryId = key.Primary,
            MediaId = key.Secondary!.Value,
            OwnerId = ownerId,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(MemoryMedia entity, SyncRow row) =>
        entity.SortOrder = row.Int32("sort_order", entity.SortOrder);
}

/// <remarks>
/// İÇERİK SÜTUNU YOK — bağın kendisi bilginin tamamı. <c>ApplyCore</c> boş
/// ama sınıf yine de var: bağın satırı, tombstone'u ve günlük kaydı
/// ötekilerle aynı yoldan geçiyor.
/// </remarks>
internal sealed class RitualPersonMapper : SyncEntityMapper<RitualPerson>
{
    public override string EntityType => SyncEntityTypes.RitualPeople;

    public override (string Parent, string Child)? LinkColumns => ("ritual_id", "person_id");

    protected override RitualPerson CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            RitualId = key.Primary,
            PersonId = key.Secondary!.Value,
            OwnerId = ownerId,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(RitualPerson entity, SyncRow row)
    {
    }
}

internal sealed class JournalMediaMapper : SyncEntityMapper<JournalMedia>
{
    public override string EntityType => SyncEntityTypes.JournalMedia;

    public override (string Parent, string Child)? LinkColumns =>
        ("journal_entry_id", "media_id");

    protected override JournalMedia CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            JournalEntryId = key.Primary,
            MediaId = key.Secondary!.Value,
            OwnerId = ownerId,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(JournalMedia entity, SyncRow row) =>
        entity.SortOrder = row.Int32("sort_order", entity.SortOrder);
}
