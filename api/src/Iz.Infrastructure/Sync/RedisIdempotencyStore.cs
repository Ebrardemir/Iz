using System.Text.Json;
using Iz.Application.Sync;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;

namespace Iz.Infrastructure.Sync;

/// <inheritdoc cref="IIdempotencyStore"/>
/// <remarks>
/// HATALARI YUTUYOR — ve bu, bu sınıfın en önemli özelliği.
///
/// Redis'e ulaşamadığımızda push'u reddetseydik, Redis'in her hıçkırığında
/// BÜTÜN kullanıcıların kuyruğu dururdu. Oysa idempotency'nin yokluğunda
/// olabilecek en kötü şey bir yanlış çakışma — veri bozulması değil.
/// "Kuyruk kilitlenmesin" kuralı burada da daha ağır basıyor.
///
/// Yutulan her hata LOGLANIYOR. Sessizce yutmak, Redis'in aylardır kapalı
/// olduğunu kimsenin fark etmemesi demekti.
///
/// ⚠️ LOG İÇERİK TAŞIMIYOR (§5 standartları): yalnız kullanıcı kimliği ve
/// anahtar yazılıyor, yanıt gövdesi ASLA. Gövde kullanıcının anı metnini
/// içerebilir.
/// </remarks>
internal sealed class RedisIdempotencyStore(
    IConnectionMultiplexer redis,
    ILogger<RedisIdempotencyStore> logger) : IIdempotencyStore
{
    /// <summary>Yol haritası §4.1: anahtar 24 saat tutuluyor.</summary>
    /// <remarks>
    /// Süre, istemcinin bir push'u makul olarak yeniden deneyeceği en uzun
    /// pencereden uzun olmalı. Çevrimdışı kalan bir cihaz bir gün sonra
    /// bağlandığında aynı anahtarla dönerse, o an artık yeni bir istek
    /// sayılıyor — ve doğrusu da bu: aradan geçen sürede kullanıcı kaydı
    /// başka cihazdan değiştirmiş olabilir.
    /// </remarks>
    private static readonly TimeSpan Omur = TimeSpan.FromHours(24);

    private static readonly JsonSerializerOptions Bicim = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    public async Task<IdempotencyRecord?> FindAsync(
        Guid userId,
        string key,
        CancellationToken cancellationToken)
    {
        try
        {
            var deger = await redis.GetDatabase().StringGetAsync(Anahtar(userId, key));

            // METNE AÇIKÇA ÇEVİRİLİYOR. `RedisValue`'nun hem `string`e hem
            // `ReadOnlySpan<byte>`a örtük dönüşümü var; doğrudan
            // `Deserialize(deger, ...)` yazmak, System.Text.Json'ın her iki
            // aşırı yüklemesini de taşıyan sürümlerinde DERLENMİYOR
            // ("call is ambiguous"). Yerelde sessizce derlenip CI'da
            // patlayan tam olarak buydu.
            return (string?)deger is { Length: > 0 } json
                ? JsonSerializer.Deserialize<IdempotencyRecord>(json, Bicim)
                : null;
        }
        catch (Exception ex) when (Gecici(ex))
        {
            logger.LogWarning(
                ex,
                "Idempotency kaydı okunamadı; istek idempotency güvencesi OLMADAN işlenecek. "
                + "Kullanıcı: {UserId}",
                userId);

            return null;
        }
    }

    public async Task SaveAsync(
        Guid userId,
        string key,
        IdempotencyRecord record,
        CancellationToken cancellationToken)
    {
        try
        {
            await redis.GetDatabase().StringSetAsync(
                Anahtar(userId, key),
                JsonSerializer.Serialize(record, Bicim),
                Omur);
        }
        catch (Exception ex) when (Gecici(ex))
        {
            logger.LogWarning(
                ex,
                "Idempotency kaydı yazılamadı; bu isteğin tekrarı yanlış çakışma üretebilir. "
                + "Kullanıcı: {UserId}",
                userId);
        }
    }

    /// <summary>
    /// KULLANICI BAŞINA AD ALANI.
    /// </summary>
    /// <remarks>
    /// Anahtarı istemci üretiyor. Kullanıcıyla birleştirmeseydik, bir
    /// kullanıcının ürettiği anahtar BAŞKA bir kullanıcının kaydına çarpar ve
    /// ona ait bir yanıtı — içinde anı metniyle birlikte — döndürürdük.
    /// Çakışmanın kazara olması da mümkün: kimliği zayıf üreten bir istemci
    /// sürümü yeter.
    /// </remarks>
    private static string Anahtar(Guid userId, string key) => $"iz:idem:{userId}:{key}";

    /// <summary>
    /// Yutulacak hatalar: bağlantı ve zaman aşımı.
    /// </summary>
    /// <remarks>
    /// Her istisnayı yutmuyoruz. Bir serileştirme hatası ya da programlama
    /// hatası BİZİM hatamızdır ve görünmesi gerekir; yutulursa kalıcı olarak
    /// çalışmayan bir idempotency ile yaşamaya devam ederiz.
    /// </remarks>
    private static bool Gecici(Exception ex) =>
        ex is RedisConnectionException or RedisTimeoutException or TimeoutException;
}
