using Iz.Domain.Users;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Iz.Infrastructure.Persistence.Configurations;

internal sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("users");
        builder.HasKey(u => u.Id);

        builder.Property(u => u.FirebaseUid).HasMaxLength(128).IsRequired();

        // Hesabın giriş anahtarı: benzersiz VE indeksli. Her istekte bu
        // sütundan arama yapılıyor, indeks isteğe bağlı değil.
        //
        // Benzersizlik ayrıca EnsureUserHandler'daki yarış durumunu çözen
        // mekanizmadır: iki eşzamanlı istek aynı kullanıcıyı açmaya
        // çalıştığında kaybeden taraf buradan hata alır ve kazananı okur.
        builder.HasIndex(u => u.FirebaseUid)
            .IsUnique()
            .HasDatabaseName("ix_users_firebase_uid");

        builder.Property(u => u.Email).HasMaxLength(320);
        builder.Property(u => u.DisplayName).HasMaxLength(100);
        builder.Property(u => u.Locale).HasMaxLength(16);

        // Plan ANAHTAR olarak yazılır ("free"/"plus"/"family"), sayı olarak
        // değil — istemcideki IzPlan.key ile birebir aynı sözlük.
        // HasConversion<string>() KULLANILMIYOR: o "Free" yazardı, istemci
        // ise "free" bekliyor (bkz. IzPlanKeys).
        builder.Property(u => u.PlanCache)
            .HasConversion(plan => plan.ToKey(), key => IzPlanKeys.FromKey(key))
            .HasMaxLength(16)
            .IsRequired();

        // Tombstone: silinmiş kullanıcı hiçbir sorguda görünmez.
        builder.HasQueryFilter(u => u.DeletedAt == null);
    }
}
