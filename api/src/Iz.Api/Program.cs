using System.Text.Json;
using Iz.Api;
using Iz.Api.Authentication;
using Iz.Api.Endpoints;
using Iz.Api.ErrorHandling;
using Iz.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

// --- Yapılandırma ---------------------------------------------------------
// Ortam değişkenleri appsettings'in ÜSTÜNE yazar. Sırlar yalnız oradan gelir.
builder.Configuration.AddEnvironmentVariables(prefix: "IZ_");

var izSection = builder.Configuration.GetSection(IzOptions.SectionName);
builder.Services.Configure<IzOptions>(izSection);
var izOptions = izSection.Get<IzOptions>() ?? new IzOptions();

// --- Loglama --------------------------------------------------------------
// Konsola JSON: hangi barındırmaya gidersek gidelim, satırlar yapılandırılmış
// biçimde toplanabilsin. Ayrı bir log kütüphanesi eklemiyoruz — henüz
// ihtiyaç yok, ve her bağımlılık bir bakım yükü.
builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(o =>
{
    o.IncludeScopes = true;
    o.JsonWriterOptions = new JsonWriterOptions { Indented = false };
});

// --- Hata gövdesi ---------------------------------------------------------
// Rapor 22.1: standart hata gövdesi (RFC 9457 ProblemDetails).
// İstemci tarafındaki Failure hiyerarşisi buna göre eşleniyor.
builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = context =>
    {
        // İstemcinin dallanacağı makine-okunur kod. Metin değişebilir, bu değişmez.
        // TryAdd: AppExceptionHandler daha özel bir kod yazdıysa üzerine yazılmaz.
        context.ProblemDetails.Extensions.TryAdd(
            "errorCode",
            context.ProblemDetails.Status switch
            {
                StatusCodes.Status400BadRequest => "bad_request",
                StatusCodes.Status401Unauthorized => "unauthorized",
                StatusCodes.Status403Forbidden => "forbidden",
                StatusCodes.Status404NotFound => "not_found",
                StatusCodes.Status409Conflict => "conflict",
                StatusCodes.Status429TooManyRequests => "rate_limited",
                _ => "unexpected",
            });

        // İzlenebilirlik: kullanıcı hatayı bildirdiğinde logda bulabilelim.
        context.ProblemDetails.Extensions.TryAdd(
            "traceId", context.HttpContext.TraceIdentifier);
    };
});

builder.Services.AddExceptionHandler<AppExceptionHandler>();

// --- Veri erişimi ve use-case'ler ----------------------------------------
builder.Services.AddIzInfrastructure(RequireDatabaseConnection(izOptions));

// --- Kimlik ---------------------------------------------------------------
// ADR-B15: doğrulama Google'da, karar bizde.
builder.Services.AddScoped<CurrentUserContext>();
builder.Services.AddScoped<Iz.Application.Abstractions.ICurrentUser>(
    sp => sp.GetRequiredService<CurrentUserContext>());
builder.Services.AddIzFirebaseAuthentication(izOptions.FirebaseProjectId);
builder.Services.AddAuthorization();

// --- Sağlık kontrolleri ---------------------------------------------------
// İki ayrı uç nokta, çünkü iki ayrı soru soruyorlar:
//   /health/live  → süreç ayakta mı? (yeniden başlatılmalı mı)
//   /health/ready → istek alabilir mi? (trafiğe açılmalı mı)
// Bağımlılık kontrolleri Faz 1'de "ready"ye eklenecek.
builder.Services.AddHealthChecks();

// --- OpenAPI --------------------------------------------------------------
// ADR-B03: sözleşme sunucu koddan üretilir, istemci client'ı ondan üretilir.
builder.Services.AddOpenApi("v1");

var app = builder.Build();

// Yakalanmamış istisnalar da ProblemDetails olarak döner; yığın izi SIZMAZ.
app.UseExceptionHandler();
app.UseStatusCodePages();

app.MapOpenApi();

app.UseAuthentication();
app.UseAuthorization();

// Kimliği kendi kullanıcı kaydımıza bağlar. UseAuthentication'dan SONRA
// olmak zorunda: doğrulanmamış bir token'dan uid okumak, hiç doğrulamamakla
// aynı şeydir.
app.UseMiddleware<CurrentUserMiddleware>();

app.MapHealthChecks("/health/live");
app.MapHealthChecks("/health/ready");

// Sürüm ve ortam bilgisi — dağıtımın gerçekten güncellendiğini doğrulamak için.
app.MapGet("/health", (IConfiguration config) => Results.Ok(new
{
    status = "ok",
    environment = config[$"{IzOptions.SectionName}:Environment"] ?? "dev",
}))
.WithName("Health")
.WithSummary("Servisin ayakta olduğunu ve hangi ortamda çalıştığını bildirir.");

app.MapMeEndpoints();
app.MapDeviceEndpoints();

app.Run();

/// <summary>
/// Veritabanı bağlantı dizesi olmadan AÇILMAYIZ.
/// </summary>
/// <remarks>
/// Alternatifi — eksikse boş geçip ilk sorguda patlamak — arızayı dağıtımdan
/// saatler sonra, ilk gerçek kullanıcının isteğinde ortaya çıkarır. Sağlık
/// yoklaması o sırada yeşil yanıyor olur; çünkü sağlık ucu veritabanına
/// dokunmuyor. Yanlış yapılandırmanın en ucuz bulunduğu an açılış anıdır.
/// </remarks>
static string RequireDatabaseConnection(IzOptions options)
    => string.IsNullOrWhiteSpace(options.DatabaseConnection)
        ? throw new InvalidOperationException(
            "Veritabanı bağlantı dizesi tanımlı değil. " +
            "IZ_Iz__DatabaseConnection ortam değişkenini ayarlayın.")
        : options.DatabaseConnection;

/// <summary>
/// Entegrasyon testleri <c>WebApplicationFactory&lt;Program&gt;</c> ile
/// uygulamayı ayağa kaldırıyor; bunun için Program tipinin görünür olması gerekiyor.
/// </summary>
public partial class Program;
