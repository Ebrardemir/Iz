using System.Text.Json;
using System.Text.Json.Nodes;

namespace Iz.Application.Sync;

/// <summary>Bir push isteğinin çözülmüş hâli.</summary>
/// <param name="DeviceId">
/// Değişiklikleri gönderen cihaz. <c>change_log.device_id</c> buradan
/// doluyor ve echo önlemenin dayanağı o (yol haritası §4.2).
/// </param>
public sealed record SyncPushCommand(Guid DeviceId, IReadOnlyList<SyncPushChange> Changes);

/// <summary>Kuyruktaki tek bir satır.</summary>
/// <param name="BaseVersion">
/// İstemcinin bildiği son sürüm; yeni kayıtta 0. Sunucudaki sürümle
/// eşleşmiyorsa araya biri girmiş demektir ve sunucu KENDİLİĞİNDEN EZMEZ.
/// </param>
/// <param name="Payload">
/// <c>{ v, entity, links }</c> zarfı — bkz. <see cref="SyncPayload"/>.
/// Silme isteklerinde boş olabilir: silmek için gövde gerekmiyor.
/// </param>
public sealed record SyncPushChange(
    string? EntityType,
    string? EntityId,
    string? Op,
    int BaseVersion,
    JsonElement? Payload);

/// <summary>Bir değişikliğin sonucu.</summary>
public enum SyncPushStatus
{
    /// <summary>Yazıldı (ya da zaten o hâldeydi).</summary>
    Applied,

    /// <summary>
    /// Sunucudaki sürüm istemcinin bildiğinden farklı. Hiçbir şey yazılmadı.
    /// </summary>
    Conflict,

    /// <summary>
    /// Sunucu bu satırı hiç işleyemedi. Sebebi
    /// <see cref="PushRejectionReasons"/>'da.
    /// </summary>
    Rejected,
}

/// <param name="EntityId">
/// İstemcinin GÖNDERDİĞİ metin, aynen yankılanıyor: outbox satırını onunla
/// eşleştiriyor. Kanonikleştirseydik büyük harfli bir UUID gönderen istemci
/// kendi satırını sonuçta bulamaz ve kuyruktan hiç düşüremezdi.
/// </param>
/// <param name="Version">Yazmadan SONRAKİ sürüm; istemci kendi satırına yazıyor.</param>
/// <param name="Seq">
/// Bu değişikliğin <c>change_log</c> sırası. Değişiklik bir şeyi
/// DEĞİŞTİRMEDİYSE <c>null</c>: aynı gövde ikinci kez gelince günlüğe satır
/// düşmüyor.
/// </param>
/// <param name="Server">Yalnız çakışmada dolu.</param>
/// <param name="Reason">Yalnız redde dolu.</param>
public sealed record SyncPushChangeResult(
    string EntityId,
    SyncPushStatus Status,
    int? Version = null,
    long? Seq = null,
    SyncServerVersion? Server = null,
    string? Reason = null);

/// <summary>Çakışmada sunucunun elindeki hâl.</summary>
/// <remarks>
/// BAĞLAR BURADA YOK. Bağlar sürüm çakışması üretmiyor (satır bazlı
/// birleşiyorlar, §4.4), dolayısıyla kullanıcıya gösterilecek "iki sürüm"un
/// parçası değiller.
/// </remarks>
public sealed record SyncServerVersion(int Version, JsonNode Payload);

/// <param name="Cursor">
/// Sunucunun O ANKİ günlük başı.
/// </param>
/// <remarks>
/// ⚠️ BU DEĞER PULL CURSOR'I DEĞİL — bir İPUCU. İstemci bunu doğrudan
/// <c>SyncState.cursor</c>'a yazarsa, push ile aynı anda BAŞKA bir cihazın
/// yazdığı satırları atlamış olur ve o değişiklikler o cihaza HİÇ gelmez.
/// Pull cursor'ını yalnız pull ilerletir (yol haritası §4.2).
/// </remarks>
public sealed record SyncPushResult(IReadOnlyList<SyncPushChangeResult> Results, long Cursor);

/// <summary>
/// <c>status: "rejected"</c> sebepleri — istemci ile sunucu arasındaki sözlük.
/// </summary>
/// <remarks>
/// REDDEDİLEN SATIR KUYRUKTA KALIR mı, DÜŞER mi? İstemcinin kararı, ama
/// ayrım bu sözlükten okunuyor: <see cref="EntityIdInvalid"/> gibi bir sebep
/// tekrar denemeyle düzelmez (satır düşmeli, yoksa kuyruk sonsuza kadar
/// takılır), <see cref="EntitlementRequired"/> ise düzelir (abonelik
/// alınınca).
///
/// Metinler DEĞİŞMEZ: kullanıcının cihazında bekleyen bir kuyruk uygulama
/// güncellemesinden sağ çıkıyor ve eski istemci bu kodlara bakarak dallanıyor.
/// </remarks>
public static class PushRejectionReasons
{
    /// <summary>Sunucunun tanımadığı bir tür — istemci sunucudan yeni.</summary>
    public const string UnknownEntityType = "unknown_entity_type";

    /// <summary>Kimlik ayrıştırılamadı; bağ türüne tekil UUID gelmiş olabilir.</summary>
    public const string EntityIdInvalid = "entity_id_invalid";

    /// <summary><c>op</c> alanı <c>upsert</c>/<c>delete</c> değil.</summary>
    public const string OperationInvalid = "operation_invalid";

    /// <summary>Gövde yok ya da nesne değil.</summary>
    public const string PayloadInvalid = "payload_invalid";

    /// <summary>Zarf sürümü sunucunun okuyabileceğinden yüksek.</summary>
    public const string PayloadVersionUnsupported = "payload_version_unsupported";

    /// <summary>Zarfın içinde <c>entity</c> yok.</summary>
    public const string PayloadEntityMissing = "payload_entity_missing";

    /// <summary>
    /// Sync İZ+ özelliği (ADR-B09) ve hesap free planda.
    /// </summary>
    /// <remarks>
    /// ⚠️ HENÜZ ÜRETİLMİYOR — kapı Faz 4'te takılıyor
    /// (<c>PushChangesHandler</c> içindeki işaretli nokta). Sabit bugünden
    /// duruyor ki istemci tarafı paywall'ı beklemeden yazılabilsin.
    /// </remarks>
    public const string EntitlementRequired = "entitlement_required";
}
