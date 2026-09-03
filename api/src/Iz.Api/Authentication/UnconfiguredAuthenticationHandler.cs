using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace Iz.Api.Authentication;

/// <summary>
/// Firebase yapılandırılmadığında devreye giren şema: her isteği reddeder.
/// </summary>
/// <remarks>
/// "Yapılandırma eksikse kimlik doğrulamayı atla" en tehlikeli varsayılandır —
/// üretimde bir ortam değişkeni unutulduğunda API sessizce herkese açılır.
/// Bu sınıf o ihtimali kapatır: eksik yapılandırma 401 üretir.
/// </remarks>
public sealed class UnconfiguredAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "FirebaseYapilandirilmadi";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        => Task.FromResult(AuthenticateResult.Fail(
            "Firebase proje kimliği yapılandırılmadı (IZ_Iz__FirebaseProjectId)."));
}
