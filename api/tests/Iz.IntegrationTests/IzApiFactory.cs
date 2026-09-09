using System.Net.Http.Headers;
using Iz.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Testcontainers.PostgreSql;
using Testcontainers.Redis;

namespace Iz.IntegrationTests;

/// <summary>
/// Testler için API'yi GERÇEK bir PostgreSQL ile ayağa kaldırır.
/// </summary>
/// <remarks>
/// Bellek içi sağlayıcı KULLANMIYORUZ (yol haritası §8). Gerekçesi somut:
/// bu projede test etmek istediğimiz şeylerin çoğu — benzersizlik kısıtı,
/// yabancı anahtar, <c>snake_case</c> eşlemesi, migration'ın gerçekten
/// çalışması — bellek içi sağlayıcıda YOKTUR. Orada yeşil yanan bir test,
/// üretimde kırmızı olacak bir davranışı onaylar.
///
/// Konteyner test sınıfları arasında paylaşılır; her test kendi benzersiz
/// Firebase kimliğini kullandığı için birbirlerine değmezler.
/// </remarks>
public sealed class IzApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    // docker-compose ile AYNI imaj: testte geçip üretimde patlayan bir
    // sürüm farkı olmasın.
    private readonly PostgreSqlContainer _postgres =
        new PostgreSqlBuilder("postgres:17-alpine").Build();

    /// <summary>
    /// GERÇEK Redis — sahte bir idempotency deposu KULLANMIYORUZ.
    /// </summary>
    /// <remarks>
    /// Aynı gerekçe Postgres'teki gibi: test etmek istediğimiz şeylerin bir
    /// kısmı (TTL, anahtar ad alanı, bağlantı kopunca hataların yutulması)
    /// bellek içi bir sözlükte YOKTUR. Orada yeşil yanan bir test, üretimde
    /// kırmızı olacak bir davranışı onaylar.
    ///
    /// docker-compose ile AYNI imaj.
    /// </remarks>
    private readonly RedisContainer _redis =
        new RedisBuilder("redis:7-alpine").Build();

    public async Task InitializeAsync()
    {
        await Task.WhenAll(_postgres.StartAsync(), _redis.StartAsync());

        // Şemayı migration'larla kuruyoruz — EnsureCreated ile değil.
        // Böylece her test koşusu migration zincirinin gerçekten
        // çalıştığını da doğrulamış oluyor.
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();
        await db.Database.MigrateAsync();
    }

    public new async Task DisposeAsync()
    {
        await _postgres.DisposeAsync();
        await _redis.DisposeAsync();
        await base.DisposeAsync();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("Iz:DatabaseConnection", _postgres.GetConnectionString());
        builder.UseSetting("Iz:RedisConnection", _redis.GetConnectionString());
        builder.UseSetting("Iz:FirebaseProjectId", TestTokens.ProjectId);
        builder.UseSetting("Iz:Environment", "test");

        builder.ConfigureTestServices(services =>
        {
            // Google'ın anahtar sunucusuna ÇIKMADAN doğrulama yap.
            // Değiştirdiğimiz tek şey imzalama anahtarı; iss/aud/exp
            // kontrolleri üretimdeki ayarların aynısı kalıyor.
            services.PostConfigure<JwtBearerOptions>(
                JwtBearerDefaults.AuthenticationScheme,
                options =>
                {
                    options.Authority = null;
                    options.RequireHttpsMetadata = false;

                    // Boş yapılandırma: handler keşif belgesini indirmeye
                    // çalışmaz. Bu satır olmazsa testler ağa çıkar.
                    options.Configuration = new OpenIdConnectConfiguration();

                    options.TokenValidationParameters.IssuerSigningKey = TestTokens.SigningKey;
                    options.TokenValidationParameters.ValidateIssuerSigningKey = true;
                });
        });
    }

    /// <summary>Verilen token ile kimliklenmiş bir istemci döndürür.</summary>
    /// <remarks>
    /// İstemci, <c>Idempotency-Key</c> başlığı olmayan her push'a KENDİLİĞİNDEN
    /// yeni bir anahtar ekliyor — gerçek uygulamanın retry katmanının yapacağı
    /// şeyin aynısı. Böylece anahtarla ilgilenmeyen testler onu her çağrıda
    /// tekrarlamak zorunda kalmıyor.
    ///
    /// Anahtarı KENDİ koyan testler (idempotency testleri) bu davranıştan
    /// etkilenmiyor; anahtarın ZORUNLU olduğunu sınayan test ise
    /// <see cref="CreateClient"/> ile ham bir istemci kuruyor.
    /// </remarks>
    public HttpClient CreateClientWithToken(string token)
    {
        var client = CreateDefaultClient(new OtomatikIdempotencyKey());
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }

    /// <inheritdoc cref="CreateClientWithToken"/>
    private sealed class OtomatikIdempotencyKey : DelegatingHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            if (!request.Headers.Contains("Idempotency-Key"))
            {
                request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
            }

            return base.SendAsync(request, cancellationToken);
        }
    }

    /// <summary>Yeni bir kullanıcı için kimliklenmiş istemci ve kimliği birlikte üretir.</summary>
    public (HttpClient Client, string Uid) CreateAuthenticatedClient(
        string? email = null,
        string? displayName = null)
    {
        var uid = TestTokens.NewUid();
        return (CreateClientWithToken(TestTokens.Create(uid, email, displayName)), uid);
    }
}

/// <summary>
/// Konteyneri her test sınıfı için yeniden başlatmamak adına tek koleksiyon.
/// </summary>
[CollectionDefinition(Name)]
public sealed class IzApiCollection : ICollectionFixture<IzApiFactory>
{
    public const string Name = "iz-api";
}
