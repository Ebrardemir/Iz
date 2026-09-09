namespace Iz.Application.Sync;

/// <summary>
/// <c>GET /v1/sync/state</c> — "sunucuda benim için ne var?"
/// </summary>
/// <remarks>
/// SENKRONİZASYONUN ÜÇÜNCÜ UCU ve en küçüğü. Push yazıyor, pull okuyor; bu
/// uç hiçbir şey taşımıyor, yalnız DURUMU bildiriyor.
///
/// NEDEN AYRI BİR UÇ — pull zaten `hasMore` döndürmüyor mu?
/// Döndürüyor ama bedeli var: pull bir SAYFA veri indiriyor. Yedekleme
/// Sağlığı ekranını açan kullanıcı için 200 kaydı indirip atmak gereksiz;
/// üstelik ekran her açıldığında. Bu uç tek bir sayaç sorgusu.
///
/// YAN ETKİSİ YOK. Cursor'ı ilerletmiyor, cihazın "son görülme"sini
/// tazelemiyor. Durum sorgusunun durumu değiştirmesi, ekranı açmanın
/// senkronizasyonu etkilemesi demek olurdu.
/// </remarks>
public sealed class GetSyncStateHandler(ISyncStore store)
{
    public async Task<SyncStateResult> HandleAsync(
        Guid userId,
        long cursor,
        CancellationToken cancellationToken) =>
        // Negatif cursor sıfırlanıyor — pull'daki kuralın aynısı. Burada
        // bedeli daha da düşük: yalnız sayaç büyük çıkar, veri inmez.
        await store.StateAsync(userId, Math.Max(cursor, 0), cancellationToken);
}
