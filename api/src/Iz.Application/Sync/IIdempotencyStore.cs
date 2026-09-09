namespace Iz.Application.Sync;

/// <summary>
/// Aynı isteğin ikinci kez işlenmesini engelleyen kısa ömürlü hafıza.
/// </summary>
/// <remarks>
/// EKSİKLİĞİNİN BEDELİ DUPLICATE DEĞİL, YANLIŞ ÇAKIŞMA.
/// Kimlikleri istemci üretiyor ve aynı gövde ikinci kez geldiğinde hiçbir
/// alan değişmiyor — yani veri zaten çoğalmıyor. Asıl sorun sürüm: yanıtı
/// alamadan yeniden denenen bir push, ilk denemede artmış sürüm yüzünden
/// <c>conflict</c> alır ve kullanıcıya KENDİ değişikliği "başka bir sürüm"
/// diye gösterilir. Kullanıcı açısından bu, olmayan bir çakışmayı çözmek
/// zorunda kalmak demek.
///
/// Bu yüzden saklanan şey işlemin kendisi değil YANITI: ikinci istek hiç
/// işlenmiyor, ilk yanıt aynen dönüyor (yol haritası §4.1).
///
/// NEDEN VERİTABANI DEĞİL REDIS?
/// Kayıtlar 24 saat sonra çöp. Postgres'te tutsaydık her push bir INSERT
/// daha yazar ve o tabloyu düzenli temizleyecek bir iş yazmamız gerekirdi.
/// TTL'i altyapının kendisinin bilmesi, unutulabilecek bir bakım işini
/// ortadan kaldırıyor.
/// </remarks>
public interface IIdempotencyStore
{
    /// <summary>
    /// Anahtar daha önce kullanıldıysa o isteğin kaydı.
    /// </summary>
    /// <remarks>
    /// <c>null</c> dönmesi "kullanılmamış" DEMEK ZORUNDA DEĞİL: depo
    /// erişilemiyorsa da <c>null</c> döner (bkz. <see cref="SaveAsync"/>
    /// notundaki bozulma kuralı).
    /// </remarks>
    Task<IdempotencyRecord?> FindAsync(
        Guid userId,
        string key,
        CancellationToken cancellationToken);

    /// <summary>
    /// Yanıtı 24 saatliğine saklar.
    /// </summary>
    /// <remarks>
    /// DEPO ERİŞİLEMEZSE İSTEK DÜŞMÜYOR. Redis'e ulaşamadığımızda push'u
    /// reddetseydik, Redis'in her hıçkırığında bütün kullanıcıların kuyruğu
    /// dururdu. Oysa idempotency'nin yokluğunda olan en kötü şey bir yanlış
    /// çakışma — veri bozulması değil. "Kuyruk kilitlenmesin" kuralı burada
    /// da daha ağır basıyor.
    /// </remarks>
    Task SaveAsync(
        Guid userId,
        string key,
        IdempotencyRecord record,
        CancellationToken cancellationToken);
}

/// <param name="RequestFingerprint">
/// İSTEĞİN parmak izi — aynı anahtarın FARKLI bir gövdeyle kullanılmasını
/// yakalıyor.
/// </param>
/// <param name="Response">İlk isteğin yanıtı, olduğu gibi.</param>
/// <remarks>
/// Parmak izi olmasaydı, anahtarı yanlışlıkla yeniden kullanan bir istemci
/// İKİNCİ batch'inin yanıtı yerine BİRİNCİSİNİNKİNİ alırdı: değişiklikleri
/// hiç işlenmez ama "applied" gördüğü için kuyruktan düşürürdü. Sessiz veri
/// kaybının en kolay kaçırılan biçimi.
/// </remarks>
public sealed record IdempotencyRecord(string RequestFingerprint, string Response);
