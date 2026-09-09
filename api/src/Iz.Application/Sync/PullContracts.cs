using System.Text.Json.Nodes;

namespace Iz.Application.Sync;

/// <summary>Bir pull sayfasının sonucu.</summary>
/// <param name="NextCursor">
/// İstemcinin bir SONRAKİ pull'da göndereceği değer.
/// </param>
/// <param name="HasMore">
/// Bu sayfadan sonra daha var mı? İstemci <c>true</c> olduğu sürece
/// çekmeye devam ediyor — bootstrap (yol haritası §4.3) tam olarak bu.
/// </param>
/// <remarks>
/// ⚠️ İSTEMCİ <see cref="NextCursor"/>'I ANCAK TÜM DEĞİŞİKLİKLERİ YEREL
/// TRANSACTION'A YAZDIKTAN SONRA KAYDEDER. Önce kaydederse ve araya bir
/// çökme girerse o sayfa BİR DAHA GELMEZ: içindeki değişiklikler o cihaza
/// hiç ulaşmaz ve kimse fark etmez. Yarıda kesilen bir pull'un aynı sayfayı
/// tekrar getirmesi zararsız, çünkü uygulama idempotent.
/// </remarks>
public sealed record SyncPullResult(
    IReadOnlyList<SyncPullChange> Changes,
    long NextCursor,
    bool HasMore);

/// <summary>Tek bir kaydın son hâli.</summary>
/// <param name="Seq">
/// Bu kaydın bu sayfadaki EN YÜKSEK günlük sırası.
/// </param>
/// <param name="Op"><c>upsert</c> · <c>delete</c>.</param>
/// <param name="DeviceId">
/// Değişikliği gönderen cihaz — ECHO ÖNLEMENİN dayanağı (yol haritası §4.2).
/// </param>
/// <param name="Payload">
/// Kaydın GÜNCEL satırı. Silmede <c>null</c>: silmek için gövde gerekmiyor
/// ve göndermek, kullanıcının sildiği veriyi kabloya geri koymak olurdu.
/// </param>
/// <remarks>
/// SUNUCU KENDİ CİHAZININ SATIRLARINI SÜZMÜYOR, İŞARETLİYOR — ayrım
/// bilinçli. Süzseydik sunucunun "hangi cihaz soruyor" bilgisine ihtiyacı
/// olurdu ve bu bilgi istemcinin SÖYLEDİĞİ bir şey; ona dayanan bir
/// süzgeç, yanlış cihaz kimliği gönderen bir istemcide sessizce veri
/// atlardı. Kararı istemciye bırakmak hem daha dürüst hem daha ucuz:
/// istemci kendi kimliğini kesin biliyor.
/// </remarks>
public sealed record SyncPullChange(
    long Seq,
    string EntityType,
    string EntityId,
    string Op,
    int Version,
    Guid? DeviceId,
    JsonNode? Payload);
