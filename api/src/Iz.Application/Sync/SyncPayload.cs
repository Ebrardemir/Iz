using System.Text.Json;

namespace Iz.Application.Sync;

/// <summary>
/// Push gövdesindeki <c>payload</c> zarfı: <c>{ "v", "entity", "links" }</c>.
/// </summary>
/// <remarks>
/// Kaynağı istemcideki <c>encodeOutboxPayload</c>
/// (iz/lib/features/sync/data/outbox_payload.dart).
///
/// BAĞLAR NEDEN ANA KAYDIN İÇİNDE GELİYOR?
/// "Anıdan kişiyi çıkardım" tek başına bir varlık değişikliği değil, bir BAĞ
/// değişikliği — ve outbox'ın <c>entityId</c>'si tekil. Bağları anının
/// gövdesiyle birlikte göndermek §1.1'deki "çıkarılan kişi ikinci cihazda
/// geri geliyor" hatasını kapatmanın en doğrudan yolu.
///
/// TOMBSTONE BAĞLAR DA GELİYOR: istemci yalnız canlı bağları gönderseydi
/// sunucu "eksik olan henüz gelmemiş" ile "eksik olan silinmiş"i ayırt
/// edemezdi.
///
/// SUNUCU BAĞI KENDİ SATIRI OLARAK SAKLIYOR ve ona kendi <c>change_log</c>
/// kaydını düşürüyor (bkz. <c>SyncEntityTypes</c>). Bağı ana kaydın bir
/// parçası saysaydık, iki cihazın aynı anıya FARKLI kişiler eklemesi
/// gereksiz bir çakışma üretirdi.
/// </remarks>
public sealed class SyncPayload
{
    /// <summary>
    /// Okuyabildiğimiz en yüksek zarf sürümü.
    /// </summary>
    /// <remarks>
    /// İstemci bunu <c>kOutboxPayloadVersion</c> olarak yazıyor. Daha
    /// yükseği geldiğinde o değişiklik REDDEDİLİYOR — sessizce yarım
    /// okumaktansa açıkça reddetmek doğru: yarım okunan bir gövde,
    /// kullanıcının verisini eksik yazar ve kimse fark etmez.
    /// </remarks>
    public const int SupportedVersion = 1;

    private SyncPayload(SyncRow entity, IReadOnlyList<SyncLinkGroup> links)
    {
        Entity = entity;
        Links = links;
    }

    public SyncRow Entity { get; }

    /// <summary>Gövdeye iliştirilmiş bağ satırları, tür tür.</summary>
    public IReadOnlyList<SyncLinkGroup> Links { get; }

    /// <summary>
    /// Zarfı çözer. Başarısızlıkta <paramref name="rejection"/> dolar ve o
    /// DEĞİŞİKLİK reddedilir — istek değil.
    /// </summary>
    /// <remarks>
    /// Tek bir bozuk gövde yüzünden 200 değişikliklik bir batch'i 400 ile
    /// geri çevirseydik, kullanıcının kuyruğu o satırda sonsuza kadar
    /// takılırdı: geri kalan 199 değişiklik de hiç gitmezdi.
    /// </remarks>
    public static bool TryParse(
        JsonElement? payload,
        out SyncPayload result,
        out string? rejection)
    {
        result = new SyncPayload(SyncRow.Empty, []);
        rejection = null;

        if (payload is not { ValueKind: JsonValueKind.Object } envelope)
        {
            rejection = PushRejectionReasons.PayloadInvalid;
            return false;
        }

        // `v` YOKSA 1 SAYILIYOR. Eksik sürüm etiketi bir belirsizlik değil:
        // ilk biçim buydu ve o gövdeyi okuyabiliyoruz.
        if (envelope.TryGetProperty("v", out var version) &&
            version.ValueKind == JsonValueKind.Number &&
            version.TryGetInt32(out var number) &&
            number > SupportedVersion)
        {
            rejection = PushRejectionReasons.PayloadVersionUnsupported;
            return false;
        }

        if (!envelope.TryGetProperty("entity", out var entity) ||
            entity.ValueKind != JsonValueKind.Object)
        {
            rejection = PushRejectionReasons.PayloadEntityMissing;
            return false;
        }

        result = new SyncPayload(new SyncRow(entity), ReadLinks(envelope));
        return true;
    }

    /// <remarks>
    /// TANIMADIĞIMIZ BAĞ TÜRÜ ATLANIYOR, reddedilmiyor. İstemci sunucudan
    /// yeniyse (yeni bir bağ tablosu eklenmiş) o grubu yazacak yerimiz yok;
    /// ama ana kaydı ve tanıdığımız bağları yazabiliyoruz. Tümünü reddetmek,
    /// tek bir yeni tablo yüzünden kullanıcının bütün anılarını buluttan
    /// uzak tutardı.
    /// </remarks>
    private static IReadOnlyList<SyncLinkGroup> ReadLinks(JsonElement envelope)
    {
        if (!envelope.TryGetProperty("links", out var links) ||
            links.ValueKind != JsonValueKind.Object)
        {
            return [];
        }

        var groups = new List<SyncLinkGroup>();

        foreach (var group in links.EnumerateObject())
        {
            if (group.Value.ValueKind != JsonValueKind.Array)
            {
                continue;
            }

            var mapper = SyncEntityMappers.Find(group.Name);
            if (mapper is not { IsLink: true })
            {
                continue;
            }

            var rows = new List<SyncRow>();
            foreach (var row in group.Value.EnumerateArray())
            {
                if (row.ValueKind == JsonValueKind.Object)
                {
                    rows.Add(new SyncRow(row));
                }
            }

            if (rows.Count > 0)
            {
                groups.Add(new SyncLinkGroup(mapper, rows));
            }
        }

        return groups;
    }
}

/// <summary>Tek bir bağ tablosuna ait satırlar.</summary>
public sealed record SyncLinkGroup(SyncEntityMapper Mapper, IReadOnlyList<SyncRow> Rows);
