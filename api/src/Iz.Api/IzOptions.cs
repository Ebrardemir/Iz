namespace Iz.Api;

/// <summary>
/// Uygulamanın çalışma zamanı yapılandırması.
/// </summary>
/// <remarks>
/// KURAL: Bağlantı dizeleri, anahtarlar ve sırlar YALNIZ ortam
/// değişkeninden gelir; appsettings.json'a yazılmaz ve depoya girmez
/// (TR-M14: "Sırlar depoda durmaz").
///
/// Bunun ikinci bir faydası var: barındırma kararı henüz verilmedi.
/// Yapılandırma tamamen ortamdan geldiği ve uygulama durumsuz olduğu
/// sürece aynı imaj hem kiralık bir VPS'te hem yönetilen bir konteyner
/// servisinde çalışır. Karar ertelenebilir kalıyor.
/// </remarks>
public sealed class IzOptions
{
    public const string SectionName = "Iz";

    /// <summary>dev | staging | prod — istemcideki IZ_ENV ile aynı sözlük.</summary>
    public string Environment { get; init; } = "dev";

    /// <summary>PostgreSQL bağlantı dizesi. Ortamdan gelir.</summary>
    public string? DatabaseConnection { get; init; }

    /// <summary>Redis bağlantı dizesi (idempotency + hız sınırı).</summary>
    public string? RedisConnection { get; init; }

    /// <summary>Firebase proje kimliği — ID token'ın "aud" alanı bununla doğrulanır (ADR-B15).</summary>
    public string? FirebaseProjectId { get; init; }

    public bool IsProduction =>
        string.Equals(Environment, "prod", StringComparison.OrdinalIgnoreCase);
}
