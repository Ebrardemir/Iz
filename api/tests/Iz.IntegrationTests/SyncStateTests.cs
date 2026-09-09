using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;

namespace Iz.IntegrationTests;

/// <summary>
/// <c>GET /v1/sync/state</c> — Yedekleme Sağlığı ekranının (FR-164,
/// TR-M11-13) sunucu tarafındaki payı.
/// </summary>
/// <remarks>
/// Bu ucun işi "sunucuda benim için ne var?" sorusunu VERİ İNDİRMEDEN
/// cevaplamak. Yanlış cevap vermesi sessizdir: kullanıcı "her şey yedeklendi"
/// görür ve inanır.
/// </remarks>
[Collection(IzApiCollection.Name)]
public sealed class SyncStateTests(IzApiFactory factory)
{
    private async Task<(HttpClient Client, Guid DeviceId)> HesapAsync()
    {
        var (client, _) = factory.CreateAuthenticatedClient();

        var device = await (await client.PostAsJsonAsync(
                "/v1/devices", new { platform = "ios", schemaVersion = 8 }))
            .Content.ReadFromJsonAsync<JsonObject>();

        return (client, Guid.Parse(device!["id"]!.GetValue<string>()));
    }

    private static async Task PushAsync(HttpClient client, Guid deviceId, Guid aniId, string baslik)
    {
        var response = await client.PostAsJsonAsync("/v1/sync/push", new
        {
            deviceId,
            changes = new[]
            {
                new
                {
                    entityType = "memory",
                    entityId = aniId.ToString(),
                    op = "upsert",
                    baseVersion = 0,
                    payload = new
                    {
                        v = 1,
                        entity = new
                        {
                            id = aniId.ToString(),
                            title = baslik,
                            occurred_at = "2026-03-12T10:00:00.000Z",
                            occurred_year = 2026,
                            occurred_month = 3,
                            occurred_day = 12,
                            created_at = "2026-03-12T10:00:00.000Z",
                            version = 1,
                        },
                    },
                },
            },
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    private static async Task<Durum> DurumAsync(HttpClient client, long? cursor = null)
    {
        var yol = "/v1/sync/state" + (cursor is null ? "" : $"?cursor={cursor}");
        var response = await client.GetAsync(yol);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var durum = await response.Content.ReadFromJsonAsync<Durum>();
        Assert.NotNull(durum);
        return durum;
    }

    [Fact]
    public async Task Yeni_hesapta_her_sey_SIFIR()
    {
        // Yeni cihaz kurulumunda (TR-M11-14) "geri yuklenecek bir sey var mi?"
        // sorusunun cevabi burasi. Bos hesap icin dogru cevap sifir, hata
        // degil.
        var (client, _) = await HesapAsync();

        var durum = await DurumAsync(client);

        Assert.Equal(0, durum.ServerCursor);
        Assert.Equal(0, durum.PendingCount);
        Assert.Null(durum.LastChangeAt);
    }

    [Fact]
    public async Task Push_sonrasi_cursor_ve_son_degisiklik_dolu()
    {
        var (client, cihaz) = await HesapAsync();

        var oncesi = DateTimeOffset.UtcNow.AddSeconds(-5);
        await PushAsync(client, cihaz, Guid.CreateVersion7(), "Ilk");

        var durum = await DurumAsync(client);

        Assert.True(durum.ServerCursor > 0);
        Assert.NotNull(durum.LastChangeAt);
        Assert.True(durum.LastChangeAt > oncesi);
    }

    [Fact]
    public async Task Bekleyen_sayisi_CURSORDAN_SONRASINI_sayiyor()
    {
        var (client, cihaz) = await HesapAsync();

        await PushAsync(client, cihaz, Guid.CreateVersion7(), "Birinci");
        var ilk = await DurumAsync(client);

        await PushAsync(client, cihaz, Guid.CreateVersion7(), "Ikinci");
        await PushAsync(client, cihaz, Guid.CreateVersion7(), "Ucuncu");

        // Istemci ilk noktada kalmis: iki degisiklik indirmesi gerekiyor.
        var sonrasi = await DurumAsync(client, ilk.ServerCursor);

        Assert.Equal(2, sonrasi.PendingCount);
        Assert.True(sonrasi.ServerCursor > ilk.ServerCursor);

        // Guncel cursor ile: bekleyen YOK.
        Assert.Equal(0, (await DurumAsync(client, sonrasi.ServerCursor)).PendingCount);
    }

    [Fact]
    public async Task Cursor_verilmezse_TUM_gunluk_bekliyor_sayiliyor()
    {
        // Bootstrap'in habercisi: cursor=0 ile "her sey bekliyor".
        var (client, cihaz) = await HesapAsync();

        await PushAsync(client, cihaz, Guid.CreateVersion7(), "Tek kayit");

        var durum = await DurumAsync(client);

        Assert.True(durum.PendingCount >= 1);
        Assert.Equal(durum.ServerCursor, (await DurumAsync(client, 0)).ServerCursor);
    }

    [Fact]
    public async Task Negatif_cursor_istegi_KESMIYOR()
    {
        var (client, cihaz) = await HesapAsync();
        await PushAsync(client, cihaz, Guid.CreateVersion7(), "Kayit");

        var durum = await DurumAsync(client, -5);

        Assert.True(durum.PendingCount >= 1);
    }

    [Fact]
    public async Task Baskasinin_durumu_SIZMIYOR()
    {
        // change_log'un global sorgu suzgeci yok; kapsami her sorgu kendisi
        // yaziyor. Bu uc de o sorumlulugun altinda.
        var (kurban, kurbaninCihazi) = await HesapAsync();
        await PushAsync(kurban, kurbaninCihazi, Guid.CreateVersion7(), "Kurbanin");
        await PushAsync(kurban, kurbaninCihazi, Guid.CreateVersion7(), "Kurbanin ikincisi");

        var (saldirgan, _) = await HesapAsync();
        var durum = await DurumAsync(saldirgan);

        Assert.Equal(0, durum.ServerCursor);
        Assert.Equal(0, durum.PendingCount);
        Assert.Null(durum.LastChangeAt);
    }

    [Fact]
    public async Task Durum_sorgusunun_YAN_ETKISI_YOK()
    {
        // Durum sorgusunun durumu degistirmesi, ekrani acmanin
        // senkronizasyonu etkilemesi demek olurdu.
        var (client, cihaz) = await HesapAsync();
        await PushAsync(client, cihaz, Guid.CreateVersion7(), "Kayit");

        var once = await DurumAsync(client);
        await DurumAsync(client);
        await DurumAsync(client, 0);
        var sonra = await DurumAsync(client);

        Assert.Equal(once.ServerCursor, sonra.ServerCursor);
        Assert.Equal(once.PendingCount, sonra.PendingCount);
        Assert.Equal(once.LastChangeAt, sonra.LastChangeAt);
    }

    [Fact]
    public async Task Kimliksiz_istek_401_donuyor()
    {
        var response = await factory.CreateClient().GetAsync("/v1/sync/state");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private sealed record Durum(long ServerCursor, int PendingCount, DateTimeOffset? LastChangeAt);
}
