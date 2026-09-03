using System.Net;
using System.Net.Http.Json;
using Iz.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Iz.IntegrationTests;

/// <summary>TRD M1: profil ve hesap açılışı.</summary>
[Collection(IzApiCollection.Name)]
public sealed class MeEndpointTests(IzApiFactory factory)
{
    [Fact]
    public async Task Ilk_istekte_kullanici_kaydi_acilir()
    {
        // ADR-B15'in doğrudan sonucu: ayrı bir "kayıt ol" ucu yok.
        // Geçerli token'ın ilk gelişi hesabın bizde açılması demek.
        var uid = TestTokens.NewUid();
        var client = factory.CreateClientWithToken(
            TestTokens.Create(uid, email: "biri@ornek.com", displayName: "Ebru"));

        var me = await client.GetFromJsonAsync<MePayload>("/v1/me");

        Assert.NotNull(me);
        Assert.Equal("biri@ornek.com", me.Email);
        Assert.Equal("Ebru", me.DisplayName);
        Assert.NotEqual(Guid.Empty, me.Id);

        // Kimliğimiz Firebase uid'si DEĞİL, kendi UUID'miz.
        Assert.NotEqual(uid, me.Id.ToString());
    }

    [Fact]
    public async Task Ayni_kullanici_iki_kez_kayit_acmaz()
    {
        var uid = TestTokens.NewUid();
        var client = factory.CreateClientWithToken(TestTokens.Create(uid, "tekrar@ornek.com"));

        var ilk = await client.GetFromJsonAsync<MePayload>("/v1/me");
        var ikinci = await client.GetFromJsonAsync<MePayload>("/v1/me");

        Assert.NotNull(ilk);
        Assert.NotNull(ikinci);
        Assert.Equal(ilk.Id, ikinci.Id);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();
        var kayitSayisi = await db.Users.CountAsync(u => u.FirebaseUid == uid);

        Assert.Equal(1, kayitSayisi);
    }

    [Fact]
    public async Task Yeni_kullanici_free_planda_baslar()
    {
        // ADR-B09: senkronizasyon İZ+ özelliği. Varsayılanın "free" olması
        // yalnız bir varsayılan değil, sync kapısının kapalı başlaması demek.
        var (client, _) = factory.CreateAuthenticatedClient();

        var me = await client.GetFromJsonAsync<MePayload>("/v1/me");

        Assert.NotNull(me);
        Assert.Equal("free", me.Plan);
    }

    [Fact]
    public async Task Firebase_tarafinda_degisen_eposta_bizde_de_tazelenir()
    {
        // TR-M1-06: tek gerçek kaynak Firebase; bizdeki kopya güncel kalmalı,
        // yoksa hesap silme ve destek yanlış adrese gider.
        var uid = TestTokens.NewUid();

        var eski = factory.CreateClientWithToken(TestTokens.Create(uid, "eski@ornek.com"));
        await eski.GetFromJsonAsync<MePayload>("/v1/me");

        var yeni = factory.CreateClientWithToken(TestTokens.Create(uid, "yeni@ornek.com"));
        var me = await yeni.GetFromJsonAsync<MePayload>("/v1/me");

        Assert.NotNull(me);
        Assert.Equal("yeni@ornek.com", me.Email);
    }

    [Fact]
    public async Task Profil_guncellenir()
    {
        var (client, _) = factory.CreateAuthenticatedClient();
        await client.GetAsync("/v1/me");

        var response = await client.PatchAsJsonAsync(
            "/v1/me", new { displayName = "Yeni Ad", locale = "tr-TR" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var me = await response.Content.ReadFromJsonAsync<MePayload>();
        Assert.NotNull(me);
        Assert.Equal("Yeni Ad", me.DisplayName);
        Assert.Equal("tr-TR", me.Locale);
    }

    [Fact]
    public async Task Bos_birakilan_alan_degismez()
    {
        // PATCH semantiği: null "dokunma" demek, "boşalt" demek değil.
        var (client, _) = factory.CreateAuthenticatedClient();
        await client.PatchAsJsonAsync("/v1/me", new { displayName = "Kalıcı", locale = "tr-TR" });

        var response = await client.PatchAsJsonAsync("/v1/me", new { locale = "en-US" });
        var me = await response.Content.ReadFromJsonAsync<MePayload>();

        Assert.NotNull(me);
        Assert.Equal("Kalıcı", me.DisplayName);
        Assert.Equal("en-US", me.Locale);
    }

    [Fact]
    public async Task Cok_uzun_ad_alan_bilgisiyle_reddedilir()
    {
        var (client, _) = factory.CreateAuthenticatedClient();

        var response = await client.PatchAsJsonAsync(
            "/v1/me", new { displayName = new string('a', 101) });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(
            "application/problem+json",
            response.Content.Headers.ContentType?.MediaType);

        var problem = await response.Content.ReadFromJsonAsync<ProblemPayload>();
        Assert.NotNull(problem);

        // İstemci metne değil koda bakar; hatayı doğru form alanının
        // altında gösterebilmesi için "field" da gelmeli (TRD §1.2).
        Assert.Equal("display_name_too_long", problem.ErrorCode);
        Assert.Equal("displayName", problem.Field);
    }

    private sealed record MePayload(
        Guid Id,
        string? Email,
        string? DisplayName,
        string? Locale,
        string Plan,
        DateTimeOffset CreatedAt);

    private sealed record ProblemPayload(string? ErrorCode, string? Field);
}
