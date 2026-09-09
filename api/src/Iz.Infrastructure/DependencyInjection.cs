using Iz.Application.Abstractions;
using Iz.Application.Devices;
using Iz.Application.Users;
using Iz.Infrastructure.Persistence;
using Iz.Infrastructure.Persistence.Interceptors;
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
        // Interceptor'ın kendisi istek başına ömürlü: içindeki `ISyncOrigin`
        // o isteğe ait. Singleton olsaydı bir kullanıcının cihaz kimliği
        // başka bir kullanıcının günlüğüne yazılırdı.
        services.AddScoped<ChangeLogInterceptor>();

        services.AddDbContext<IzDbContext>((provider, options) => options
            .UseNpgsql(connectionString)
            // ⚠️ change_log'a yazmayı BU SATIR garanti ediyor. Kaldırıldığı
            // an her şey derlenir, testlerin çoğu geçer ve hiçbir değişiklik
            // ikinci cihaza gitmez (yol haritası §3.1).
            .AddInterceptors(provider.GetRequiredService<ChangeLogInterceptor>())
            // Tablo ve sütunlar snake_case: users, firebase_uid, last_seen_at.
            // Elle eşlemek yerine kural koyuyoruz — 2 tabloda fark etmez ama
            // Faz 3'te 15 tablo × ~15 sütun olacak ve orada tek harflik bir
            // yazım hatası saatler yer.
            .UseSnakeCaseNamingConvention());

        services.AddScoped<IUnitOfWork, EfUnitOfWork>();
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IDeviceRepository, DeviceRepository>();

        services.AddSingleton<IClock, SystemClock>();

        // İstek başına: cihazı push işleyicisi, gövdeyi doğruladıktan sonra
        // yazıyor. İki arayüz aynı örneği görüyor — biri yazsın diye,
        // öteki yalnız okusun diye.
        services.AddScoped<SyncOrigin>();
        services.AddScoped<ISyncOrigin>(provider => provider.GetRequiredService<SyncOrigin>());

        // Use-case'ler: durumsuz, isteğe bağlı ömürlü.
        services.AddScoped<EnsureUserHandler>();
        services.AddScoped<UpdateProfileHandler>();
        services.AddScoped<RegisterDeviceHandler>();

        return services;
    }
}
