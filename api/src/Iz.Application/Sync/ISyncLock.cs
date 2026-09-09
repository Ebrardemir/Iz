namespace Iz.Application.Sync;

/// <summary>
/// Aynı kullanıcının push'larını SIRAYA SOKAR.
/// </summary>
/// <remarks>
/// NEDEN GEREKLİ — SÜRÜM KONTROLÜ TEK BAŞINA YETMİYOR.
/// Push "oku → karşılaştır → yaz" yapıyor ve bu üç adım atomik değil. Aynı
/// hesabın iki cihazı aynı anda aynı kaydı gönderirse:
///
///   A: sürüm 1'i okur      B: sürüm 1'i okur
///   A: baseVersion=1 ✓     B: baseVersion=1 ✓
///   A: sürüm 2 yazar       B: sürüm 2 yazar   ← A'nın yazdığını EZER
///
/// İkisi de <c>applied</c> alır. Kaybeden cihaz değişikliğinin sunucuda
/// olduğunu sanır; oysa hiç yok. Sürüm kontrolünün önlemek için var olduğu
/// sessiz kaybın ta kendisi, yalnız dar bir yarış penceresinde.
///
/// NEDEN İYİMSER KİLİT (<c>IsConcurrencyToken</c>) DEĞİL?
/// O da yarışı yakalardı ama <c>SaveChanges</c>'in TAMAMINI düşürürdü:
/// 200 değişikliklik bir batch, tek bir çakışan satır yüzünden komple
/// reddedilirdi. Oysa push'un en sert kuralı "bir çakışma kuyruğu
/// kilitlemez". Sıraya sokmak, ikinci push'un birincinin SONUCUNU görmesini
/// ve düzgün bir <c>conflict</c> üretmesini sağlıyor.
///
/// Ayrıca kilit, bağların "silme kazanır" birleşmesini de koruyor — orada
/// sürüm kontrolü hiç yok, dolayısıyla iyimser kilit o yolu hiç kapatmazdı.
///
/// MALİYETİ DÜŞÜK: kilit KULLANICI başına. İki farklı kullanıcının push'u
/// birbirini beklemiyor, ve tek bir kullanıcının push'ları zaten seyrek.
///
/// PULL KİLİT ALMIYOR: yalnız okuyor ve cursor semantiği eşzamanlı yazmaya
/// zaten dayanıklı.
/// </remarks>
public interface ISyncLock
{
    /// <summary>
    /// Kullanıcıyı kilitler; kilit <see cref="ISyncLockHandle"/> kapanana
    /// kadar sürer.
    /// </summary>
    Task<ISyncLockHandle> AcquireAsync(Guid userId, CancellationToken cancellationToken);
}

/// <summary>Açık kilit. Kapatılmazsa yapılan yazmalar geri alınır.</summary>
/// <remarks>
/// COMMIT ÇAĞRILMADAN <c>Dispose</c> edilirse HER ŞEY GERİ ALINIYOR. Bu,
/// "yarıda kalan push yarım veri bırakmasın" güvencesinin son halkası: bir
/// istisna işleyicinin ortasında çıksa bile yazılmış satırlar geri sarılıyor.
/// </remarks>
public interface ISyncLockHandle : IAsyncDisposable
{
    Task CommitAsync(CancellationToken cancellationToken);
}
