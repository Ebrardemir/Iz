using Iz.Application.Abstractions;
using Iz.Domain.Devices;
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

        base.OnModelCreating(modelBuilder);
    }
}
