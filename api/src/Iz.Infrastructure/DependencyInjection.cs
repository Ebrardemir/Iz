using Iz.Application.Abstractions;
using Iz.Application.Devices;
using Iz.Application.Users;
using Iz.Infrastructure.Persistence;
using Iz.Infrastructure.Time;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Iz.Infrastructure;

public static class DependencyInjection
{
    /// <summary>
    /// Veri erişimi ve use-case'leri kaydeder.
    /// </summary>
    /// <param name="connectionString">
    /// PostgreSQL bağlantı dizesi. Depoda değil, ortam değişkeninde durur
    /// (<c>IZ_Iz__DatabaseConnection</c>).
    /// </param>
    public static IServiceCollection AddIzInfrastructure(
        this IServiceCollection services,
        string connectionString)
    {
        services.AddDbContext<IzDbContext>(options => options
            .UseNpgsql(connectionString)
            // Tablo ve sütunlar snake_case: users, firebase_uid, last_seen_at.
            // Elle eşlemek yerine kural koyuyoruz — 2 tabloda fark etmez ama
            // Faz 3'te 15 tablo × ~15 sütun olacak ve orada tek harflik bir
            // yazım hatası saatler yer.
            .UseSnakeCaseNamingConvention());

        services.AddScoped<IUnitOfWork, EfUnitOfWork>();
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IDeviceRepository, DeviceRepository>();

        services.AddSingleton<IClock, SystemClock>();

        // Use-case'ler: durumsuz, isteğe bağlı ömürlü.
        services.AddScoped<EnsureUserHandler>();
        services.AddScoped<UpdateProfileHandler>();
        services.AddScoped<RegisterDeviceHandler>();

        return services;
    }
}
