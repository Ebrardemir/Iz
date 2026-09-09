using Iz.Domain.Categories;
using Iz.Domain.Collections;
using Iz.Domain.Journal;
using Iz.Domain.Locations;
using Iz.Domain.Media;
using Iz.Domain.Memories;
using Iz.Domain.People;
using Iz.Domain.Rituals;
using Iz.Domain.Sync;

namespace Iz.Application.Sync;

/// <summary>
/// Ana kayıtların eşleyicileri — sekiz tür.
/// </summary>
/// <remarks>
/// TEK DOSYADA, <c>ContentConfigurations</c> ile aynı gerekçeyle: sekizi de
/// aynı iki metodun tekrarı, ayrı dosyalara bölmek aralarındaki gerçek farkı
/// (hangi sütunlar) görünmez yapardı.
///
/// ALAN ADLARI SQL SÜTUN ADI. Kaynağı istemcideki Drift tabloları; ayrıntı
/// <see cref="SyncRow"/> notunda.
///
/// SUNUCU DOĞRULAMA YAPMIYOR. Uzunluk sınırları veritabanında (istemciyle
/// AYNI), iş kuralları istemcide. Buraya bir kural eklemek, cihazda kabul
/// edilen bir kaydın push'ta reddedilmesi ve kuyruğun kilitlenmesi demek.
/// </remarks>
internal sealed class MemoryMapper : SyncEntityMapper<Memory>
{
    public override string EntityType => SyncEntityTypes.Memory;

    public override (string Parent, string Child)? LinkColumns => null;

    protected override Memory CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            Id = key.Primary,
            OwnerId = ownerId,
            OccurredAt = now,
            OccurredYear = now.Year,
            OccurredMonth = now.Month,
            OccurredDay = now.Day,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(Memory entity, SyncRow row)
    {
        entity.Title = row.Text("title");
        entity.Note = row.Text("note");

        // ÖNCE `occurred_at`: aşağıdaki üç parça, alan eksikse ondan
        // türetiliyor.
        entity.OccurredAt = row.DateTime("occurred_at", entity.OccurredAt);

        // TARİH PARÇALARI GÖVDEDEN OKUNUYOR, sunucuda HESAPLANMIYOR.
        // Hesaplasaydık kaydın YEREL gününü kaybederdik: Türkiye'de 26
        // Temmuz 00:30'da yaşanan bir anı UTC'de 25 Temmuz'dur ve "Bugünün
        // İzi" (FR-080) onu yanlış güne düşürürdü. Doğru gün, istemcinin
        // bildiği gün.
        entity.OccurredYear = row.Int32("occurred_year", entity.OccurredAt.Year);
        entity.OccurredMonth = row.Int32("occurred_month", entity.OccurredAt.Month);
        entity.OccurredDay = row.Int32("occurred_day", entity.OccurredAt.Day);

        entity.CategoryId = row.NullableGuid("category_id");
        entity.LocationId = row.NullableGuid("location_id");
        entity.CoverMediaId = row.NullableGuid("cover_media_id");
        entity.IsFavorite = row.Bool("is_favorite");
        entity.IsArchived = row.Bool("is_archived");
        entity.SourceJournalEntryId = row.NullableGuid("source_journal_entry_id");
    }
}

internal sealed class JournalEntryMapper : SyncEntityMapper<JournalEntry>
{
    public override string EntityType => SyncEntityTypes.JournalEntry;

    public override (string Parent, string Child)? LinkColumns => null;

    protected override JournalEntry CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            Id = key.Primary,
            OwnerId = ownerId,
            EntryDate = now,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(JournalEntry entity, SyncRow row)
    {
        entity.EntryDate = row.DateTime("entry_date", entity.EntryDate);

        // İstemcide sütun adı `content`, `text` DEĞİL: `text` Drift'in sütun
        // kurucusu ve aynı adı sütuna veremiyor. Domain'de alan adı `text`,
        // kabloda `content`.
        entity.Content = row.TextOr("content", entity.Content);

        entity.Title = row.Text("title");
        entity.MoodScore = row.NullableInt32("mood_score");
        entity.MoodKey = row.Text("mood_key");
        entity.PromptId = row.Text("prompt_id");

        // ⚠️ `deviceOnly` OLAN KAYIT BURAYA HİÇ GELMEMELİ (FR-035). Süzgeç
        // istemcide, outbox'a yazan noktada. Sunucuda ikinci bir kapı YOK ve
        // bu bilinçli: ikisi olsaydı hangisinin gerçek söz olduğu
        // belirsizleşirdi (bkz. JournalEntry notu).
        entity.PrivacyMode = row.TextOr("privacy_mode", entity.PrivacyMode);

        entity.IsFavorite = row.Bool("is_favorite");
        entity.ConvertedMemoryId = row.NullableGuid("converted_memory_id");
    }
}

internal sealed class PersonMapper : SyncEntityMapper<Person>
{
    public override string EntityType => SyncEntityTypes.Person;

    public override (string Parent, string Child)? LinkColumns => null;

    protected override Person CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            Id = key.Primary,
            OwnerId = ownerId,
            Name = string.Empty,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(Person entity, SyncRow row)
    {
        entity.Name = row.TextOr("name", entity.Name);
        entity.Kind = row.TextOr("kind", entity.Kind);
        entity.RelationType = row.TextOr("relation_type", entity.RelationType);
        entity.RelationLabel = row.Text("relation_label");
        entity.BirthDate = row.NullableDateTime("birth_date");
        entity.AvatarMediaId = row.NullableGuid("avatar_media_id");
        entity.Note = row.Text("note");
        entity.IsFavorite = row.Bool("is_favorite");
    }
}

internal sealed class CategoryMapper : SyncEntityMapper<Category>
{
    public override string EntityType => SyncEntityTypes.Category;

    public override (string Parent, string Child)? LinkColumns => null;

    protected override Category CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            Id = key.Primary,
            OwnerId = ownerId,
            Name = string.Empty,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(Category entity, SyncRow row)
    {
        // IsSystem true ise burada AD DEĞİL bir ÇEVİRİ ANAHTARI durur
        // ("travel", "family"). Sunucu bu ayrımı bilmek zorunda değil.
        entity.Name = row.TextOr("name", entity.Name);
        entity.IconKey = row.TextOr("icon_key", entity.IconKey);
        entity.SortOrder = row.Int32("sort_order", entity.SortOrder);
        entity.IsSystem = row.Bool("is_system");
    }
}

internal sealed class CollectionMapper : SyncEntityMapper<Collection>
{
    public override string EntityType => SyncEntityTypes.Collection;

    public override (string Parent, string Child)? LinkColumns => null;

    protected override Collection CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            Id = key.Primary,
            OwnerId = ownerId,
            Title = string.Empty,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(Collection entity, SyncRow row)
    {
        entity.Title = row.TextOr("title", entity.Title);
        entity.Description = row.Text("description");
        entity.CoverMediaId = row.NullableGuid("cover_media_id");
        entity.Visibility = row.TextOr("visibility", entity.Visibility);
        entity.StartDate = row.NullableDateTime("start_date");
        entity.EndDate = row.NullableDateTime("end_date");
    }
}

internal sealed class RitualMapper : SyncEntityMapper<Ritual>
{
    public override string EntityType => SyncEntityTypes.Ritual;

    public override (string Parent, string Child)? LinkColumns => null;

    protected override Ritual CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            Id = key.Primary,
            OwnerId = ownerId,
            Title = string.Empty,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(Ritual entity, SyncRow row)
    {
        entity.Title = row.TextOr("title", entity.Title);
        entity.RecurrenceType = row.TextOr("recurrence_type", entity.RecurrenceType);
        entity.AnchorMonth = row.NullableInt32("anchor_month");
        entity.AnchorDay = row.NullableInt32("anchor_day");
        entity.IconKey = row.TextOr("icon_key", entity.IconKey);
    }
}

internal sealed class LocationMapper : SyncEntityMapper<Location>
{
    public override string EntityType => SyncEntityTypes.Location;

    public override (string Parent, string Child)? LinkColumns => null;

    protected override Location CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            Id = key.Primary,
            OwnerId = ownerId,
            Label = string.Empty,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(Location entity, SyncRow row)
    {
        entity.Label = row.TextOr("label", entity.Label);
        entity.Latitude = row.NullableDouble("latitude");
        entity.Longitude = row.NullableDouble("longitude");
        entity.City = row.Text("city");
        entity.Country = row.Text("country");
    }
}

internal sealed class MediaItemMapper : SyncEntityMapper<MediaItem>
{
    public override string EntityType => SyncEntityTypes.MediaItem;

    public override (string Parent, string Child)? LinkColumns => null;

    protected override MediaItem CreateCore(
        SyncEntityKey key,
        Guid ownerId,
        SyncRow row,
        DateTimeOffset now) => new()
        {
            Id = key.Primary,
            OwnerId = ownerId,
            Type = string.Empty,
            CreatedAt = row.DateTime("created_at", now),
            UpdatedAt = now,
        };

    protected override void ApplyCore(MediaItem entity, SyncRow row)
    {
        entity.Type = row.TextOr("type", entity.Type);

        // ⚠️ `local_preview_path`, `gallery_asset_id` ve `last_verified_at`
        // BİLEREK OKUNMUYOR (yol haritası §4.6). Üçü de cihaza özgü: başka
        // bir cihazda anlamsız, hatta yanıltıcı — var olmayan bir dosya
        // yolunu gerçek sanmak, "medyan kayıp" demekten daha kötü. Sunucuda
        // sütunları da yok.
        entity.CloudObjectKey = row.Text("cloud_object_key");
        entity.OriginalStatus = row.TextOr("original_status", entity.OriginalStatus);
        entity.MimeType = row.Text("mime_type");
        entity.Width = row.NullableInt32("width");
        entity.Height = row.NullableInt32("height");
        entity.DurationMs = row.NullableInt32("duration_ms");
        entity.SizeBytes = row.NullableInt64("size_bytes");
    }
}
