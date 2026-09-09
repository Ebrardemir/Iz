using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;

namespace Iz.IntegrationTests;

/// <summary>
/// <c>GET /v1/sync/pull</c> — yol haritası §4.2 ve §4.3.
/// </summary>
/// <remarks>
/// PULL'UN YANLIŞ DAVRANMASI SESSİZDİR. Atlanan bir sayfa, ikinci cihazda
/// hiç belirmeyen bir anıdır; diriltilen bir kayıt, kullanıcının sildiği
/// şeyin geri gelmesidir. İkisi de hata mesajı üretmez.
///
/// Testler push üzerinden veri kuruyor — sahte satır eklemiyor. Böylece iki
/// ucun AYNI sözleşmeyi konuştuğu da her koşuşta doğrulanıyor.
/// </remarks>
[Collection(IzApiCollection.Name)]
public sealed class SyncPullTests(IzApiFactory factory)
{
    // --- Yardımcılar -------------------------------------------------------

    private async Task<(HttpClient Client, Guid DeviceId)> HesapAsync()
    {
        var (client, _) = factory.CreateAuthenticatedClient();
        return (client, await CihazAsync(client));
    }

    /// <summary>Aynı hesaba İKİNCİ bir cihaz kaydeder.</summary>
    private static async Task<Guid> CihazAsync(HttpClient client)
    {
        var device = await (await client.PostAsJsonAsync(
                "/v1/devices", new { platform = "ios", schemaVersion = 8 }))
            .Content.ReadFromJsonAsync<JsonObject>();

        return Guid.Parse(device!["id"]!.GetValue<string>());
    }

    private static object AniGovdesi(Guid id, string? baslik, object[]? baglar = null) => new
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
            is_favorite = false,
            is_archived = false,
            created_at = "2026-03-12T10:00:00.000Z",
            version = 1,
            owner_id = "local",
        },
        links = new { memory_people = baglar ?? [] },
    };

    private static object KisiBagi(Guid aniId, Guid kisiId, bool silindi) => new
    {
        memory_id = aniId.ToString(),
        person_id = kisiId.ToString(),
        role = "kardesim",
        created_at = "2026-03-12T10:00:00.000Z",
        deleted_at = silindi ? "2026-03-13T08:00:00.000Z" : null,
        version = 1,
    };

    private static async Task PushAsync(
        HttpClient client,
        Guid deviceId,
        Guid aniId,
        string op,
        int baseVersion,
        object? payload)
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
                    op,
                    baseVersion,
                    payload,
                },
            },
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    private static async Task<PullYaniti> PullAsync(HttpClient client, long cursor, int? limit = null)
    {
        var yol = $"/v1/sync/pull?cursor={cursor}" + (limit is null ? "" : $"&limit={limit}");
        var response = await client.GetAsync(yol);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var yanit = await response.Content.ReadFromJsonAsync<PullYaniti>();
        Assert.NotNull(yanit);
        return yanit;
    }

    // --- Temel yol ---------------------------------------------------------

    [Fact]
    public async Task Push_edilen_kayit_pullda_GOVDESIYLE_geliyor()
    {
        var (client, cihaz) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        await PushAsync(client, cihaz, aniId, "upsert", 0, AniGovdesi(aniId, "Kahve molasi"));

        var yanit = await PullAsync(client, cursor: 0);
        var degisiklik = Assert.Single(yanit.Changes, c => c.EntityId == aniId.ToString());

        Assert.Equal("memory", degisiklik.EntityType);
        Assert.Equal("upsert", degisiklik.Op);
        Assert.Equal(1, degisiklik.Version);
        Assert.NotNull(degisiklik.Payload);

        // ALAN ADLARI SQL SUTUN ADI — istemcinin Drift satiriyla ayni dil.
        // camelCase donseydik istemci her alani cevirmek zorunda kalir ve o
        // ceviri bir gun bir alani sessizce dusururdu.
        Assert.Equal("Kahve molasi", degisiklik.Payload["title"]!.GetValue<string>());
        Assert.Equal(2026, degisiklik.Payload["occurred_year"]!.GetValue<int>());
        Assert.False(degisiklik.Payload.ContainsKey("occurredYear"));

        Assert.Equal(degisiklik.Seq, yanit.NextCursor);
        Assert.False(yanit.HasMore);
    }

    [Fact]
    public async Task Kaydi_GONDEREN_cihaz_isaretleniyor_echo_onleme()
    {
        // Sunucu SUZMUYOR, ISARETLIYOR (§4.2). Suzseydik "hangi cihaz
        // soruyor" bilgisine ihtiyacimiz olurdu ve o bilgi istemcinin
        // SOYLEDIGI bir sey; yanlis kimlik gonderen bir istemcide sessizce
        // veri atlanirdi.
        var (client, birinciCihaz) = await HesapAsync();
        var ikinciCihaz = await CihazAsync(client);
        var aniId = Guid.CreateVersion7();

        await PushAsync(client, birinciCihaz, aniId, "upsert", 0, AniGovdesi(aniId, "A cihazindan"));

        var yanit = await PullAsync(client, cursor: 0);
        var degisiklik = Assert.Single(yanit.Changes, c => c.EntityId == aniId.ToString());

        Assert.Equal(birinciCihaz, degisiklik.DeviceId);
        Assert.NotEqual(ikinciCihaz, degisiklik.DeviceId);
    }

    [Fact]
    public async Task Iki_cihaz_ayni_hesap_Ada_yazilan_Bde_gorunuyor()
    {
        // Yol haritasi §6, Faz 3 kabul senaryosu 1. Sunucu tarafinin sozu bu.
        var (client, cihazA) = await HesapAsync();
        var cihazB = await CihazAsync(client);
        var aniId = Guid.CreateVersion7();

        await PushAsync(client, cihazA, aniId, "upsert", 0, AniGovdesi(aniId, "A'da olusturuldu"));

        // B hicbir sey bilmiyor: bootstrap.
        var yanit = await PullAsync(client, cursor: 0);
        var degisiklik = Assert.Single(yanit.Changes, c => c.EntityId == aniId.ToString());

        Assert.Equal("A'da olusturuldu", degisiklik.Payload!["title"]!.GetValue<string>());
        Assert.NotEqual(cihazB, degisiklik.DeviceId);
    }

    // --- Sayfalama ---------------------------------------------------------

    [Fact]
    public async Task Cursor_ilerliyor_ve_ayni_sayfa_iki_kez_gelmiyor()
    {
        var (client, cihaz) = await HesapAsync();
        var birinci = Guid.CreateVersion7();
        var ikinci = Guid.CreateVersion7();

        await PushAsync(client, cihaz, birinci, "upsert", 0, AniGovdesi(birinci, "Birinci"));
        await PushAsync(client, cihaz, ikinci, "upsert", 0, AniGovdesi(ikinci, "Ikinci"));

        var sayfa1 = await PullAsync(client, cursor: 0, limit: 1);
        Assert.Single(sayfa1.Changes);
        Assert.True(sayfa1.HasMore);

        var sayfa2 = await PullAsync(client, sayfa1.NextCursor, limit: 1);
        Assert.Single(sayfa2.Changes);
        Assert.NotEqual(sayfa1.Changes[0].EntityId, sayfa2.Changes[0].EntityId);
        Assert.True(sayfa2.NextCursor > sayfa1.NextCursor);

        // Son sayfadan sonrasi BOS ve cursor yerinde kaliyor.
        var sayfa3 = await PullAsync(client, sayfa2.NextCursor);
        Assert.Empty(sayfa3.Changes);
        Assert.False(sayfa3.HasMore);
        Assert.Equal(sayfa2.NextCursor, sayfa3.NextCursor);
    }

    [Fact]
    public async Task Ayni_kayit_sayfada_TEK_SATIR_en_yuksek_seq_ile()
    {
        // Bir ani bes kez duzenlenmisse gunlukte bes satir var ama govde
        // besinde de ayni olurdu. Birlestirmeseydik istemci ayni kaydi bes
        // kez yazar, trafik bes katina cikardi.
        var (client, cihaz) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        await PushAsync(client, cihaz, aniId, "upsert", 0, AniGovdesi(aniId, "Birinci hali"));
        await PushAsync(client, cihaz, aniId, "upsert", 1, AniGovdesi(aniId, "Ikinci hali"));
        await PushAsync(client, cihaz, aniId, "upsert", 2, AniGovdesi(aniId, "Ucuncu hali"));

        var yanit = await PullAsync(client, cursor: 0);
        var degisiklik = Assert.Single(yanit.Changes, c => c.EntityId == aniId.ToString());

        // SON hali geliyor, ara surumler degil.
        Assert.Equal("Ucuncu hali", degisiklik.Payload!["title"]!.GetValue<string>());
        Assert.Equal(3, degisiklik.Version);

        // Cursor BIRLESTIRMEDEN ONCEKI son satirdan: istemci tukettigi her
        // gunluk satirinin otesine gecmeli, yoksa her pull ayni yerde doner.
        Assert.True(yanit.NextCursor >= degisiklik.Seq);
        Assert.Empty((await PullAsync(client, yanit.NextCursor)).Changes);
    }

    // --- Silme -------------------------------------------------------------

    [Fact]
    public async Task Silinen_kayit_DELETE_olarak_ve_GOVDESIZ_geliyor()
    {
        var (client, cihaz) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        await PushAsync(client, cihaz, aniId, "upsert", 0, AniGovdesi(aniId, "Silinecek"));
        await PushAsync(client, cihaz, aniId, "delete", 1, null);

        var yanit = await PullAsync(client, cursor: 0);
        var degisiklik = Assert.Single(yanit.Changes, c => c.EntityId == aniId.ToString());

        Assert.Equal("delete", degisiklik.Op);
        Assert.Equal(2, degisiklik.Version);

        // Govde YOK: gerekmiyor, ve gondermek kullanicinin sildigi veriyi
        // kabloya geri koymak olurdu.
        Assert.Null(degisiklik.Payload);
    }

    [Fact]
    public async Task Sayfa_disinda_silinen_kayit_UPSERT_olarak_gelmiyor()
    {
        // BU TESTIN YAKALADIGI HATA EN SINSISI.
        //
        // Gunlukte "upsert" yazan bir kayit, sayfanin DISINDA kalan daha yeni
        // bir seq'te silinmis olabilir. Govdeyi tablodan okudugumuz icin
        // elimizdeki satir zaten silinmis olan satir. Gunluge uysaydik onu
        // "guncellendi" diye gonderir, istemci kaydi DIRILTIRDI — silme ancak
        // bir sonraki sayfada gelirdi ve kayit o arada ekranda gorunurdu.
        //
        // Bu yuzden `op` gunlukten degil SATIRDAN turetiliyor.
        var (client, cihaz) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        await PushAsync(client, cihaz, aniId, "upsert", 0, AniGovdesi(aniId, "Once vardi"));
        await PushAsync(client, cihaz, aniId, "delete", 1, null);

        // limit=1: ilk sayfa YALNIZ upsert satirini kapsiyor.
        var sayfa1 = await PullAsync(client, cursor: 0, limit: 1);
        var degisiklik = Assert.Single(sayfa1.Changes);

        Assert.Equal(aniId.ToString(), degisiklik.EntityId);
        Assert.Equal("delete", degisiklik.Op);
        Assert.Null(degisiklik.Payload);
    }

    // --- Bağlar ------------------------------------------------------------

    [Fact]
    public async Task Baglar_da_pullda_geliyor_kimlikleri_BILESIK()
    {
        var (client, cihaz) = await HesapAsync();
        var aniId = Guid.CreateVersion7();
        var kisiId = Guid.CreateVersion7();

        await PushAsync(client, cihaz, aniId, "upsert", 0,
            AniGovdesi(aniId, "Bagli ani", [KisiBagi(aniId, kisiId, silindi: false)]));

        var yanit = await PullAsync(client, cursor: 0);
        var bag = Assert.Single(yanit.Changes, c => c.EntityType == "memory_people");

        Assert.Equal($"{aniId}:{kisiId}", bag.EntityId);
        Assert.Equal("upsert", bag.Op);
        Assert.Equal("kardesim", bag.Payload!["role"]!.GetValue<string>());
    }

    [Fact]
    public async Task Koparilan_bag_DELETE_olarak_iniyor()
    {
        // §1.1'in oteki yarisi: silme yalnizca sunucuda kalmamali, ikinci
        // cihaza da bir SATIR olarak gitmeli. Gitmezse orada bag yasamaya
        // devam eder.
        var (client, cihaz) = await HesapAsync();
        var aniId = Guid.CreateVersion7();
        var kisiId = Guid.CreateVersion7();

        await PushAsync(client, cihaz, aniId, "upsert", 0,
            AniGovdesi(aniId, "Bagli ani", [KisiBagi(aniId, kisiId, silindi: false)]));
        await PushAsync(client, cihaz, aniId, "upsert", 1,
            AniGovdesi(aniId, "Kisi cikarildi", [KisiBagi(aniId, kisiId, silindi: true)]));

        var yanit = await PullAsync(client, cursor: 0);
        var bag = Assert.Single(yanit.Changes, c => c.EntityType == "memory_people");

        Assert.Equal("delete", bag.Op);
        Assert.Null(bag.Payload);
    }

    // --- Sahiplik ----------------------------------------------------------

    [Fact]
    public async Task Baskasinin_degisiklikleri_HIC_gelmiyor()
    {
        // change_log'un global sorgu suzgeci YOK; kapsami her sorgu kendisi
        // yaziyor. Bu test o tek satirlik sorumlulugu koruyor.
        var (kurban, kurbaninCihazi) = await HesapAsync();
        var kurbaninAnisi = Guid.CreateVersion7();

        await PushAsync(kurban, kurbaninCihazi, kurbaninAnisi, "upsert", 0,
            AniGovdesi(kurbaninAnisi, "Kurbanin gizli anisi"));

        var (saldirgan, _) = await HesapAsync();
        var yanit = await PullAsync(saldirgan, cursor: 0);

        Assert.DoesNotContain(yanit.Changes, c => c.EntityId == kurbaninAnisi.ToString());
        Assert.Empty(yanit.Changes);
    }

    // --- Sınırlar ----------------------------------------------------------

    [Fact]
    public async Task Negatif_cursor_BOOTSTRAPa_dusuyor_istegi_kesmiyor()
    {
        // Reddetmek istemciyi esitlemeden tamamen keserdi. Sifirlamak yalniz
        // bir bootstrap pahasina dogru sonucu veriyor; pull idempotent oldugu
        // icin tekrar inen veri zarar vermez.
        var (client, cihaz) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        await PushAsync(client, cihaz, aniId, "upsert", 0, AniGovdesi(aniId, "Bootstrap"));

        var yanit = await PullAsync(client, cursor: -99);
        Assert.Single(yanit.Changes, c => c.EntityId == aniId.ToString());
    }

    [Fact]
    public async Task Anlamsiz_limit_makul_bir_degere_cekiliyor()
    {
        var (client, cihaz) = await HesapAsync();
        await PushAsync(client, cihaz, Guid.CreateVersion7(), "upsert", 0,
            AniGovdesi(Guid.CreateVersion7(), "x"));

        // 0 ve devasa deger: ikisi de istisna atmadan calisiyor.
        Assert.True((await PullAsync(client, 0, limit: 0)).Changes.Count >= 1);
        Assert.True((await PullAsync(client, 0, limit: 100_000)).Changes.Count >= 1);
    }

    [Fact]
    public async Task Kimliksiz_pull_401_donuyor()
    {
        var response = await factory.CreateClient().GetAsync("/v1/sync/pull?cursor=0");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    // --- Yanit modeli ------------------------------------------------------

    private sealed record PullYaniti(List<PullDegisikligi> Changes, long NextCursor, bool HasMore);

    private sealed record PullDegisikligi(
        long Seq,
        string EntityType,
        string EntityId,
        string Op,
        int Version,
        Guid? DeviceId,
        JsonObject? Payload);
}
