using Iz.Application.Abstractions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Iz.Infrastructure.Persistence;

/// <summary>
/// <c>dotnet ef migrations add</c> için DbContext üretir.
/// </summary>
/// <remarks>
/// NEDEN GEREKLİ? EF araçları normalde uygulamanın <c>Program.cs</c>'ini
/// çalıştırıp DI konteynerinden DbContext'i alır. Bunu yapabilmesi için
/// uygulamanın açılışta gerçek bir veritabanına ihtiyaç duymaması gerekir —
/// bizimki duyuyor (bağlantı dizesi zorunlu). Bu fabrika o bağı kesiyor:
/// migration üretmek için veritabanı ÇALIŞIYOR OLMAK ZORUNDA DEĞİL, çünkü
/// migration yalnız model ile önceki migration'ı karşılaştırır.
/// </remarks>
internal sealed class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<IzDbContext>
{
    public IzDbContext CreateDbContext(string[] args)
    {
        // Yedek değer docker-compose'daki YEREL geliştirme veritabanıdır —
        // aynı şifre compose dosyasında da açıkça duruyor. Bu bir sır değil
        // ve olmamalı: gerçek ortamların bağlantı dizesi yalnız
        // IZ_Iz__DatabaseConnection'dan gelir (TR-M14, §7.4).
        var connectionString =
            Environment.GetEnvironmentVariable("IZ_Iz__DatabaseConnection")
            ?? "Host=localhost;Port=5432;Database=iz;Username=iz;Password=gelistirme";

        var options = new DbContextOptionsBuilder<IzDbContext>()
            .UseNpgsql(connectionString)
            .UseSnakeCaseNamingConvention()
            .Options;

        return new IzDbContext(options, NoCurrentUser.Instance);
    }

    /// <summary>Tasarım zamanında oturum açmış kullanıcı yoktur.</summary>
    private sealed class NoCurrentUser : ICurrentUser
    {
        public static readonly NoCurrentUser Instance = new();

        public Guid? UserId => null;
    }
}
