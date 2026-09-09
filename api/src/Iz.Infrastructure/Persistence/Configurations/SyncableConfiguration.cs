using Iz.Domain.Sync;
using Iz.Domain.Users;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Iz.Infrastructure.Persistence.Configurations;

/// <summary>
/// Senkronize edilen her tablonun paylaştığı yapılandırma.
/// </summary>
/// <remarks>
/// On dört tabloda aynı beş sütun var. Elle tekrarlamak, bir gün birinde
/// eksik indeks ya da yanlış silme davranışı bırakmak demekti.
/// </remarks>
internal static class SyncableConfiguration
{
    /// <summary>
    /// Sahiplik, sürüm ve tombstone sütunlarını yapılandırır.
    /// </summary>
    /// <param name="ownerIndexName">
    /// Sahip indeksinin adı. EF'in ürettiği ad tahmin edilebilir değil ve
    /// migration'da açıkça görünmesini istiyoruz.
    /// </param>
    public static void ConfigureSyncable<T>(
        this EntityTypeBuilder<T> builder,
        string ownerIndexName)
        where T : class, ISyncable
    {
        // HESAPLANAN ALANLAR SÜTUN DEĞİL. `SyncEntityType` ve `SyncId`
        // kablodaki kimliği anlatıyor; ikisi de mevcut sütunlardan
        // türetiliyor ve saklamak aynı bilgiyi iki yerde tutmak olurdu.
        builder.Ignore(e => e.SyncEntityType);
        builder.Ignore(e => e.SyncId);

        // KULLANICI SİLİNİRSE VERİSİ DE GİDER (KVKK, §7.3). Cascade
        // veritabanında: uygulama kodu unutsa bile artık kayıt kalmaz.
        builder.HasOne<User>()
            .WithMany()
            .HasForeignKey(e => e.OwnerId)
            .OnDelete(DeleteBehavior.Cascade);

        // PULL'UN SICAK YOLU. Her sorgu sahiple süzülüyor; indeks isteğe
        // bağlı değil.
        builder.HasIndex(e => e.OwnerId).HasDatabaseName(ownerIndexName);

        // Sürüm 1'den başlıyor — istemcideki `SyncableTable.version` ile
        // aynı. Yeni kayıt push'ta `baseVersion: 0` gönderiyor, yani
        // "sunucuda henüz yoktu".
        builder.Property(e => e.Version).HasDefaultValue(1).IsRequired();

        // ⚠️ `DeletedAt` SORGU SÜZGECİNE KONMUYOR — gerekçesi ISyncable'daki
        // notta: senkronizasyonun işi silmeyi TAŞIMAK. Gizleseydik ikinci
        // cihaz silmeyi hiç öğrenemezdi.
    }
}
