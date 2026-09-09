using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;
using Iz.Domain.Sync;
using Iz.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Iz.IntegrationTests;

/// <summary>
/// <c>POST /v1/sync/push</c> — yol haritası §4.1.
/// </summary>
/// <remarks>
/// BURADAKİ TESTLERİN ÇOĞU YAYIN DURDURUCU. Push'un yanlış davranması
/// kullanıcının verisini SESSİZCE bozar: ezilen bir not, geri gelen bir
/// kişi, ikinci cihaza hiç gitmeyen bir anı. Hiçbiri hata mesajı üretmez.
///
/// GERÇEK PostgreSQL üzerinde koşuyor: <c>bigserial</c> sırası, bileşik
/// anahtarlar ve global sorgu süzgeci bellek içi sağlayıcıda yok.
/// </remarks>
[Collection(IzApiCollection.Name)]
public sealed class SyncPushTests(IzApiFactory factory)
{
    // --- Yardımcılar -------------------------------------------------------

    /// <summary>Kimlikli istemci + kayıtlı bir cihaz.</summary>
    /// <remarks>
    /// Cihaz kaydı ZORUNLU: push kayıtlı olmayan bir cihaz kimliğini
    /// reddediyor (echo kuralının kötüye kullanılmasına karşı).
    /// </remarks>
    private async Task<(HttpClient Client, Guid DeviceId)> HesapAsync()
    {
        var (client, _) = factory.CreateAuthenticatedClient();

        var device = await (await client.PostAsJsonAsync(
                "/v1/devices", new { platform = "ios", schemaVersion = 8 }))
            .Content.ReadFromJsonAsync<JsonObject>();

        return (client, Guid.Parse(device!["id"]!.GetValue<string>()));
    }

    private static object AniGovdesi(
        Guid id,
        string? baslik = "Kahve Molasi",
        string? not = null,
        object[]? kisiBaglari = null) => new
        {
            v = 1,
            entity = new
            {
                id = id.ToString(),
                title = baslik,
                note = not,
                occurred_at = "2026-03-12T10:00:00.000Z",
                occurred_year = 2026,
                occurred_month = 3,
                occurred_day = 12,
                is_favorite = false,
                is_archived = false,
                created_at = "2026-03-12T10:00:00.000Z",
                updated_at = "2026-03-12T10:00:00.000Z",
                version = 1,
                owner_id = "local",
            },
            links = new { memory_people = kisiBaglari ?? [] },
        };

    private static object KisiBagi(Guid aniId, Guid kisiId, string? rol, bool silindi) => new
    {
        memory_id = aniId.ToString(),
        person_id = kisiId.ToString(),
        role = rol,
        created_at = "2026-03-12T10:00:00.000Z",
        updated_at = "2026-03-12T10:00:00.000Z",
        deleted_at = silindi ? "2026-03-13T08:00:00.000Z" : null,
        version = 1,
    };

    private static async Task<PushYaniti> PushAsync(
        HttpClient client,
        Guid deviceId,
        params object[] changes)
    {
        var response = await client.PostAsJsonAsync(
            "/v1/sync/push", new { deviceId, changes });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var yanit = await response.Content.ReadFromJsonAsync<PushYaniti>();
        Assert.NotNull(yanit);
        return yanit;
    }

    private static object Degisiklik(
        string entityType,
        Guid entityId,
        string op,
        int baseVersion,
        object? payload) => new
        {
            entityType,
            entityId = entityId.ToString(),
            op,
            baseVersion,
            payload,
        };

    /// <summary>
    /// Sunucudaki satırı OKUR — sahiplik süzgecini atlayarak.
    /// </summary>
    /// <remarks>
    /// Süzgeç isteğin kullanıcısına bakıyor; testin kendi kapsamında
    /// kullanıcı yok, dolayısıyla süzgeç hiçbir satır geçirmezdi. Testin
    /// sorusu sahiplik hakkında değil, YAZILAN VERİ hakkında.
    /// </remarks>
    private static async Task<T?> SatirAsync<T>(
        IzDbContext db,
        Func<IQueryable<T>, IQueryable<T>> filtre)
        where T : class =>
        await filtre(db.Set<T>().IgnoreQueryFilters()).SingleOrDefaultAsync();

    // --- Temel yol ---------------------------------------------------------

    [Fact]
    public async Task Yeni_ani_yaziliyor_ve_gunluge_dusuyor()
    {
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        var yanit = await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "upsert", 0, AniGovdesi(aniId)));

        var sonuc = Assert.Single(yanit.Results);
        Assert.Equal("applied", sonuc.Status);
        Assert.Equal(1, sonuc.Version);

        // Sira VERITABANI uretiyor; dolu olmasi gunluge gercekten
        // dusuruldugunun kanidi.
        Assert.NotNull(sonuc.Seq);
        Assert.Equal(sonuc.Seq, yanit.Cursor);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var ani = await SatirAsync<Domain.Memories.Memory>(db, q => q.Where(m => m.Id == aniId));
        Assert.NotNull(ani);
        Assert.Equal("Kahve Molasi", ani.Title);
        Assert.Equal(2026, ani.OccurredYear);
        Assert.Equal(3, ani.OccurredMonth);
        Assert.Equal(12, ani.OccurredDay);
        Assert.Null(ani.DeletedAt);

        var gunluk = await db.ChangeLog
            .Where(e => e.EntityId == aniId.ToString())
            .SingleAsync();

        Assert.Equal(SyncEntityTypes.Memory, gunluk.EntityType);
        Assert.Equal(ChangeOperation.Upsert, gunluk.Operation);

        // ECHO ONLEME: gunluk satiri gonderen cihazi tasiyor, yoksa istemci
        // kendi degisikligini pull'da geri alir.
        Assert.Equal(deviceId, gunluk.DeviceId);
    }

    [Fact]
    public async Task Ayni_govde_ikinci_kez_gelince_gunluge_YENI_SATIR_dusmuyor()
    {
        // IDEMPOTENCY-KEY henuz yok; kimlikleri istemci urettigi icin ayni
        // govde DUPLICATE uretmiyor. Bu test o guvenceyi koruyor: degismeyen
        // bir kayit yeniden yazilmiyor, ikinci cihaz bosuna satir cekmiyor.
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        await PushAsync(client, deviceId, Degisiklik("memory", aniId, "upsert", 0, AniGovdesi(aniId)));

        // Ikinci gonderim: sunucu artik 1. surumde, istemci de 1 diyor.
        var ikinci = await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "upsert", 1, AniGovdesi(aniId)));

        var sonuc = Assert.Single(ikinci.Results);
        Assert.Equal("applied", sonuc.Status);
        Assert.Equal(1, sonuc.Version);

        // Hicbir alan degismedi: surum artmadi, gunluge satir dusmedi.
        Assert.Null(sonuc.Seq);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        Assert.Equal(
            1,
            await db.ChangeLog.CountAsync(e => e.EntityId == aniId.ToString()));
    }

    [Fact]
    public async Task Surum_uyusmazliginda_CAKISMA_donuyor_ve_sunucu_EZMIYOR()
    {
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        await PushAsync(client, deviceId, Degisiklik("memory", aniId, "upsert", 0, AniGovdesi(aniId)));

        // Ilk cihaz 2. surume tasiyor.
        await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "upsert", 1, AniGovdesi(aniId, baslik: "Sunucudaki baslik")));

        // Ikinci cihaz hala 1. surumu biliyor.
        var yanit = await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "upsert", 1, AniGovdesi(aniId, baslik: "Eski cihazin basligi")));

        var sonuc = Assert.Single(yanit.Results);
        Assert.Equal("conflict", sonuc.Status);
        Assert.NotNull(sonuc.Server);
        Assert.Equal(2, sonuc.Server.Version);

        // KULLANICIYA IKI SURUM GOSTERILEBILSIN diye sunucunun govdesi de
        // donuyor (§4.4: hicbir metin sessizce silinmez).
        Assert.Equal("Sunucudaki baslik", sonuc.Server.Payload["title"]!.GetValue<string>());

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var ani = await SatirAsync<Domain.Memories.Memory>(db, q => q.Where(m => m.Id == aniId));
        Assert.NotNull(ani);

        // EZILMEDI.
        Assert.Equal("Sunucudaki baslik", ani.Title);
        Assert.Equal(2, ani.Version);
    }

    [Fact]
    public async Task Cakisan_satir_KUYRUGU_KILITLEMIYOR()
    {
        // §4.1'in tek istisnasi: batch tek transaction ama cakisan ogeler
        // "islenmedi" sayilip geri kalani uygulaniyor. Aksi halde tek bir
        // cakisma kullanicinin butun degisikliklerini durdururdu.
        var (client, deviceId) = await HesapAsync();
        var cakisan = Guid.CreateVersion7();
        var saglam = Guid.CreateVersion7();

        await PushAsync(client, deviceId, Degisiklik("memory", cakisan, "upsert", 0, AniGovdesi(cakisan)));

        var yanit = await PushAsync(
            client, deviceId,
            Degisiklik("memory", cakisan, "upsert", 7, AniGovdesi(cakisan, baslik: "Yanlis surum")),
            Degisiklik("memory", saglam, "upsert", 0, AniGovdesi(saglam, baslik: "Gecmesi gereken")));

        Assert.Equal(2, yanit.Results.Count);
        Assert.Equal("conflict", yanit.Results[0].Status);
        Assert.Equal("applied", yanit.Results[1].Status);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        Assert.NotNull(await SatirAsync<Domain.Memories.Memory>(db, q => q.Where(m => m.Id == saglam)));
    }

    // --- Silme -------------------------------------------------------------

    [Fact]
    public async Task Silme_TOMBSTONE_yaziyor_ve_gunluge_DELETE_dusuyor()
    {
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        await PushAsync(client, deviceId, Degisiklik("memory", aniId, "upsert", 0, AniGovdesi(aniId)));
        await PushAsync(client, deviceId, Degisiklik("memory", aniId, "delete", 1, null));

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var ani = await SatirAsync<Domain.Memories.Memory>(db, q => q.Where(m => m.Id == aniId));
        Assert.NotNull(ani);
        Assert.NotNull(ani.DeletedAt);
        Assert.Equal(2, ani.Version);

        var son = await db.ChangeLog
            .Where(e => e.EntityId == aniId.ToString())
            .OrderByDescending(e => e.Seq)
            .FirstAsync();

        Assert.Equal(ChangeOperation.Delete, son.Operation);
    }

    [Fact]
    public async Task Sunucuda_OLMAYAN_kaydin_silinmesi_yine_de_tombstone_aciyor()
    {
        // Hicbir sey yapmasaydik, ayni kaydi henuz push etmemis IKINCI bir
        // cihaz onu sonradan gonderir ve kullanicinin sildigi kayit
        // dirilirdi. Anonim -> hesap yukseltmesinde iki cihazin da ayni yerel
        // kayitlari tasimasi bunu gercek bir senaryo yapiyor.
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        var yanit = await PushAsync(client, deviceId, Degisiklik("memory", aniId, "delete", 0, null));

        Assert.Equal("applied", Assert.Single(yanit.Results).Status);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var ani = await SatirAsync<Domain.Memories.Memory>(db, q => q.Where(m => m.Id == aniId));
        Assert.NotNull(ani);
        Assert.NotNull(ani.DeletedAt);
    }

    [Fact]
    public async Task Zaten_silinmis_kaydin_tekrar_silinmesi_surumu_SISIRMIYOR()
    {
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        await PushAsync(client, deviceId, Degisiklik("memory", aniId, "upsert", 0, AniGovdesi(aniId)));
        await PushAsync(client, deviceId, Degisiklik("memory", aniId, "delete", 1, null));

        var tekrar = await PushAsync(client, deviceId, Degisiklik("memory", aniId, "delete", 1, null));

        var sonuc = Assert.Single(tekrar.Results);
        Assert.Equal("applied", sonuc.Status);
        Assert.Equal(2, sonuc.Version);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        // Uc degil IKI satir: ikinci silme gunluge dusmedi.
        Assert.Equal(
            2,
            await db.ChangeLog.CountAsync(e => e.EntityId == aniId.ToString()));
    }

    // --- Baglar — §1.1'in borcu -------------------------------------------

    [Fact]
    public async Task Baglar_ana_kaydin_govdesinden_yaziliyor_ve_KENDI_gunluk_satirini_aliyor()
    {
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();
        var kisiId = Guid.CreateVersion7();

        await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "upsert", 0, AniGovdesi(
                aniId, kisiBaglari: [KisiBagi(aniId, kisiId, "fotografi ceken", silindi: false)])));

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var bag = await SatirAsync<Domain.Memories.MemoryPerson>(
            db, q => q.Where(l => l.MemoryId == aniId && l.PersonId == kisiId));

        Assert.NotNull(bag);
        Assert.Equal("fotografi ceken", bag.Role);
        Assert.Null(bag.DeletedAt);

        // Bagin kendi UUID'si yok; gunlukteki kimligi CIFT.
        var bagGunlugu = await db.ChangeLog
            .Where(e => e.EntityId == $"{aniId}:{kisiId}")
            .SingleAsync();

        Assert.Equal(SyncEntityTypes.MemoryPeople, bagGunlugu.EntityType);
    }

    [Fact]
    public async Task Bagda_SILME_KAZANIYOR_canli_satir_onu_DIRILTMIYOR()
    {
        // YOL HARITASININ EN PAHALI DERSI (§1.1): kullanici anidan kisiyi
        // cikarir, bir sonraki esitlemede kisi geri gelir. Buradaki kural o
        // hatanin sunucu tarafindaki kapisi.
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();
        var kisiId = Guid.CreateVersion7();

        // 1) Bag kuruldu.
        await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "upsert", 0, AniGovdesi(
                aniId, kisiBaglari: [KisiBagi(aniId, kisiId, "kardesim", silindi: false)])));

        // 2) Kisi cikarildi — bag tombstone olarak geldi.
        await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "upsert", 1, AniGovdesi(
                aniId, baslik: "Duzenlendi",
                kisiBaglari: [KisiBagi(aniId, kisiId, "kardesim", silindi: true)])));

        // 3) ESKI bir cihaz bagi hala CANLI biliyor ve oyle gonderiyor.
        await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "upsert", 2, AniGovdesi(
                aniId, baslik: "Duzenlendi",
                kisiBaglari: [KisiBagi(aniId, kisiId, "kardesim", silindi: false)])));

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var bag = await SatirAsync<Domain.Memories.MemoryPerson>(
            db, q => q.Where(l => l.MemoryId == aniId && l.PersonId == kisiId));

        Assert.NotNull(bag);
        Assert.NotNull(bag.DeletedAt);
    }

    [Fact]
    public async Task Degismeyen_baglar_her_pushta_gunluge_dusmuyor()
    {
        // Istemci bir aniyi her kaydettiginde TUM baglarini yeniden
        // gonderiyor. Hepsine gunluk satiri dusseydik, kullanici tek bir
        // basligi duzeltir, ikinci cihaz on bes satir cekerdi.
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();
        var kisiId = Guid.CreateVersion7();
        object[] baglar = [KisiBagi(aniId, kisiId, "kankam", silindi: false)];

        await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "upsert", 0, AniGovdesi(aniId, kisiBaglari: baglar)));

        await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "upsert", 1, AniGovdesi(
                aniId, baslik: "Yeni baslik", kisiBaglari: baglar)));

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        // Ani iki kez degisti, bag bir kez yazildi.
        Assert.Equal(2, await db.ChangeLog.CountAsync(e => e.EntityId == aniId.ToString()));
        Assert.Equal(1, await db.ChangeLog.CountAsync(e => e.EntityId == $"{aniId}:{kisiId}"));
    }

    [Fact]
    public async Task Cakisan_ana_kaydin_baglari_da_YAZILMIYOR()
    {
        // "Hicbir sey yazilmadi" sozunun tamami: cakisan bir degisikligin
        // baglari da uygulanmiyor. Istemci satiri cozup yeniden gonderecek,
        // baglar onunla birlikte gelecek.
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();
        var kisiId = Guid.CreateVersion7();

        await PushAsync(client, deviceId, Degisiklik("memory", aniId, "upsert", 0, AniGovdesi(aniId)));

        await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "upsert", 99, AniGovdesi(
                aniId, kisiBaglari: [KisiBagi(aniId, kisiId, "gelmemeli", silindi: false)])));

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        Assert.Null(await SatirAsync<Domain.Memories.MemoryPerson>(
            db, q => q.Where(l => l.MemoryId == aniId && l.PersonId == kisiId)));
    }

    // --- Ayni batch icinde tekrar -----------------------------------------

    [Fact]
    public async Task Ayni_kayit_batchte_iki_kez_gelebiliyor()
    {
        // Kuyrukta once "olustur" sonra "duzenle" satiri var. Ikincisinde
        // veritabanina sorsaydik henuz kaydedilmemis olan ilkini bulamaz,
        // ayni anahtarla ikinci bir satir acmaya calisir ve BATCH'IN TAMAMI
        // duserdi.
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        var yanit = await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "create", 0, AniGovdesi(aniId, baslik: "Ilk")),
            Degisiklik("memory", aniId, "update", 1, AniGovdesi(aniId, baslik: "Ikinci")));

        Assert.All(yanit.Results, r => Assert.Equal("applied", r.Status));

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var ani = await SatirAsync<Domain.Memories.Memory>(db, q => q.Where(m => m.Id == aniId));
        Assert.NotNull(ani);
        Assert.Equal("Ikinci", ani.Title);

        // Iki degisiklik, TEK gunluk satiri: kayit bu istekte bir kez dogdu.
        Assert.Equal(1, await db.ChangeLog.CountAsync(e => e.EntityId == aniId.ToString()));
    }

    // --- Reddetme ----------------------------------------------------------

    [Theory]
    [InlineData("bilinmeyen_tur", "unknown_entity_type")]
    [InlineData("memory_people", "entity_id_invalid")]
    public async Task Tanimlanamayan_satir_REDDEDILIYOR_batch_devam_ediyor(
        string entityType,
        string beklenenSebep)
    {
        // `memory_people` bir BAG: kimligi "uuid:uuid" olmali. Tekil bir UUID
        // gelirse sunucu bagi yanlis anahtarla arar, bulamaz ve YENISINI
        // acardi — kullanicida ikinci bir bag satiri olurdu.
        var (client, deviceId) = await HesapAsync();
        var bozukId = Guid.CreateVersion7();
        var saglam = Guid.CreateVersion7();

        var yanit = await PushAsync(
            client, deviceId,
            Degisiklik(entityType, bozukId, "upsert", 0, AniGovdesi(bozukId)),
            Degisiklik("memory", saglam, "upsert", 0, AniGovdesi(saglam)));

        Assert.Equal("rejected", yanit.Results[0].Status);
        Assert.Equal(beklenenSebep, yanit.Results[0].Reason);
        Assert.Equal("applied", yanit.Results[1].Status);
    }

    [Fact]
    public async Task Okunamayan_govde_ISTEGI_degil_SATIRI_reddediyor()
    {
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        var yanit = await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "upsert", 0, new { v = 99, entity = new { id = aniId } }));

        var sonuc = Assert.Single(yanit.Results);
        Assert.Equal("rejected", sonuc.Status);
        Assert.Equal("payload_version_unsupported", sonuc.Reason);
    }

    [Fact]
    public async Task Bilinmeyen_ALAN_kaydi_reddetmiyor()
    {
        // TR-M13-22'nin sunucu karsiligi: sunucudan yeni bir istemcinin
        // gonderdigi tek bir yeni alan, o kullanicinin butun kuyrugunu
        // kilitlememeli.
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        var yanit = await PushAsync(
            client, deviceId,
            Degisiklik("memory", aniId, "upsert", 0, new
            {
                v = 1,
                entity = new
                {
                    id = aniId.ToString(),
                    title = "Yeni istemci",
                    occurred_at = "2026-03-12T10:00:00.000Z",
                    occurred_year = 2026,
                    occurred_month = 3,
                    occurred_day = 12,
                    gelecekteki_alan = "sunucu bunu tanimiyor",
                },
                links = new { gelecekteki_bag_tablosu = new[] { new { x = 1 } } },
            }));

        Assert.Equal("applied", Assert.Single(yanit.Results).Status);
    }

    [Fact]
    public async Task Gecersiz_UTF8_tasiyan_govde_500_DEGIL_rejected_donuyor()
    {
        // GERCEK BIR OLAYDAN GELIYOR: elle test betigi Windows'ta govdeyi
        // cp1254 ile gonderdi ("kardesim"deki s harfi tek bayt 0xFE oldu) ve
        // sunucu BUTUN batch'i 500 ile dusurdu.
        //
        // System.Text.Json bozuk UTF-8'i AYRISTIRIRKEN yakalamiyor; hata
        // ancak o alan okundugunda cikiyor — yani eslemenin ortasinda.
        // Istemci 500'u "sunucu bozuk" diye okur ve ayni istegi yeniden
        // dener; kuyruk orada sonsuza kadar takilirdi.
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();
        var saglam = Guid.CreateVersion7();

        // Once gecerli JSON kuruluyor, sonra tek bir bayt bozuluyor: 0xFE
        // hicbir UTF-8 dizisinin parcasi olamaz. (cp1254'te 's' harfi.)
        var govde = $$"""
            { "deviceId": "{{deviceId}}", "changes": [
              { "entityType": "memory", "entityId": "{{aniId}}", "op": "upsert", "baseVersion": 0,
                "payload": { "v": 1, "entity": { "id": "{{aniId}}", "title": "kardeXim",
                             "occurred_at": "2026-03-12T10:00:00.000Z",
                             "occurred_year": 2026, "occurred_month": 3, "occurred_day": 12 } } }
            ] }
            """;

        var bozuk = System.Text.Encoding.UTF8.GetBytes(govde);
        bozuk[Array.IndexOf(bozuk, (byte)'X')] = 0xFE;

        var response = await client.PostAsync(
            "/v1/sync/push",
            new ByteArrayContent(bozuk)
            {
                Headers = { ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("application/json") },
            });

        var metin = await response.Content.ReadAsStringAsync();

        Assert.True(
            response.StatusCode == HttpStatusCode.OK,
            $"Beklenen 200 + rejected, gelen {(int)response.StatusCode}: {metin[..Math.Min(300, metin.Length)]}");
        Assert.Contains("payload_encoding_invalid", metin, StringComparison.Ordinal);

        // Ve KUYRUK ACIK KALIYOR: ayni batch'teki saglam satir yaziliyor.
        var devam = await PushAsync(
            client, deviceId, Degisiklik("memory", saglam, "upsert", 0, AniGovdesi(saglam)));

        Assert.Equal("applied", Assert.Single(devam.Results).Status);
    }

    [Fact]
    public async Task Batch_ust_siniri_asilirsa_400_donuyor()
    {
        var (client, deviceId) = await HesapAsync();

        var changes = Enumerable.Range(0, 201).Select(_ =>
        {
            var id = Guid.CreateVersion7();
            return Degisiklik("memory", id, "upsert", 0, AniGovdesi(id));
        }).ToArray();

        var response = await client.PostAsJsonAsync("/v1/sync/push", new { deviceId, changes });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var problem = await response.Content.ReadFromJsonAsync<JsonObject>();
        Assert.Equal("batch_too_large", problem!["errorCode"]!.GetValue<string>());
    }

    [Fact]
    public async Task Govde_1_MBi_asarsa_reddediliyor()
    {
        // Sayi siniri islemede, BOYUT siniri uc noktada: 200 kucuk satir ile
        // 200 tane 20.000 karakterlik not ayni sayi ama cok farkli bellek.
        // HER SATIR TEK BASINA GECERLI: 200 degisiklik siniri asilmiyor ve
        // hicbir not sutun sinirini (20.000) asmiyor. Reddin TEK sebebi
        // toplam boyut olsun.
        var (client, deviceId) = await HesapAsync();

        var changes = Enumerable.Range(0, 200).Select(_ =>
        {
            var id = Guid.CreateVersion7();
            return Degisiklik("memory", id, "upsert", 0,
                AniGovdesi(id, not: new string('x', 6_000)));
        }).ToArray();

        var response = await client.PostAsJsonAsync("/v1/sync/push", new { deviceId, changes });
        var govde = await response.Content.ReadAsStringAsync();

        // 413, 500 DEGIL. Istemci 500'u "sunucu bozuk" diye okur ve batch'i
        // kucultmek yerine ayni istegi yeniden dener; kuyruk orada kilitlenir.
        Assert.True(
            response.StatusCode == HttpStatusCode.RequestEntityTooLarge,
            $"Beklenen 413, gelen {(int)response.StatusCode}. Govde: {govde[..Math.Min(300, govde.Length)]}");

        Assert.Contains("payload_too_large", govde, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Bozuk_JSON_govdesi_500_degil_400_donuyor()
    {
        // Ayni hattin oteki ucu: okunamayan bir govde de istemciye "sunucu
        // bozuk" dememeli. Push'a ozgu degil, butun uclari ilgilendiriyor.
        var (client, _) = await HesapAsync();

        var response = await client.PostAsync(
            "/v1/sync/push",
            new StringContent("{ bu gecerli JSON degil", System.Text.Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    // --- Sahiplik ve cihaz -------------------------------------------------

    [Fact]
    public async Task Kayitli_olmayan_cihazla_push_REDDEDILIYOR()
    {
        // Istemci baska bir cihazin kimligini iddia edebilseydi, echo
        // kuralini kullanarak kendi degisikliklerini o cihazdan gizleyebilirdi.
        var (client, _) = factory.CreateAuthenticatedClient();
        var aniId = Guid.CreateVersion7();

        var response = await client.PostAsJsonAsync("/v1/sync/push", new
        {
            deviceId = Guid.CreateVersion7(),
            changes = new[] { Degisiklik("memory", aniId, "upsert", 0, AniGovdesi(aniId)) },
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var problem = await response.Content.ReadFromJsonAsync<JsonObject>();
        Assert.Equal("device_unknown", problem!["errorCode"]!.GetValue<string>());
    }

    [Fact]
    public async Task Baskasinin_cihaz_kimligi_KABUL_EDILMIYOR()
    {
        var (_, kurbaninCihazi) = await HesapAsync();
        var (saldirgan, _) = factory.CreateAuthenticatedClient();
        var aniId = Guid.CreateVersion7();

        var response = await saldirgan.PostAsJsonAsync("/v1/sync/push", new
        {
            deviceId = kurbaninCihazi,
            changes = new[] { Degisiklik("memory", aniId, "upsert", 0, AniGovdesi(aniId)) },
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Baskasinin_kaydinin_kimligiyle_push_o_kayda_DOKUNAMIYOR()
    {
        // IDOR (§7.2, TR-M14-22). Saldirgan kurbanin ani kimligini biliyor ve
        // uzerine yazmaya calisiyor.
        //
        // KORUNAN IKI SEY: (a) kurbanin satiri degismez, (b) yanit kurbanin
        // hicbir alanini sizdirmaz — cakisma govdesi bile donmez, cunku
        // sahiplik suzgeci saldirgan icin o kaydi HIC var etmiyor.
        var (kurban, kurbaninCihazi) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        await PushAsync(
            kurban, kurbaninCihazi,
            Degisiklik("memory", aniId, "upsert", 0, AniGovdesi(aniId, baslik: "Kurbanin anisi")));

        var (saldirgan, saldirganinCihazi) = await HesapAsync();

        var response = await saldirgan.PostAsJsonAsync("/v1/sync/push", new
        {
            deviceId = saldirganinCihazi,
            changes = new[]
            {
                Degisiklik("memory", aniId, "upsert", 1, AniGovdesi(aniId, baslik: "Ele gecirildi")),
            },
        });

        var govde = await response.Content.ReadAsStringAsync();
        Assert.DoesNotContain("Kurbanin anisi", govde, StringComparison.Ordinal);

        // ⚠️ BUGUNKU DAVRANIS 409 ve bu bir TASARIM ACIGI, guvenlik acigi
        // degil. `memories` tablosunun birincil anahtari tek basina `id`;
        // sahiplik suzgeci saldirgana kaydi gostermedigi icin sunucu YENI bir
        // satir acmaya calisiyor ve benzersizlik kisiti patliyor.
        //
        // Zararsiz gorunuyor ama MESRU bir senaryosu var: ayni cihazda
        // oturum kapatip BASKA bir hesapla girmek. Yerel kayitlar yeni
        // kullanicinin adina push edilir ve kuyruk her denemede burada
        // kilitlenir. Kalici cozum bilesik anahtar — (owner_id, id) — ve o
        // on dort tabloyu birden ilgilendiren bir goc karari.
        // Yol haritasi §11'e acik soru olarak yazildi.
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var satir = await SatirAsync<Domain.Memories.Memory>(db, q => q.Where(m => m.Id == aniId));
        Assert.NotNull(satir);
        Assert.Equal("Kurbanin anisi", satir.Title);
        Assert.Equal(1, satir.Version);
    }

    [Fact]
    public async Task Govdedeki_owner_id_YOK_SAYILIYOR()
    {
        // Istemci bugun `owner_id: "local"` gonderiyor (anonim -> hesap
        // yukseltmesi henuz yazilmadi). Sahiplik TOKEN'DAN geliyor.
        var (client, deviceId) = await HesapAsync();
        var aniId = Guid.CreateVersion7();

        await PushAsync(client, deviceId, Degisiklik("memory", aniId, "upsert", 0, AniGovdesi(aniId)));

        var me = await (await client.GetAsync("/v1/me")).Content.ReadFromJsonAsync<JsonObject>();
        var userId = Guid.Parse(me!["id"]!.GetValue<string>());

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var ani = await SatirAsync<Domain.Memories.Memory>(db, q => q.Where(m => m.Id == aniId));
        Assert.NotNull(ani);
        Assert.Equal(userId, ani.OwnerId);
    }

    // --- Yanit modeli ------------------------------------------------------

    private sealed record PushYaniti(List<PushSonucu> Results, long Cursor);

    private sealed record PushSonucu(
        string EntityId,
        string Status,
        int? Version,
        long? Seq,
        SunucuSurumu? Server,
        string? Reason);

    private sealed record SunucuSurumu(int Version, JsonObject Payload);
}
