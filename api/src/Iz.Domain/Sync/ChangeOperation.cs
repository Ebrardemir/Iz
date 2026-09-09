namespace Iz.Domain.Sync;

/// <summary>
/// Bir <c>change_log</c> satırının anlattığı değişim türü.
/// </summary>
/// <remarks>
/// İSTEMCİDEKİNDEN DAHA DAR. Orada <c>create</c> ve <c>update</c> ayrı
/// (OutboxOperation), burada ikisi <see cref="Upsert"/> altında birleşiyor —
/// çünkü pull'u alan cihaz için fark yok: kayıt yoksa açar, varsa günceller.
/// Ayrımı korusaydık, "bende create diyor ama kayıt zaten var" durumunu her
/// istemcinin ayrıca çözmesi gerekirdi.
/// </remarks>
public enum ChangeOperation
{
    Upsert,
    Delete,
}

/// <summary>
/// Kablodaki karşılıkları. Sayı DEĞİL metin yazılır: veritabanını elle okuyan
/// biri <c>1</c> görüp ne olduğunu tahmin etmek zorunda kalmasın, ve enum'a
/// yeni bir değer eklemek eski satırların anlamını kaydırmasın.
/// </summary>
public static class ChangeOperationKeys
{
    public const string Upsert = "upsert";
    public const string Delete = "delete";

    public static string ToKey(this ChangeOperation op) => op switch
    {
        ChangeOperation.Upsert => Upsert,
        ChangeOperation.Delete => Delete,
        _ => throw new ArgumentOutOfRangeException(nameof(op), op, null),
    };

    public static ChangeOperation FromKey(string key) => key switch
    {
        Upsert => ChangeOperation.Upsert,
        Delete => ChangeOperation.Delete,
        _ => throw new ArgumentOutOfRangeException(nameof(key), key, "Bilinmeyen işlem."),
    };
}
