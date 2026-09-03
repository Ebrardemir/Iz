using System.Net;
using System.Net.Http.Headers;

namespace Iz.IntegrationTests;

/// <summary>
/// TR-M1-05: sunucu ID token'ı imza, <c>aud</c>, <c>iss</c> ve <c>exp</c>
/// açısından doğrular. Bu testler o cümlenin dört yarısını ayrı ayrı sınar.
/// </summary>
[Collection(IzApiCollection.Name)]
public sealed class AuthenticationTests(IzApiFactory factory)
{
    [Fact]
    public async Task Tokensiz_istek_401_alir()
    {
        var response = await factory.CreateClient().GetAsync("/v1/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Bozuk_token_401_alir()
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", "bu.bir.token.degil");

        var response = await client.GetAsync("/v1/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Baska_anahtarla_imzalanmis_token_401_alir()
    {
        // Saldırganın kendi ürettiği token: yapı doğru, imza yanlış.
        var token = TestTokens.CreateWithForeignSignature(TestTokens.NewUid());

        var response = await factory.CreateClientWithToken(token).GetAsync("/v1/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Suresi_dolmus_token_401_alir()
    {
        var token = TestTokens.CreateExpired(TestTokens.NewUid());

        var response = await factory.CreateClientWithToken(token).GetAsync("/v1/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Baska_Firebase_projesinin_tokeni_401_alir()
    {
        // "aud" doğrulamasının varlık sebebi: Firebase'de herkes proje
        // açabilir. Hedef kitleyi kontrol etmezsek başkasının projesinde
        // açılmış bir hesap bizim API'mizde geçerli olurdu.
        var token = TestTokens.Create(
            TestTokens.NewUid(),
            issuer: "https://securetoken.google.com/baska-proje",
            audience: "baska-proje");

        var response = await factory.CreateClientWithToken(token).GetAsync("/v1/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Gecerli_token_kabul_edilir()
    {
        var (client, _) = factory.CreateAuthenticatedClient();

        var response = await client.GetAsync("/v1/me");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
