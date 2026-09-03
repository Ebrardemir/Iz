using System.Net;
using System.Net.Http.Json;
using Iz.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Iz.IntegrationTests;

/// <summary>Cihaz kaydı ve sahiplik sınırı (TR-M14-22).</summary>
[Collection(IzApiCollection.Name)]
public sealed class DeviceEndpointTests(IzApiFactory factory)
{
    [Fact]
    public async Task Cihaz_kaydedilir_ve_kimligi_sunucu_uretir()
    {
        var (client, _) = factory.CreateAuthenticatedClient();

        var response = await client.PostAsJsonAsync(
            "/v1/devices",
            new { platform = "ios", appVersion = "1.5.0+42", schemaVersion = 7 });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var device = await response.Content.ReadFromJsonAsync<DevicePayload>();
        Assert.NotNull(device);
        Assert.NotEqual(Guid.Empty, device.Id);
        Assert.Equal("ios", device.Platform);
        Assert.Equal(7, device.SchemaVersion);
    }

    [Fact]
    public async Task Ayni_kimlikle_ikinci_kayit_yeni_cihaz_acmaz()
    {
        var (client, _) = factory.CreateAuthenticatedClient();

        var ilk = await (await client.PostAsJsonAsync(
            "/v1/devices", new { platform = "android", schemaVersion = 5 }))
            .Content.ReadFromJsonAsync<DevicePayload>();

        Assert.NotNull(ilk);

        var ikinci = await (await client.PostAsJsonAsync(
            "/v1/devices", new { id = ilk.Id, platform = "android", schemaVersion = 7 }))
            .Content.ReadFromJsonAsync<DevicePayload>();

        Assert.NotNull(ikinci);
        Assert.Equal(ilk.Id, ikinci.Id);

        // Şema sürümü tazelendi: istemci güncellendiğinde sunucu bunu görmeli
        // (TR-M13-21 minimum istemci sürümü kontrolü buna dayanacak).
        Assert.Equal(7, ikinci.SchemaVersion);
    }

    [Fact]
    public async Task Bilinmeyen_platform_kaydi_reddetmez()
    {
        // Kullanıcı, istemcinin yazım hatası yüzünden cihazını
        // kaydedememekle cezalandırılmamalı.
        var (client, _) = factory.CreateAuthenticatedClient();

        var response = await client.PostAsJsonAsync(
            "/v1/devices", new { platform = "windows-phone" });

        var device = await response.Content.ReadFromJsonAsync<DevicePayload>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(device);
        Assert.Equal("unknown", device.Platform);
    }

    [Fact]
    public async Task Baskasinin_cihaz_kimligiyle_gelen_istek_o_cihaza_dokunamaz()
    {
        // IDOR senaryosu — yol haritası §7.2 ve TR-M14-22'nin testi.
        // Kurban bir cihaz kaydeder; saldırgan aynı kimliği kendi token'ıyla
        // gönderir. Beklenen: kurbanın kaydı DEĞİŞMEZ.
        var (kurban, _) = factory.CreateAuthenticatedClient();
        var kurbaninCihazi = await (await kurban.PostAsJsonAsync(
            "/v1/devices", new { platform = "ios", appVersion = "1.0.0" }))
            .Content.ReadFromJsonAsync<DevicePayload>();

        Assert.NotNull(kurbaninCihazi);

        var (saldirgan, _) = factory.CreateAuthenticatedClient();
        var saldirganinYaniti = await (await saldirgan.PostAsJsonAsync(
            "/v1/devices",
            new { id = kurbaninCihazi.Id, platform = "android", appVersion = "9.9.9" }))
            .Content.ReadFromJsonAsync<DevicePayload>();

        Assert.NotNull(saldirganinYaniti);

        // Saldırgana kurbanın kimliği DÖNMEZ; kendi yeni cihazı açılır.
        Assert.NotEqual(kurbaninCihazi.Id, saldirganinYaniti.Id);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        // Global sorgu süzgecini burada bilerek atlıyoruz: testin görevi
        // "kurbanın satırı gerçekten bozulmamış mı" sorusuna cevap vermek.
        var kurbaninKaydi = await db.Devices
            .IgnoreQueryFilters()
            .SingleAsync(d => d.Id == kurbaninCihazi.Id);

        Assert.Equal("1.0.0", kurbaninKaydi.AppVersion);
        Assert.Equal(Iz.Domain.Devices.DevicePlatform.Ios, kurbaninKaydi.Platform);
    }

    [Fact]
    public async Task Tokensiz_cihaz_kaydi_401_alir()
    {
        var response = await factory.CreateClient()
            .PostAsJsonAsync("/v1/devices", new { platform = "ios" });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private sealed record DevicePayload(
        Guid Id,
        string Platform,
        string? AppVersion,
        int? SchemaVersion,
        DateTimeOffset LastSeenAt);
}
