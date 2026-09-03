namespace Iz.Application.Users;

/// <summary>
/// DOĞRULANMIŞ Firebase ID token'ından okunan kimlik.
/// </summary>
/// <remarks>
/// Bu tipin var olma sebebi tek bir kural: TR-M1-05 — "istemcinin ilettiği
/// uid'ye güvenilmez". Use-case'ler <c>HttpContext</c> görmez; yalnız bu
/// kaydı alır. Kaydı üretebilen tek yer ise imzası doğrulanmış token'ı
/// çözen kimlik doğrulama katmanıdır. Yani gövdeden gelen bir uid'nin
/// buraya sızabileceği bir yol yoktur.
/// </remarks>
/// <param name="FirebaseUid">Token'ın <c>sub</c> alanı.</param>
/// <param name="Email">Token'ın <c>email</c> alanı; sağlayıcıya göre boş olabilir.</param>
/// <param name="EmailVerified">Firebase e-postayı doğruladı mı.</param>
/// <param name="DisplayName">Token'ın <c>name</c> alanı (Apple/Google girişinde gelir).</param>
public sealed record AuthenticatedIdentity(
    string FirebaseUid,
    string? Email,
    bool EmailVerified,
    string? DisplayName);
