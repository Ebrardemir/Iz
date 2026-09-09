using Iz.Application.Abstractions;
using Iz.Domain.Devices;
using Iz.Domain.Memories;
using Iz.Domain.Sync;
using Iz.Domain.Users;
using Microsoft.EntityFrameworkCore;

namespace Iz.Infrastructure.Persistence;

/// <summary>
/// Sunucu veritabanı. Tablo ve sütun adları snake_case
/// (BACKEND_YOL_HARITASI §3'teki model birebir korunur).
/// </summary>
public sealed class IzDbContext(DbContextOptions<IzDbContext> options, ICurrentUser currentUser)
    : DbContext(options)
{
    public DbSet<User> Users => Set<User>();

    public DbSet<Device> Devices => Set<Device>();

    /// <summary>
    /// Senkronizasyonun kalbi. Satırları ELLE EKLENMİYOR —
    /// <c>ChangeLogInterceptor</c> her <c>SaveChanges</c>'te kendisi
    /// üretiyor (yol haritası §3.1).
    /// </summary>
    public DbSet<ChangeLogEntry> ChangeLog => Set<ChangeLogEntry>();

    // ---- Senkronize edilen içerik -------------------------------------
    public DbSet<Memory> Memories => Set<Memory>();

    public DbSet<MemoryPerson> MemoryPeople => Set<MemoryPerson>();

    public DbSet<MemoryCollection> MemoryCollections => Set<MemoryCollection>();

    public DbSet<MemoryRitual> MemoryRituals => Set<MemoryRitual>();

    public DbSet<MemoryMedia> MemoryMedia => Set<MemoryMedia>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(IzDbContext).Assembly);

        // ---- IDOR'a karşı ikinci hat (TR-M14-22, §7.2) -------------------
        // Repository'ler zaten userId ile sorguluyor. Bu süzgeç onun yerine
        // değil, ÜSTÜNE geçer: yarın biri filtreyi yazmayı unutan yeni bir
        // sorgu eklerse, sorgu boş döner — başkasının verisini döndürmez.
        // Güvenlik kuralının "hatırlanması gereken" değil "unutulamayan"
        // olması gerekir.
        //
        // Kullanıcı yoksa (sağlık uçları, arka plan işleri) süzgeç hiçbir
        // satır geçirmez. Sessizce her şeyi açmaktansa sessizce hiçbir şey
        // vermek doğru varsayılandır.
        modelBuilder.Entity<Device>()
            .HasQueryFilter(d => currentUser.UserId != null && d.UserId == currentUser.UserId);

        // Senkronize edilen her tablo aynı hattı alıyor. Süzgeç SAHİPLİĞE
        // bakıyor, tombstone'a DEĞİL: silinmiş satırı gizleseydik pull
        // silmeyi hiç göremez, ikinci cihazda kayıt sonsuza kadar yaşardı
        // (bkz. ISyncable.DeletedAt).
        //
        // ⚠️ YENİ BİR SENKRONİZE TABLO EKLERKEN buraya da bir satır gerekiyor.
        // Unutmak IDOR demek — bu yüzden `SyncQueryFilterTests` her
        // `ISyncable` tipinin süzgeci olduğunu denetliyor ve eksikse testler
        // kırmızıya döner.
        modelBuilder.Entity<Memory>()
            .HasQueryFilter(m => currentUser.UserId != null && m.OwnerId == currentUser.UserId);
        modelBuilder.Entity<MemoryPerson>()
            .HasQueryFilter(l => currentUser.UserId != null && l.OwnerId == currentUser.UserId);
        modelBuilder.Entity<MemoryCollection>()
            .HasQueryFilter(l => currentUser.UserId != null && l.OwnerId == currentUser.UserId);
        modelBuilder.Entity<MemoryRitual>()
            .HasQueryFilter(l => currentUser.UserId != null && l.OwnerId == currentUser.UserId);
        modelBuilder.Entity<MemoryMedia>()
            .HasQueryFilter(l => currentUser.UserId != null && l.OwnerId == currentUser.UserId);

        base.OnModelCreating(modelBuilder);
    }
}
