using Iz.Domain.Sync;

namespace Iz.Application.Sync;

/// <summary>
/// Senkronize edilen satırlara ve değişiklik günlüğüne erişim.
/// </summary>
/// <remarks>
/// NEDEN TEK BİR ARAYÜZ, VARLIK BAŞINA REPOSITORY DEĞİL?
/// On dört tür için on dört repository, on dört kayıt satırı ve on dört
/// benzer sınıf demekti — hepsi de aynı üç işi yapan. Push her türe AYNI
/// şekilde davranıyor (bul, yaz, sürümü artır); ayrımı yapan tek şey
/// <see cref="SyncEntityMapper"/>, o da zaten var.
///
/// SAHİPLİK SÜZGECİ ALTYAPIDA. Buradaki hiçbir metot <c>userId</c>
/// almıyor çünkü EF'in global sorgu süzgeci onu istekten okuyor (§7.2).
/// İkinci bir <c>userId</c> parametresi eklemek, çağıranın yanlış kullanıcıyı
/// geçirebilmesi demekti — yani IDOR'un tam da kapatmak istediğimiz biçimi.
/// Tek istisna <see cref="ChangesAfterAsync"/>: <c>change_log</c>'un süzgeci
/// yok (bkz. <c>ChangeLogEntryConfiguration</c>) ve kapsamı çağıran yazıyor.
/// </remarks>
public interface ISyncStore
{
    /// <summary>
    /// Kaydı bulur — TOMBSTONE'LANMIŞ OLSA BİLE.
    /// </summary>
    /// <remarks>
    /// Silinmiş satırı gizleseydik push onu "yok" sanır, YENİSİNİ açardı ve
    /// kullanıcının sildiği kayıt geri gelirdi.
    /// </remarks>
    Task<ISyncable?> FindAsync(
        SyncEntityMapper mapper,
        SyncEntityKey key,
        CancellationToken cancellationToken);

    void Add(ISyncable entity);

    /// <summary>
    /// Bu kaydın gerçekten DEĞİŞİP değişmediği.
    /// </summary>
    /// <remarks>
    /// Sürümü ve <c>updatedAt</c>'i yalnız gerçekten değişen kayıtta
    /// artırıyoruz. Yoksa: istemci bir anıyı her kaydettiğinde onun TÜM
    /// bağlarını yeniden gönderiyor (gövde bağları da taşıyor), ve her
    /// gönderim değişmemiş bağlara da birer günlük satırı düşürürdü.
    /// Kullanıcı tek bir başlığı düzeltir, ikinci cihaz on beş satır çekerdi.
    /// </remarks>
    bool IsModified(ISyncable entity);

    /// <summary>Kullanıcının günlüğündeki en yüksek sıra; hiç yoksa 0.</summary>
    Task<long> CurrentCursorAsync(Guid userId, CancellationToken cancellationToken);

    /// <summary>
    /// <paramref name="cursor"/>'dan sonraki günlük satırları.
    /// </summary>
    /// <remarks>
    /// Push bunu KAYDETTİKTEN SONRA çağırıyor: yazdığı satırların hangi
    /// <c>seq</c>'i aldığını başka türlü bilemez — sırayı veritabanı
    /// üretiyor (<c>bigserial</c>). Aynı sorgu Faz 3'ün ikinci adımında
    /// <c>/v1/sync/pull</c>'un da tek sorgusu olacak.
    /// </remarks>
    Task<IReadOnlyList<ChangeLogEntry>> ChangesAfterAsync(
        Guid userId,
        long cursor,
        CancellationToken cancellationToken);
}
