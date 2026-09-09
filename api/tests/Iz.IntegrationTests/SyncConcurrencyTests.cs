using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using Iz.Domain.Memories;
using Iz.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Iz.IntegrationTests;

/// <summary>
/// Aynı hesabın iki cihazı AYNI ANDA push ederse ne olur?
/// </summary>
/// <remarks>
/// SÜRÜM KONTROLÜ TEK BAŞINA YETMİYOR. Push "oku → karşılaştır → yaz"
/// yapıyor ve kilit olmadan bu üçlü atomik değil:
///
///   A: sürüm 1'i okur      B: sürüm 1'i okur
///   A: baseVersion=1 ✓     B: baseVersion=1 ✓
///   A: sürüm 2 yazar       B: sürüm 2 yazar   ← A'nınkini EZER
///
/// İkisi de <c>applied</c> alırdı ve kaybeden cihaz değişikliğinin sunucuda
/// olduğunu sanırdı. Bu dosya, <c>ISyncLock</c>'un o pencereyi kapattığını
/// sınıyor.
///
/// TEST GERÇEKTEN EŞZAMANLI: iki istek aynı anda başlatılıyor ve ikisi de
/// beklenmeden gönderiliyor. Kilit çalışmazsa ikisi de "applied" döner ve
/// test kırmızıya gider.
/// </remarks>
[Collection(IzApiCollection.Name)]
public sealed class SyncConcurrencyTests(IzApiFactory factory)
{
    /// <summary>
    /// AYNI kullanıcı için iki ayrı istemci.
    /// </summary>
    /// <remarks>
    /// <c>CreateAuthenticatedClient</c> her çağrıda YENİ bir kimlik üretiyor;
    /// burada iki cihazın aynı hesaba ait olması gerekiyor, o yüzden token
    /// aynı <c>uid</c> ile iki kez üretiliyor.
    /// </remarks>
    private (HttpClient Birinci, HttpClient Ikinci) AyniHesap()
    {
        var uid = TestTokens.NewUid();
        return (
            factory.CreateClientWithToken(TestTokens.Create(uid)),
            factory.CreateClientWithToken(TestTokens.Create(uid)));
    }

    private static async Task<Guid> CihazAsync(HttpClient client)
    {
        var device = await (await client.PostAsJsonAsync(
                "/v1/devices", new { platform = "ios", schemaVersion = 8 }))
            .Content.ReadFromJsonAsync<JsonObject>();

        return Guid.Parse(device!["id"]!.GetValue<string>());
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

    private static Task<HttpResponseMessage> PushAsync(
        HttpClient client,
        Guid deviceId,
        Guid aniId,
        int baseVersion,
        string baslik) =>
        client.PostAsJsonAsync("/v1/sync/push", new
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
        });

    private static async Task<(string Status, int? Version)> SonucAsync(HttpResponseMessage response)
    {
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var govde = await response.Content.ReadFromJsonAsync<JsonObject>();
        var sonuc = govde!["results"]!.AsArray()[0]!;

        return (sonuc["status"]!.GetValue<string>(), (int?)sonuc["version"]?.GetValue<int>());
    }

    [Fact]
    public async Task Ayni_kaydi_ayni_anda_yazan_iki_cihazdan_BIRI_cakisma_aliyor()
    {
        var (birinci, ikinci) = AyniHesap();
        var cihazA = await CihazAsync(birinci);
        var cihazB = await CihazAsync(ikinci);
        var aniId = Guid.CreateVersion7();

        // Kayit acilir: surum 1.
        Assert.Equal("applied", (await SonucAsync(
            await PushAsync(birinci, cihazA, aniId, 0, "Ilk"))).Status);

        // IKI CIHAZ, AYNI ANDA, AYNI baseVersion.
        var a = PushAsync(birinci, cihazA, aniId, 1, "A cihazindan");
        var b = PushAsync(ikinci, cihazB, aniId, 1, "B cihazindan");

        var sonuclar = await Task.WhenAll(a, b);
        var durumlar = new[]
        {
            await SonucAsync(sonuclar[0]),
            await SonucAsync(sonuclar[1]),
        };

        // BIRI yazar, OTEKI cakisma alir. Kilit olmasaydi ikisi de "applied"
        // doner ve kaybeden cihaz degisikliginin sunucuda oldugunu sanirdi.
        Assert.Single(durumlar, d => d.Status == "applied");
        Assert.Single(durumlar, d => d.Status == "conflict");

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var ani = await db.Set<Memory>().IgnoreQueryFilters()
            .SingleAsync(m => m.Id == aniId);

        // SURUM TAM BIR ARTTI. Iki yazma gecseydi surum yine 2 olurdu ama
        // iceriklerden biri sessizce kaybolurdu; asagidaki iki iddia birlikte
        // "yalnizca bir yazma oldu" diyor.
        Assert.Equal(2, ani.Version);
        Assert.Contains(ani.Title, new[] { "A cihazindan", "B cihazindan" });

        Assert.Equal(2, await db.ChangeLog.CountAsync(e => e.EntityId == aniId.ToString()));
    }

    [Fact]
    public async Task Farkli_kayitlara_ayni_anda_yazmak_ikisini_de_gecirir()
    {
        // Kilit KULLANICI basina; ayni kullanicinin ILGISIZ iki yazmasi da
        // siraya giriyor ama ikisi de basariyla gecmeli. Kilidin dogruyu
        // engellemedigini gosteren test.
        var (birinci, ikinci) = AyniHesap();
        var cihazA = await CihazAsync(birinci);
        var cihazB = await CihazAsync(ikinci);

        var a = PushAsync(birinci, cihazA, Guid.CreateVersion7(), 0, "A'nin anisi");
        var b = PushAsync(ikinci, cihazB, Guid.CreateVersion7(), 0, "B'nin anisi");

        var sonuclar = await Task.WhenAll(a, b);

        Assert.Equal("applied", (await SonucAsync(sonuclar[0])).Status);
        Assert.Equal("applied", (await SonucAsync(sonuclar[1])).Status);
    }

    [Fact]
    public async Task Farkli_kullanicilar_birbirini_BEKLEMIYOR()
    {
        // Kilit kullanici basina: iki ayri hesabin push'u paralel akmali.
        // Global bir kilit koysaydik sunucu tek kullanicilik olurdu.
        var (birinciClient, _) = factory.CreateAuthenticatedClient();
        var (ikinciClient, _) = factory.CreateAuthenticatedClient();

        var cihazA = await CihazAsync(birinciClient);
        var cihazB = await CihazAsync(ikinciClient);

        var sonuclar = await Task.WhenAll(
            PushAsync(birinciClient, cihazA, Guid.CreateVersion7(), 0, "Birinci hesap"),
            PushAsync(ikinciClient, cihazB, Guid.CreateVersion7(), 0, "Ikinci hesap"));

        Assert.Equal("applied", (await SonucAsync(sonuclar[0])).Status);
        Assert.Equal("applied", (await SonucAsync(sonuclar[1])).Status);
    }

    [Fact]
    public async Task Reddedilen_batch_YARIM_veri_birakmiyor()
    {
        // Kilit ayni zamanda bu istegin transaction'i. Islemenin ortasinda
        // bir istisna cikarsa commit edilmeden kapaniyor ve yazilan her sey
        // geri sariliyor: yarim uygulanmis bir batch, hic uygulanmamis
        // batch'ten cok daha kotudur.
        //
        // Tetikleyici: ayni istekte, sunucuda BASKA bir kullaniciya ait bir
        // kimlikle kayit acmaya calismak benzersizlik kisitini patlatiyor.
        var (kurban, _) = factory.CreateAuthenticatedClient();
        var kurbaninCihazi = await CihazAsync(kurban);
        var carpisanId = Guid.CreateVersion7();

        Assert.Equal("applied", (await SonucAsync(
            await PushAsync(kurban, kurbaninCihazi, carpisanId, 0, "Kurbanin"))).Status);

        var (saldirgan, _) = factory.CreateAuthenticatedClient();
        var saldirganinCihazi = await CihazAsync(saldirgan);
        var masumId = Guid.CreateVersion7();

        var response = await saldirgan.PostAsJsonAsync("/v1/sync/push", new
        {
            deviceId = saldirganinCihazi,
            changes = new[]
            {
                new
                {
                    entityType = "memory",
                    entityId = masumId.ToString(),
                    op = "upsert",
                    baseVersion = 0,
                    payload = Govde(masumId, "Once bu yazilir"),
                },
                new
                {
                    entityType = "memory",
                    entityId = carpisanId.ToString(),
                    op = "upsert",
                    baseVersion = 0,
                    payload = Govde(carpisanId, "Sonra bu patlar"),
                },
            },
        });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        // ILK degisiklik de GERI ALINDI: batch ya hep ya hic.
        Assert.False(
            await db.Set<Memory>().IgnoreQueryFilters().AnyAsync(m => m.Id == masumId),
            "Batch reddedildi ama ilk degisiklik veritabaninda kaldi.");
    }
}
