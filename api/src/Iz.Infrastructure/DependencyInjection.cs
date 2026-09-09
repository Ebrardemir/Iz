using Iz.Application.Abstractions;
using Iz.Application.Devices;
using Iz.Application.Sync;
using Iz.Application.Users;
using Iz.Infrastructure.Persistence;
using Iz.Infrastructure.Persistence.Interceptors;
using Iz.Infrastructure.Sync;
using Iz.Infrastructure.Time;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using StackExchange.Redis;

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
    /// <param name="redisConnection">
    /// Redis bağlantı dizesi. Boşsa idempotency güvencesi KAPALI olur
    /// (<see cref="NullIdempotencyStore"/>); üretimde bu duruma izin
    /// verilmiyor, kontrol <c>Program.cs</c>'te.
    /// </param>
    public static IServiceCollection AddIzInfrastructure(
        this IServiceCollection services,
        string connectionString,
        string? redisConnection = null)
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
        services.AddScoped<ISyncStore, SyncStore>();
        services.AddScoped<ISyncLock, PostgresSyncLock>();
        if (string.IsNullOrWhiteSpace(redisConnection))
        {
            services.AddScoped<IIdempotencyStore, NullIdempotencyStore>();
        }
        else
        {
            // ⚠️ `AbortOnConnectFail = false` ŞART. Varsayılan `true` ile
            // Redis açılış anında erişilemezse `Connect` istisna atar ve
            // UYGULAMA HİÇ AÇILMAZ — yani senkronizasyonun tamamı, yalnız
            // yanlış çakışmayı önleyen bir yardımcı yüzünden durur.
            // `false` ile bağlantı arka planda kurulmaya çalışılır ve
            // kurulana kadar depo hatalarını yutar.
            var config = ConfigurationOptions.Parse(redisConnection);
            config.AbortOnConnectFail = false;

            services.AddSingleton<IConnectionMultiplexer>(
                _ => ConnectionMultiplexer.Connect(config));

            services.AddScoped<IIdempotencyStore, RedisIdempotencyStore>();
        }

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
        services.AddScoped<PushChangesHandler>();
        services.AddScoped<PullChangesHandler>();
        services.AddScoped<GetSyncStateHandler>();

        return services;
    }
}
