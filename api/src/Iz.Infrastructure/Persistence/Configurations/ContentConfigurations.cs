using Iz.Domain.Categories;
using Iz.Domain.Collections;
using Iz.Domain.Journal;
using Iz.Domain.Locations;
using Iz.Domain.Media;
using Iz.Domain.People;
using Iz.Domain.Rituals;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Iz.Infrastructure.Persistence.Configurations;

/// <summary>
/// Anı dışındaki senkronize varlıkların yapılandırmaları.
/// </summary>
/// <remarks>
/// TEK DOSYADA: dokuzu da aynı üç satırın tekrarı (tablo adı, anahtar,
/// <c>ConfigureSyncable</c>) artı birkaç uzunluk sınırı. Dokuz ayrı dosyaya
/// bölmek, aralarındaki gerçek farkı görünmez yapardı. Anının bağları
/// <c>MemoryLinkConfigurations</c>'ta, aynı gerekçeyle.
///
/// UZUNLUK SINIRLARI İSTEMCİYLE AYNI. Sunucuda daha dar olsaydı kullanıcının
/// cihazında kabul edilen bir metin push'ta reddedilir ve kuyruk o satırda
/// SONSUZA KADAR takılırdı — kullanıcı hiçbir şeyin eşitlenmediğini görür,
/// sebebini asla öğrenemezdi. Sınırların gevşek olması bir kaybı, dar olması
/// bir kilitlenmeyi getirir; ikisinden ilkini seçiyoruz.
///
/// ENUM ALANLARI METİN olarak duruyor ve dar tipe çevrilmiyor — gerekçesi
/// varlıkların kendi notlarında.
/// </remarks>
internal sealed class JournalEntryConfiguration : IEntityTypeConfiguration<JournalEntry>
{
    public void Configure(EntityTypeBuilder<JournalEntry> builder)
    {
        builder.ToTable("journal_entries");
        builder.HasKey(e => e.Id);
        builder.ConfigureSyncable("ix_journal_entries_owner_id");

        builder.Property(e => e.Content).HasMaxLength(50_000).IsRequired();
        builder.Property(e => e.Title).HasMaxLength(200);
        builder.Property(e => e.MoodKey).HasMaxLength(32);
        builder.Property(e => e.PromptId).HasMaxLength(64);
        builder.Property(e => e.PrivacyMode).HasMaxLength(16).IsRequired();

        // GÜN BAZINDA sorgulanıyor (takvim görünümü, FR-033).
        builder.HasIndex(e => new { e.OwnerId, e.EntryDate })
            .HasDatabaseName("ix_journal_entries_owner_entry_date");
    }
}

internal sealed class JournalMediaConfiguration : IEntityTypeConfiguration<JournalMedia>
{
    public void Configure(EntityTypeBuilder<JournalMedia> builder)
    {
        builder.ToTable("journal_media");

        // ANAHTAR SIRASI `SyncId` ile aynı olmak zorunda
        // (LinkId(JournalEntryId, MediaId)); ters çevrilirse aynı bağ iki
        // farklı kimlikle günlüğe düşer.
        builder.HasKey(l => new { l.JournalEntryId, l.MediaId });
        builder.ConfigureSyncable("ix_journal_media_owner_id");

        builder.HasIndex(l => l.MediaId).HasDatabaseName("ix_journal_media_media_id");
    }
}

internal sealed class PersonConfiguration : IEntityTypeConfiguration<Person>
{
    public void Configure(EntityTypeBuilder<Person> builder)
    {
        builder.ToTable("people");
        builder.HasKey(p => p.Id);
        builder.ConfigureSyncable("ix_people_owner_id");

        builder.Property(p => p.Name).HasMaxLength(120).IsRequired();
        builder.Property(p => p.Kind).HasMaxLength(16).IsRequired();
        builder.Property(p => p.RelationType).HasMaxLength(32).IsRequired();
        builder.Property(p => p.RelationLabel).HasMaxLength(60);
        builder.Property(p => p.Note).HasMaxLength(2_000);
    }
}

internal sealed class CategoryConfiguration : IEntityTypeConfiguration<Category>
{
    public void Configure(EntityTypeBuilder<Category> builder)
    {
        builder.ToTable("categories");
        builder.HasKey(c => c.Id);
        builder.ConfigureSyncable("ix_categories_owner_id");

        builder.Property(c => c.Name).HasMaxLength(60).IsRequired();
        builder.Property(c => c.IconKey).HasMaxLength(32).IsRequired();
    }
}

internal sealed class CollectionConfiguration : IEntityTypeConfiguration<Collection>
{
    public void Configure(EntityTypeBuilder<Collection> builder)
    {
        builder.ToTable("collections");
        builder.HasKey(c => c.Id);
        builder.ConfigureSyncable("ix_collections_owner_id");

        builder.Property(c => c.Title).HasMaxLength(120).IsRequired();
        builder.Property(c => c.Description).HasMaxLength(2_000);
        builder.Property(c => c.Visibility).HasMaxLength(16).IsRequired();
    }
}

internal sealed class RitualConfiguration : IEntityTypeConfiguration<Ritual>
{
    public void Configure(EntityTypeBuilder<Ritual> builder)
    {
        builder.ToTable("rituals");
        builder.HasKey(r => r.Id);
        builder.ConfigureSyncable("ix_rituals_owner_id");

        builder.Property(r => r.Title).HasMaxLength(120).IsRequired();
        builder.Property(r => r.RecurrenceType).HasMaxLength(16).IsRequired();
        builder.Property(r => r.IconKey).HasMaxLength(32).IsRequired();
    }
}

internal sealed class RitualPersonConfiguration : IEntityTypeConfiguration<RitualPerson>
{
    public void Configure(EntityTypeBuilder<RitualPerson> builder)
    {
        builder.ToTable("ritual_people");
        builder.HasKey(l => new { l.RitualId, l.PersonId });
        builder.ConfigureSyncable("ix_ritual_people_owner_id");

        builder.HasIndex(l => l.PersonId).HasDatabaseName("ix_ritual_people_person_id");
    }
}

internal sealed class LocationConfiguration : IEntityTypeConfiguration<Location>
{
    public void Configure(EntityTypeBuilder<Location> builder)
    {
        builder.ToTable("locations");
        builder.HasKey(l => l.Id);
        builder.ConfigureSyncable("ix_locations_owner_id");

        builder.Property(l => l.Label).HasMaxLength(200).IsRequired();
        builder.Property(l => l.City).HasMaxLength(120);
        builder.Property(l => l.Country).HasMaxLength(120);
    }
}

internal sealed class MediaItemConfiguration : IEntityTypeConfiguration<MediaItem>
{
    public void Configure(EntityTypeBuilder<MediaItem> builder)
    {
        builder.ToTable("media_items");
        builder.HasKey(m => m.Id);
        builder.ConfigureSyncable("ix_media_items_owner_id");

        builder.Property(m => m.Type).HasMaxLength(16).IsRequired();
        builder.Property(m => m.OriginalStatus).HasMaxLength(16).IsRequired();
        builder.Property(m => m.MimeType).HasMaxLength(128);
        builder.Property(m => m.CloudObjectKey).HasMaxLength(512);
    }
}
