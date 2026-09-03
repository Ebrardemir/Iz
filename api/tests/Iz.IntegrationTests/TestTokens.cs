using System.IdentityModel.Tokens.Jwt;
using System.Security.Cryptography;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Iz.IntegrationTests;

/// <summary>
/// Testler için Firebase biçiminde ID token üretir.
/// </summary>
/// <remarks>
/// NEDEN GERÇEK FIREBASE'E GİTMİYORUZ? Test paketi ağa çıkmamalı: yavaşlar,
/// kesintide kırmızı yanar ve CI'a bir sır koymayı gerektirir.
///
/// Buna karşılık doğrulamanın KENDİSİNİ atlamıyoruz. Yalnız imzalama
/// anahtarını değiştiriyoruz; <c>iss</c>, <c>aud</c> ve <c>exp</c> kontrolleri
/// üretimdeki kodun aynısı. Yani "yanlış hedef kitleli token reddedilir mi?"
/// sorusunu gerçekten test ediyoruz — sahte bir kimlik doğrulayıcıyla test
/// etseydik o soruyu hiç sormamış olurduk.
/// </remarks>
public static class TestTokens
{
    /// <summary>Testlerin kullandığı sahte Firebase proje kimliği.</summary>
    public const string ProjectId = "iz-test-projesi";

    public const string Issuer = "https://securetoken.google.com/" + ProjectId;

    /// <summary>
    /// Simetrik imzalama anahtarı. Yalnız testlerde; üretimde imzayı Google atar.
    /// </summary>
    public static readonly SymmetricSecurityKey SigningKey =
        new(SHA256.HashData("iz-entegrasyon-testleri-icin-sabit-anahtar"u8.ToArray()));

    public static string Create(
        string firebaseUid,
        string? email = null,
        string? displayName = null,
        string? issuer = null,
        string? audience = null,
        TimeSpan? lifetime = null)
    {
        var claims = new Dictionary<string, object>
        {
            ["sub"] = firebaseUid,
            ["email_verified"] = true,
        };

        if (email is not null)
        {
            claims["email"] = email;
        }

        if (displayName is not null)
        {
            claims["name"] = displayName;
        }

        var now = DateTime.UtcNow;
        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = issuer ?? Issuer,
            Audience = audience ?? ProjectId,
            IssuedAt = now,
            NotBefore = now.AddMinutes(-1),
            Expires = now.Add(lifetime ?? TimeSpan.FromMinutes(30)),
            Claims = claims,
            SigningCredentials = new SigningCredentials(SigningKey, SecurityAlgorithms.HmacSha256),
        };

        return new JsonWebTokenHandler().CreateToken(descriptor);
    }

    /// <summary>Süresi çoktan dolmuş token.</summary>
    public static string CreateExpired(string firebaseUid)
    {
        var now = DateTime.UtcNow;
        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = Issuer,
            Audience = ProjectId,
            IssuedAt = now.AddHours(-2),
            NotBefore = now.AddHours(-2),
            // ClockSkew 30 sn; bir saat öncesi her koşulda dışarıda.
            Expires = now.AddHours(-1),
            Claims = new Dictionary<string, object> { ["sub"] = firebaseUid },
            SigningCredentials = new SigningCredentials(SigningKey, SecurityAlgorithms.HmacSha256),
        };

        return new JsonWebTokenHandler().CreateToken(descriptor);
    }

    /// <summary>Başka bir anahtarla imzalanmış token — imza doğrulaması için.</summary>
    public static string CreateWithForeignSignature(string firebaseUid)
    {
        var foreignKey = new SymmetricSecurityKey(
            SHA256.HashData("baska-birinin-anahtari-bu-gecerli-olmamali"u8.ToArray()));

        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = Issuer,
            Audience = ProjectId,
            Expires = DateTime.UtcNow.AddMinutes(30),
            Claims = new Dictionary<string, object> { ["sub"] = firebaseUid },
            SigningCredentials = new SigningCredentials(foreignKey, SecurityAlgorithms.HmacSha256),
        };

        return new JsonWebTokenHandler().CreateToken(descriptor);
    }

    /// <summary>Testte benzersiz bir Firebase kimliği üretir.</summary>
    public static string NewUid() => "test-uid-" + Guid.NewGuid().ToString("N");

    static TestTokens()
    {
        // Talep adları OLDUĞU GİBİ kalsın ("sub" → "sub"). Sunucu tarafındaki
        // MapInboundClaims = false ile aynı karar; testin ürettiği token
        // üretimdekinden farklı görünmemeli.
        JwtSecurityTokenHandler.DefaultInboundClaimTypeMap.Clear();
    }
}
