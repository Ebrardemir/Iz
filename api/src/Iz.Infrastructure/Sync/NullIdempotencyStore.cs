using Iz.Application.Sync;
using Microsoft.Extensions.Logging;

namespace Iz.Infrastructure.Sync;

/// <summary>
/// Redis yapılandırılmadığında devreye giren depo: hiçbir şey hatırlamaz.
/// </summary>
/// <remarks>
/// YALNIZ ÜRETİM DIŞINDA. Üretimde <c>IZ_Iz__RedisConnection</c> yoksa
/// uygulama AÇILMIYOR (bkz. <c>Program.cs</c>) — çünkü orada eksik
/// yapılandırmanın bedeli "sessizce kapalı bir güvence" olurdu ve kimse fark
/// etmezdi.
///
/// Yerelde ise Redis'siz çalışabilmek gerekiyor: bir geliştiricinin sağlık
/// uçlarına bakmak için üç konteyner kaldırması saçma. Bu sınıf o boşluğu
/// dolduruyor ve HER AÇILIŞTA UYARI BASIYOR — sessiz olsaydı, birinin
/// idempotency'nin aylardır kapalı olduğunu fark etmesi tesadüfe kalırdı.
///
/// Davranışı, Redis'in erişilemez olduğu duruma birebir denk: her istek
/// yeni sayılıyor. Bedeli, yeniden denenen bir push'ta bir yanlış çakışma.
/// </remarks>
internal sealed class NullIdempotencyStore : IIdempotencyStore
{
    public NullIdempotencyStore(ILogger<NullIdempotencyStore> logger) =>
        logger.LogWarning(
            "Redis yapılandırılmadı: Idempotency-Key GÜVENCESİ KAPALI. "
            + "Yeniden denenen bir push yanlış çakışma üretebilir. "
            + "Üretimde bu durum uygulamanın açılmasını engeller.");

    public Task<IdempotencyRecord?> FindAsync(
        Guid userId,
        string key,
        CancellationToken cancellationToken) =>
        Task.FromResult<IdempotencyRecord?>(null);

    public Task SaveAsync(
        Guid userId,
        string key,
        IdempotencyRecord record,
        CancellationToken cancellationToken) =>
        Task.CompletedTask;
}
