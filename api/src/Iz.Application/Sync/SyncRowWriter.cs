using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization.Metadata;
using Iz.Domain.Sync;

namespace Iz.Application.Sync;

/// <summary>
/// Sunucudaki satırı istemcinin okuduğu gövde biçimine çevirir.
/// </summary>
/// <remarks>
/// Bugün tek kullanıcısı çakışma yanıtı ("sunucudaki sürüm bu"); Faz 3'ün
/// ikinci adımında <c>/v1/sync/pull</c> de aynı biçimi yayacak.
///
/// OKUMA ELLE, YAZMA OTOMATİK — ve asimetri bilinçli.
/// Okuma (<see cref="SyncEntityMapper.Apply"/>) elle yazılıyor çünkü orada
/// İSTEMCİYE GÜVENMİYORUZ: hangi sütunun gövdeden yazılabileceğine sunucu
/// karar vermeli. Yazma tarafında böyle bir sınır yok; kendi satırımızı
/// kendimize serileştiriyoruz.
///
/// Asimetrinin riski, sunucuya bir sütun eklenip <c>Apply</c>'a eklenmemesi:
/// alan yanıtta görünür ama gövdeden hiç okunmaz, yani sessizce hiç
/// senkronize olmaz. <c>SyncPayloadTests</c>'teki gidiş-dönüş testi tam
/// bunu yakalıyor.
///
/// SNAKE_CASE, çünkü istemcinin ürettiği biçim o (Drift'in
/// <c>use_sql_column_name_as_json_key</c> ayarı). Tarihler ISO-8601 —
/// <c>DateTimeOffset</c>'in varsayılan biçimi zaten bu.
/// </remarks>
public static class SyncRowWriter
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        TypeInfoResolver = new DefaultJsonTypeInfoResolver
        {
            Modifiers = { DropComputedFields },
        },
    };

    public static JsonNode Write(ISyncable entity) =>
        JsonSerializer.SerializeToNode(entity, entity.GetType(), Options)
        ?? throw new InvalidOperationException("Satır serileştirilemedi.");

    /// <summary>
    /// <c>SyncEntityType</c> ve <c>SyncId</c> gövdeye girmiyor.
    /// </summary>
    /// <remarks>
    /// İkisi de mevcut sütunlardan türetiliyor ve sunucuda bile sütunları
    /// yok (<c>SyncableConfiguration</c> ikisini de <c>Ignore</c> ediyor).
    /// Gövdeye koysaydık istemci onları kendi satırına yazmaya çalışır ve
    /// karşılığı olmayan iki alan bulurdu.
    /// </remarks>
    private static void DropComputedFields(JsonTypeInfo info)
    {
        if (!typeof(ISyncable).IsAssignableFrom(info.Type))
        {
            return;
        }

        for (var i = info.Properties.Count - 1; i >= 0; i--)
        {
            if (info.Properties[i].Name is "sync_entity_type" or "sync_id")
            {
                info.Properties.RemoveAt(i);
            }
        }
    }
}
