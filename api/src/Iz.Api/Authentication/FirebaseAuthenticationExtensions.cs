using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

namespace Iz.Api.Authentication;

/// <summary>
/// Firebase ID token doğrulaması (ADR-B15, TR-M1-05).
/// </summary>
/// <remarks>
/// KENDİ TOKEN'IMIZI ÜRETMİYORUZ. İstemci Firebase'den bir ID token alır,
/// biz onu Google'ın AÇIK anahtarlarıyla doğrularız. Doğruladığımız dört şey:
/// imza · <c>iss</c> · <c>aud</c> · <c>exp</c>.
///
/// Anahtarlar her istekte Google'dan çekilmez: <c>Authority</c> verildiğinde
/// JwtBearer, OpenID keşif belgesini ve JWKS'i kendisi indirir, önbelleğe alır
/// ve süresi dolunca tazeler. Bunu elle yazmak, anahtar döndürme (key rotation)
/// gününde sessizce her kullanıcıyı dışarıda bırakma riskidir.
/// </remarks>
public static class FirebaseAuthenticationExtensions
{
    /// <summary>Firebase ID token'larının değişmez düzenleyici (issuer) ön eki.</summary>
    private const string IssuerPrefix = "https://securetoken.google.com/";

    public static IServiceCollection AddIzFirebaseAuthentication(
        this IServiceCollection services,
        string? firebaseProjectId)
    {
        if (string.IsNullOrWhiteSpace(firebaseProjectId))
        {
            // Yerel geliştirmede Firebase projesi tanımlı olmayabilir.
            // Uygulamanın açılmasını engellemiyoruz — sağlık uçları ve
            // OpenAPI çalışmaya devam etsin. Ama kimlik isteyen her uç
            // 401 döner: "yapılandırılmadı" sessizce "herkese açık"a
            // dönüşmemeli.
            services
                .AddAuthentication(UnconfiguredAuthenticationHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, UnconfiguredAuthenticationHandler>(
                    UnconfiguredAuthenticationHandler.SchemeName, configureOptions: null);

            return services;
        }

        var issuer = IssuerPrefix + firebaseProjectId;

        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.Authority = issuer;

                // Talep adları OLDUĞU GİBİ kalsın: "sub", "email", "name".
                // Varsayılan eşleme bunları uzun ClaimTypes URI'lerine
                // çevirir ve token'ın gerçek içeriğiyle kodun okuduğu ad
                // ayrışır. Ayrışan yerde bir gün yanlış talep okunur.
                options.MapInboundClaims = false;

                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = issuer,

                    // Firebase ID token'ında "aud" proje kimliğidir. Bunu
                    // doğrulamazsak BAŞKA bir Firebase projesinin token'ı
                    // bizim API'mizde geçerli olurdu.
                    ValidateAudience = true,
                    ValidAudience = firebaseProjectId,

                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,

                    // Varsayılan 5 dakikalık tolerans, süresi dolmuş bir
                    // token'ı 5 dakika daha geçerli sayar. 30 saniye,
                    // makul saat sapmasını karşılar ve pencereyi daraltır.
                    ClockSkew = TimeSpan.FromSeconds(30),
                };
            });

        return services;
    }
}
