namespace Iz.Application.Sync;

/// <summary>
/// <c>GET /v1/sync/state</c> yanıtı — Yedekleme Sağlığı ekranının (FR-164,
/// TR-M11-13) sunucu tarafındaki payı.
/// </summary>
/// <param name="ServerCursor">
/// Sunucunun o anki günlük başı. İstemci kendi cursor'ıyla karşılaştırıp
/// "geride miyim?" sorusunu cevaplıyor.
/// </param>
/// <param name="PendingCount">
/// İstemcinin gönderdiği cursor'dan sonra sunucuda bekleyen değişiklik
/// sayısı — yani İNDİRİLECEK olanlar.
/// </param>
/// <param name="LastChangeAt">
/// Bu hesabın verisinin sunucuda EN SON ne zaman değiştiği. Hiç değişiklik
/// yoksa <c>null</c>.
/// </param>
/// <remarks>
/// NEDEN `lastSyncAt` DEĞİL `lastChangeAt`?
/// Yol haritası §5'te alan adı <c>lastSyncAt</c> yazıyordu; adı değiştirdik
/// çünkü sunucu o bilgiye SAHİP DEĞİL. Sunucu yalnız "bu hesabın verisi en
/// son ne zaman değişti"yi biliyor; "bu cihaz en son ne zaman başarıyla
/// eşitledi" ise cihazın kendi bilgisi ve TR-M11-13 onun kaynağını açıkça
/// yerel <c>SyncState</c> tablosu olarak gösteriyor.
///
/// Adı <c>lastSyncAt</c> bıraksaydık istemci onu ekrana "son eşitleme" diye
/// yazardı ve kullanıcı, kendi cihazı günlerdir çevrimdışıyken bile BAŞKA
/// bir cihazın yazdığı taze bir tarih görürdü. "Yedeğim güncel" diye
/// okunacak bir yalan.
///
/// ⚠️ BEKLEYEN ÖĞE SAYISI BURADA DEĞİL (TR-M11-13'teki "bekleyen öğe"):
/// o, GÖNDERİLMEYİ bekleyen yerel outbox satırlarının sayısı ve sunucu onu
/// bilemez — henüz kendisine ulaşmamış şeylerden bahsediyoruz.
/// <see cref="PendingCount"/> bunun TERSİ: indirilmeyi bekleyenler.
/// </remarks>
public sealed record SyncStateResult(
    long ServerCursor,
    int PendingCount,
    DateTimeOffset? LastChangeAt);
