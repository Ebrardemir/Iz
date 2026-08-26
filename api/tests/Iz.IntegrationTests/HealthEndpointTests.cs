using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Iz.IntegrationTests;

/// <summary>
/// Faz 0'ın çıkış kriteri: servis ayağa kalkıyor, sağlık uçları cevap
/// veriyor ve hata gövdesi ProblemDetails biçiminde dönüyor.
/// </summary>
public sealed class HealthEndpointTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task Liveness_ucu_ayakta_oldugunu_bildirir()
    {
        var response = await _client.GetAsync("/health/live");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Readiness_ucu_trafige_hazir_oldugunu_bildirir()
    {
        var response = await _client.GetAsync("/health/ready");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Saglik_ucu_calistigi_ortami_bildirir()
    {
        // Dağıtımın gerçekten güncellendiğini doğrulamanın en ucuz yolu.
        var payload = await _client.GetFromJsonAsync<HealthPayload>("/health");

        Assert.NotNull(payload);
        Assert.Equal("ok", payload.Status);
        Assert.False(string.IsNullOrWhiteSpace(payload.Environment));
    }

    [Fact]
    public async Task Bilinmeyen_uc_ProblemDetails_dondurur()
    {
        // Rapor 22.1 — hata gövdesi HER ZAMAN ProblemDetails.
        // İstemcideki Failure eşlemesi buna güveniyor.
        var response = await _client.GetAsync("/boyle-bir-uc-yok");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal(
            "application/problem+json",
            response.Content.Headers.ContentType?.MediaType);

        var problem = await response.Content.ReadFromJsonAsync<ProblemPayload>();
        Assert.NotNull(problem);
        Assert.Equal("not_found", problem.ErrorCode);
        Assert.False(string.IsNullOrWhiteSpace(problem.TraceId));
    }

    [Fact]
    public async Task OpenAPI_sozlesmesi_yayinlaniyor()
    {
        // ADR-B03: istemci client'ı bu belgeden üretilecek.
        var response = await _client.GetAsync("/openapi/v1.json");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    private sealed record HealthPayload(string Status, string Environment);

    private sealed record ProblemPayload(string? ErrorCode, string? TraceId);
}
