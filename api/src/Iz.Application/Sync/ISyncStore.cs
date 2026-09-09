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

    /// <summary>
    /// Aynı türden çok sayıda kaydı TEK sorguda getirir.
    /// Anahtar: <see cref="SyncEntityKey.Value"/>.
    /// </summary>
    /// <remarks>
    /// NEDEN AYRI BİR METOT VAR — <see cref="FindAsync"/> döngüde çağrılamaz mı?
    /// Çağrılır, ve pull'da 200'lük bir sayfa 200 gidiş-dönüş eder. Yeni bir
    /// cihazın bootstrap'ı (yol haritası §4.3) binlerce kaydı sayfa sayfa
    /// indiriyor; orada bu fark saniyeler değil dakikalar demek.
    ///
    /// Push tek tek arıyor ve doğrusu o: orada kayıtlar sırayla işleniyor ve
    /// her biri bir öncekinin sonucuna bakabiliyor (aynı batch'te iki kez
    /// gelen kayıt). Pull'da böyle bir bağımlılık yok — hepsi birden okunabilir.
    /// </remarks>
    Task<IReadOnlyDictionary<string, ISyncable>> FindManyAsync(
        SyncEntityMapper mapper,
        IReadOnlyCollection<SyncEntityKey> keys,
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
    /// Günlüğün özeti: baş, <paramref name="cursor"/>'dan sonra bekleyen
    /// sayısı ve son değişiklik zamanı.
    /// </summary>
    /// <remarks>
    /// ÜÇ DEĞER TEK SORGUDA. Ayrı ayrı sorsaydık aralarında bir yazma
    /// olabilir ve yanıt kendi içinde tutarsız çıkardı: baş ilerlemiş ama
    /// sayaç eski, ya da tersi. Yedekleme Sağlığı ekranı o tutarsızlığı
    /// "2 değişiklik bekliyor" derken cursor'ın zaten geçmiş olması gibi
    /// anlaşılmaz bir hâlde gösterirdi.
    /// </remarks>
    Task<SyncStateResult> StateAsync(
        Guid userId,
        long cursor,
        CancellationToken cancellationToken);

    /// <summary>
    /// <paramref name="cursor"/>'dan sonraki günlük satırları, <c>seq</c>
    /// sırasıyla.
    /// </summary>
    /// <param name="limit">
    /// <c>null</c> ise SINIRSIZ.
    /// </param>
    /// <remarks>
    /// İKİ ÇAĞIRANI VAR ve sınır ihtiyaçları zıt:
    ///
    /// • Pull sayfalıyor — sınır onun sözleşmesinin parçası.
    /// • Push, KAYDETTİKTEN SONRA yazdığı satırların hangi <c>seq</c>'i
    ///   aldığını öğrenmek için çağırıyor (sırayı veritabanı üretiyor) ve
    ///   SINIR KOYAMAZ: 200 değişiklik, bağlarıyla birlikte 1.000'den fazla
    ///   günlük satırı üretebilir. Sınırlasaydık sayfanın dışında kalan
    ///   satırların <c>seq</c>'i yanıtta boş dönerdi — istemci onları
    ///   "yazılmadı" sanmazdı ama kuyruktan da düşüremezdi.
    /// </remarks>
    Task<IReadOnlyList<ChangeLogEntry>> ChangesAfterAsync(
        Guid userId,
        long cursor,
        int? limit,
        CancellationToken cancellationToken);
}
