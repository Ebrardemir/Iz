using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using Iz.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Iz.IntegrationTests;

/// <summary>
/// <c>Idempotency-Key</c> — yol haritası §4.1.
/// </summary>
/// <remarks>
/// EKSİKLİĞİNİN BEDELİ DUPLICATE DEĞİL, YANLIŞ ÇAKIŞMA.
/// Kimlikleri istemci ürettiği için aynı gövde ikinci kez geldiğinde veri
/// çoğalmıyor. Asıl sorun sürüm: yanıtı alamadan yeniden denenen bir push,
/// ilk denemede artmış sürüm yüzünden <c>conflict</c> alır ve kullanıcıya
/// KENDİ değişikliği "başka bir sürüm" diye gösterilir. Kullanıcı açısından
/// bu, olmayan bir çakışmayı çözmek zorunda kalmak demek.
///
/// GERÇEK Redis üzerinde koşuyor (bkz. <see cref="IzApiFactory"/>).
/// </remarks>
[Collection(IzApiCollection.Name)]
public sealed class SyncIdempotencyTests(IzApiFactory factory)
{
    private async Task<(HttpClient Client, Guid DeviceId)> HesapAsync()
    {
        var (client, _) = factory.CreateAuthenticatedClient();

        var device = await (await client.PostAsJsonAsync(
                "/v1/devices", new { platform = "ios", schemaVersion = 8 }))
            .Content.ReadFromJsonAsync<JsonObject>();

        return (client, Guid.Parse(device!["id"]!.GetValue<string>()));
    }

    private static object Govde(Guid id, string baslik) => new
    {
        v = 1,
        entity = new
        {
            id = id.ToString(),
            title = baslik,
            occurred_at = "2026-03-12T10:00:00.000Z",
            occurred_year = 2026,
            occurred_month = 3,
            occurred_day = 12,
            created_at = "2026-03-12T10:00:00.000Z",
            version = 1,
        },
    };

    /// <summary>Anahtarı ÇAĞIRAN belirliyor — tekrar senaryosunun çekirdeği.</summary>
    private static async Task<HttpResponseMessage> PushAsync(
        HttpClient client,
        Guid deviceId,
        Guid aniId,
        int baseVersion,
        string baslik,
        string? anahtar)
    {
        var istek = new HttpRequestMessage(HttpMethod.Post, "/v1/sync/push")
        {
            Content = JsonContent.Create(new
            {
                deviceId,
                changes = new[]
                {
                    new
                    {
                        entityType = "memory",
                        entityId = aniId.ToString(),
                        op = "upsert",
                        baseVersion,
                        payload = Govde(aniId, baslik),
                    },
                },
            }),
        };

        if (anahtar is not null)
        {
            istek.Headers.Add("Idempotency-Key", anahtar);
        }

        return await client.SendAsync(istek);
    }

    private static async Task<(string Status, int? Version, long? Seq)> SonucAsync(
        HttpResponseMessage response)
    {
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var sonuc = (await response.Content.ReadFromJsonAsync<JsonObject>())!["results"]!
            .AsArray()[0]!;

        return (
            sonuc["status"]!.GetValue<string>(),
            sonuc["version"]?.GetValue<int>(),
            sonuc["seq"]?.GetValue<long>());
    }

    // --- Asıl mesele ------------------------------------------------------

    [Fact]
    public async Task Yeniden_denenen_push_YANLIS_CAKISMA_uretmiyor()
    {
        // BU TESTIN TARIF ETTIGI SENARYO: istemci push'u gonderdi, sunucu
        // yazdi ama YANIT ULASMADI (ag koptu). Istemci ayni istegi yeniden
        // gonderiyor.
        //
        // Anahtar olmasaydi: sunucudaki surum artik 2, istemcinin gonderdigi
        // baseVersion hala 1 -> `conflict`. Kullanici KENDI degisikligini
        // "baska bir surum" diye cozmek zorunda kalirdi.
        var (client, cihaz) = await HesapAsync();
        var aniId = Guid.CreateVersion7();
        var anahtar = Guid.NewGuid().ToString();

        await PushAsync(client, cihaz, aniId, 0, "Ilk", Guid.NewGuid().ToString());

        var ilk = await SonucAsync(
            await PushAsync(client, cihaz, aniId, 1, "Duzenlendi", anahtar));

        Assert.Equal("applied", ilk.Status);
        Assert.Equal(2, ilk.Version);

        // AYNI ANAHTAR, AYNI GOVDE — yeniden deneme.
        var tekrar = await SonucAsync(
            await PushAsync(client, cihaz, aniId, 1, "Duzenlendi", anahtar));

        Assert.Equal("applied", tekrar.Status);
        Assert.Equal(ilk.Version, tekrar.Version);

        // ILK YANIT AYNEN DONUYOR: `seq` de birebir ayni. Yeniden
        // isleseydik ya cakisma ya da yeni bir seq gorurduk.
        Assert.Equal(ilk.Seq, tekrar.Seq);
    }

    [Fact]
    public async Task Ikinci_istek_HIC_ISLENMIYOR_gunluge_satir_dusmuyor()
    {
        var (client, cihaz) = await HesapAsync();
        var aniId = Guid.CreateVersion7();
        var anahtar = Guid.NewGuid().ToString();

        await PushAsync(client, cihaz, aniId, 0, "Tek kez", anahtar);
        await PushAsync(client, cihaz, aniId, 0, "Tek kez", anahtar);
        await PushAsync(client, cihaz, aniId, 0, "Tek kez", anahtar);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        // Uc istek, TEK gunluk satiri.
        Assert.Equal(1, await db.ChangeLog.CountAsync(e => e.EntityId == aniId.ToString()));
    }

    // --- Yanlış kullanım --------------------------------------------------

    [Fact]
    public async Task Ayni_anahtar_FARKLI_govdeyle_reddediliyor()
    {
        // Kabul etseydik istemci, IKINCI batch'inin yaniti yerine
        // BIRINCISININKINI alirdi: degisiklikleri hic islenmez ama "applied"
        // gordugu icin kuyruktan dusururdu. Sessiz veri kaybinin en kolay
        // kacirilan bicimi.
        var (client, cihaz) = await HesapAsync();
        var anahtar = Guid.NewGuid().ToString();

        await PushAsync(client, cihaz, Guid.CreateVersion7(), 0, "Birinci", anahtar);

        var response = await PushAsync(
            client, cihaz, Guid.CreateVersion7(), 0, "BAMBASKA bir batch", anahtar);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var problem = await response.Content.ReadFromJsonAsync<JsonObject>();
        Assert.Equal("idempotency_key_reused", problem!["errorCode"]!.GetValue<string>());
    }

    [Fact]
    public async Task Anahtarsiz_push_REDDEDILIYOR()
    {
        // Istege bagli olsaydi, gondermeyi unutan bir istemci surumunde
        // guvence SESSIZCE yok olurdu ve kullanici bunu ancak kendi
        // degisikligini cozmek zorunda kaldiginda fark ederdi.
        //
        // Ham istemci: fabrikanin otomatik anahtar ekleyen isleyicisi YOK.
        var uid = TestTokens.NewUid();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", TestTokens.Create(uid));

        var device = await (await client.PostAsJsonAsync(
                "/v1/devices", new { platform = "ios" }))
            .Content.ReadFromJsonAsync<JsonObject>();

        var response = await PushAsync(
            client,
            Guid.Parse(device!["id"]!.GetValue<string>()),
            Guid.CreateVersion7(),
            0,
            "Anahtarsiz",
            anahtar: null);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var problem = await response.Content.ReadFromJsonAsync<JsonObject>();
        Assert.Equal("idempotency_key_required", problem!["errorCode"]!.GetValue<string>());
    }

    [Fact]
    public async Task Asiri_uzun_anahtar_reddediliyor()
    {
        // Anahtari ISTEMCI uretiyor ve dogrudan Redis anahtarina giriyor;
        // sinirsiz biraksaydik tek bir istek megabaytlik bir anahtar
        // yazdirip bellegi sisirebilirdi.
        var (client, cihaz) = await HesapAsync();

        var response = await PushAsync(
            client, cihaz, Guid.CreateVersion7(), 0, "Uzun anahtar",
            new string('k', 129));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var problem = await response.Content.ReadFromJsonAsync<JsonObject>();
        Assert.Equal("idempotency_key_invalid", problem!["errorCode"]!.GetValue<string>());
    }

    // --- Kapsam -----------------------------------------------------------

    [Fact]
    public async Task Farkli_anahtar_normal_isleniyor()
    {
        var (client, cihaz) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        var ilk = await SonucAsync(
            await PushAsync(client, cihaz, aniId, 0, "Ilk", Guid.NewGuid().ToString()));
        var ikinci = await SonucAsync(
            await PushAsync(client, cihaz, aniId, 1, "Ikinci", Guid.NewGuid().ToString()));

        Assert.Equal(1, ilk.Version);
        Assert.Equal(2, ikinci.Version);
    }

    [Fact]
    public async Task Anahtar_KULLANICI_basina_ad_alaninda()
    {
        // Anahtari istemci uretiyor. Kullaniciyla birlestirmeseydik, bir
        // kullanicinin anahtari BASKASININ kaydina carpar ve ona ait bir
        // yaniti — icinde ani metniyle birlikte — dondururduk.
        var ayniAnahtar = "iki-kullanici-ayni-anahtar";

        var (birinci, birinciCihaz) = await HesapAsync();
        var birinciAni = Guid.CreateVersion7();
        var a = await SonucAsync(
            await PushAsync(birinci, birinciCihaz, birinciAni, 0, "Birincinin", ayniAnahtar));

        var (ikinci, ikinciCihaz) = await HesapAsync();
        var ikinciAni = Guid.CreateVersion7();
        var b = await SonucAsync(
            await PushAsync(ikinci, ikinciCihaz, ikinciAni, 0, "Ikincinin", ayniAnahtar));

        // Ikisi de gercekten islendi; ikincisi birincinin yanitini almadi.
        Assert.Equal("applied", a.Status);
        Assert.Equal("applied", b.Status);
        Assert.NotEqual(a.Seq, b.Seq);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        Assert.True(await db.Set<Domain.Memories.Memory>().IgnoreQueryFilters()
            .AnyAsync(m => m.Id == ikinciAni));
    }
}
