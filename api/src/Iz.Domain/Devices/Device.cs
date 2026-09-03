namespace Iz.Domain.Devices;

/// <summary>
/// Kullanıcının oturum açmış bir cihazı.
/// </summary>
/// <remarks>
/// NİYE GEREKLİ? Sync'te iki işi var:
///   1. Echo önleme — pull yanıtında "bu değişikliği zaten sen gönderdin"
///      diyebilmek için değişikliğin hangi cihazdan geldiği bilinmeli (§4.2).
///   2. Sürüm uyumu — istemci şema/uygulama sürümünü bildirir; sunucu
///      desteklemediği kadar eski bir istemciyi senkronize etmez (TR-M13-21).
/// </remarks>
public sealed class Device
{
    /// <summary>
    /// Cihaz kimliği — SUNUCU üretir, istemci saklayıp geri gönderir.
    /// </summary>
    /// <remarks>
    /// NEDEN istemci üretmiyor? Üretseydi bir istemci başka bir cihazın
    /// kimliğini iddia edebilirdi ve "kendi değişikliğini atla" kuralı
    /// silah haline gelirdi: saldırgan kurbanın deviceId'siyle yazsa,
    /// kurbanın cihazı o değişikliği kendi echo'su sanıp atlardı.
    /// Sunucunun ürettiği kimlik bu senaryoyu tamamen kapatır.
    /// </remarks>
    public required Guid Id { get; init; }

    public required Guid UserId { get; init; }

    public required DevicePlatform Platform { get; init; }

    /// <summary>Uygulama sürümü (<c>1.5.0+42</c>). TR-M13-20.</summary>
    public string? AppVersion { get; set; }

    /// <summary>İstemcinin Drift şema sürümü. TR-M13-20/21.</summary>
    public int? SchemaVersion { get; set; }

    /// <summary>
    /// Push bildirim jetonu. 1.x'te KULLANILMIYOR — bildirimlerin tamamı
    /// yereldir (TRD M10). Sütun 2.0'daki ortak koleksiyon davetleri için
    /// şemada duruyor, bugün her zaman <c>null</c>.
    /// </summary>
    public string? PushToken { get; set; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset LastSeenAt { get; set; }
}
