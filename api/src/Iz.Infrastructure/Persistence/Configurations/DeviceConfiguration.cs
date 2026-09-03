using Iz.Domain.Devices;
using Iz.Domain.Users;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Iz.Infrastructure.Persistence.Configurations;

internal sealed class DeviceConfiguration : IEntityTypeConfiguration<Device>
{
    public void Configure(EntityTypeBuilder<Device> builder)
    {
        builder.ToTable("devices");
        builder.HasKey(d => d.Id);

        builder.Property(d => d.Platform)
            .HasConversion(platform => platform.ToKey(), key => DevicePlatformKeys.FromKey(key))
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(d => d.AppVersion).HasMaxLength(32);
        builder.Property(d => d.PushToken).HasMaxLength(512);

        // Gezinme özelliği (navigation) BİLİNÇLİ OLARAK YOK: yabancı anahtar
        // var ama User.Devices koleksiyonu yok. Koleksiyon olsaydı bir
        // sorgu farkında olmadan tüm cihazları belleğe çekebilirdi.
        // İlişki kısıtı veritabanında, gezinme kolaylığı sorgularda.
        builder.HasOne<User>()
            .WithMany()
            .HasForeignKey(d => d.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(d => d.UserId).HasDatabaseName("ix_devices_user_id");
    }
}
