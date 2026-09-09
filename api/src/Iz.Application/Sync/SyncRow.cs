using System.Text.Json;

namespace Iz.Application.Sync;

/// <summary>
/// İstemcinin gönderdiği bir TABLO SATIRI — okuma tarafı.
/// </summary>
/// <remarks>
/// ANAHTARLAR SQL SÜTUN ADI, camelCase DEĞİL: <c>occurred_year</c>,
/// <c>is_favorite</c>, <c>created_at</c>. Kaynağı istemcideki
/// <c>outboxRowJson</c> — Drift satırı <c>use_sql_column_name_as_json_key</c>
/// ile serileştiriyor (iz/build.yaml). Yol haritası §4.1'deki örnek gövde
/// camelCase yazıyordu; GERÇEK olan istemcinin ürettiği biçimdir, çünkü
/// kullanıcının cihazında bekleyen kuyruk o biçimde yazılmış durumda.
///
/// TARİHLER ISO-8601 METİN (istemcideki <c>_IsoValueSerializer</c>). Çıplak
/// bir sayı olsaydı okuyan tarafın saniye mi milisaniye mi olduğunu tahmin
/// etmesi gerekirdi.
///
/// OKUYUCU BİLEREK BAĞIŞLAYICI. Eksik alan, <c>null</c> ya da beklenmedik
/// tipteki bir değer istisna atmıyor; varsayılana düşüyor. Gerekçesi
/// TR-M13-22'nin sunucu karşılığı: katı bir okuyucu, tek bir bozuk alan
/// yüzünden o kullanıcının TÜM kuyruğunu kilitlerdi ve kullanıcı hiçbir
/// şeyin eşitlenmediğini görüp sebebini asla öğrenemezdi. Bir alanı
/// varsayılanla yazmanın bedeli o alan; kuyruğu kilitlemenin bedeli her şey.
///
/// Kimlik alanları bu kuralın DIŞINDA — onlar <see cref="SyncEntityKey"/>'de
/// sıkı ayrıştırılıyor ve hata kaydı reddediyor.
/// </remarks>
public readonly struct SyncRow(JsonElement element)
{
    private readonly JsonElement _element = element;

    /// <summary>Gövdesi hiç olmayan satır — silme isteklerinde kullanılıyor.</summary>
    public static SyncRow Empty => default;

    private bool TryRead(string field, out JsonElement value)
    {
        value = default;

        return _element.ValueKind == JsonValueKind.Object &&
               _element.TryGetProperty(field, out value) &&
               value.ValueKind != JsonValueKind.Null;
    }

    public string? Text(string field) =>
        TryRead(field, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

    /// <summary>Boş geçilemeyen metin sütunları için — sütun <c>NOT NULL</c>.</summary>
    public string TextOr(string field, string fallback) => Text(field) ?? fallback;

    public bool Bool(string field) => TryRead(field, out var value)
        ? value.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.False => false,

            // SQLite boolean'ı 0/1 olarak saklıyor; istemci onu bool'a
            // çevirerek gönderiyor ama eski bir kuyruk satırı sayı taşıyor
            // olabilir. İkisini de kabul etmek bir satırı kurtarır.
            JsonValueKind.Number => value.TryGetInt32(out var number) && number != 0,
            _ => false,
        }
        : false;

    public int? NullableInt32(string field) =>
        TryRead(field, out var value) && value.ValueKind == JsonValueKind.Number &&
        value.TryGetInt32(out var number)
            ? number
            : null;

    public int Int32(string field, int fallback = 0) => NullableInt32(field) ?? fallback;

    public long? NullableInt64(string field) =>
        TryRead(field, out var value) && value.ValueKind == JsonValueKind.Number &&
        value.TryGetInt64(out var number)
            ? number
            : null;

    public double? NullableDouble(string field) =>
        TryRead(field, out var value) && value.ValueKind == JsonValueKind.Number &&
        value.TryGetDouble(out var number)
            ? number
            : null;

    public Guid? NullableGuid(string field) =>
        Text(field) is { } text && Guid.TryParse(text, out var id) ? id : null;

    /// <summary>
    /// ISO-8601 metni — HER ZAMAN UTC'ye çevrilerek.
    /// </summary>
    /// <remarks>
    /// ÇEVİRİ ŞART, KOZMETİK DEĞİL. Sunucudaki sütunlar
    /// <c>timestamp with time zone</c> ve Npgsql oraya sıfırdan farklı bir
    /// offset taşıyan <c>DateTimeOffset</c> yazmayı REDDEDİYOR — istisna
    /// atıyor. O istisna tek bir satırdan çıkıp BÜTÜN batch'i düşürürdü ve
    /// kullanıcının kuyruğu her denemede aynı yerde patlardı.
    ///
    /// <c>AssumeUniversal</c>: offset taşımayan bir metin UTC sayılıyor.
    /// İstemcinin gerçeği bu — Drift tarihleri UTC ISO-8601 olarak saklıyor
    /// (iz/build.yaml, <c>store_date_time_values_as_text</c>). Sunucunun
    /// yerel saatini varsaymak, sunucu taşındığı gün eski kayıtların saatini
    /// kaydırırdı.
    /// </remarks>
    public DateTimeOffset? NullableDateTime(string field) =>
        Text(field) is { } text &&
        DateTimeOffset.TryParse(
            text,
            System.Globalization.CultureInfo.InvariantCulture,
            System.Globalization.DateTimeStyles.AssumeUniversal |
            System.Globalization.DateTimeStyles.AdjustToUniversal,
            out var moment)
            ? moment.ToUniversalTime()
            : null;

    /// <summary>Boş geçilemeyen tarih sütunları için.</summary>
    /// <remarks>
    /// Yedeği ÇAĞIRAN veriyor ve her zaman sunucunun saati oluyor. Sabit bir
    /// tarih (ör. <c>DateTimeOffset.MinValue</c>) yazsaydık, okunamayan bir
    /// tarih kaydı 1 Ocak 0001'e düşürür ve kullanıcı anısını zaman
    /// çizgisinin en dibinde bulurdu — kaybolmuş gibi.
    /// </remarks>
    public DateTimeOffset DateTime(string field, DateTimeOffset fallback) =>
        NullableDateTime(field) ?? fallback;
}
