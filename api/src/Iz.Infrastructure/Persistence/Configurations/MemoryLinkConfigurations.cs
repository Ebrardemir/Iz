using Iz.Domain.Memories;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Iz.Infrastructure.Persistence.Configurations;

/// <summary>
/// Anının dört bağ tablosu — hepsi aynı deseni izliyor.
/// </summary>
/// <remarks>
/// TEK DOSYADA: dördü de "bileşik anahtar + sahip + senkronizasyon
/// sütunları" kalıbının aynısı. Ayrı dosyalara bölmek, aralarındaki farkı
/// (yalnız ikinci anahtar ve bir ek sütun) görünmez yapardı.
///
/// ANAHTAR SIRASI ÖNEMLİ: <c>(MemoryId, ...)</c> — <c>SyncId</c> de bu
/// sırayla üretiliyor (<c>LinkId(MemoryId, PersonId)</c>). Ters çevrilseydi
/// aynı bağ iki farklı kimlikle günlüğe düşerdi.
///
/// TERS YÖN İNDEKSİ: bileşik anahtar yalnız SOLDAN eşleşiyor. "Bu kişi hangi
/// anılarda?" sorgusu ikinci sütundan gidiyor ve indekssiz tam tarama
/// olurdu. İstemcide de aynı indeksler var (şema v5).
/// </remarks>
internal sealed class MemoryPersonConfiguration : IEntityTypeConfiguration<MemoryPerson>
{
    public void Configure(EntityTypeBuilder<MemoryPerson> builder)
    {
        builder.ToTable("memory_people");
        builder.HasKey(l => new { l.MemoryId, l.PersonId });
        builder.ConfigureSyncable("ix_memory_people_owner_id");

        builder.Property(l => l.Role).HasMaxLength(80);
        builder.HasIndex(l => l.PersonId).HasDatabaseName("ix_memory_people_person_id");
    }
}

internal sealed class MemoryCollectionConfiguration : IEntityTypeConfiguration<MemoryCollection>
{
    public void Configure(EntityTypeBuilder<MemoryCollection> builder)
    {
        builder.ToTable("memory_collections");
        builder.HasKey(l => new { l.MemoryId, l.CollectionId });
        builder.ConfigureSyncable("ix_memory_collections_owner_id");

        builder.HasIndex(l => l.CollectionId)
            .HasDatabaseName("ix_memory_collections_collection_id");
    }
}

internal sealed class MemoryRitualConfiguration : IEntityTypeConfiguration<MemoryRitual>
{
    public void Configure(EntityTypeBuilder<MemoryRitual> builder)
    {
        builder.ToTable("memory_rituals");
        builder.HasKey(l => new { l.MemoryId, l.RitualId });
        builder.ConfigureSyncable("ix_memory_rituals_owner_id");

        builder.HasIndex(l => l.RitualId).HasDatabaseName("ix_memory_rituals_ritual_id");
    }
}

internal sealed class MemoryMediaConfiguration : IEntityTypeConfiguration<MemoryMedia>
{
    public void Configure(EntityTypeBuilder<MemoryMedia> builder)
    {
        builder.ToTable("memory_media");
        builder.HasKey(l => new { l.MemoryId, l.MediaId });
        builder.ConfigureSyncable("ix_memory_media_owner_id");

        builder.HasIndex(l => l.MediaId).HasDatabaseName("ix_memory_media_media_id");
    }
}
