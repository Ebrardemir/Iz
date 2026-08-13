/// Günlük formundaki davet cümlesini SEÇEN kural — FR-032, FR-036.
///
/// Karşılama kartında tek bir sabit cümle vardı ve her açılışta aynı şeyi
/// söylüyordu; ikinci günde görünmez oluyor, üçüncüde sıkıyor. Küçük bir
/// cümle havuzu (`journalPrompts`) ve GÜNE göre değişen bir seçim, kullanıcıyı
/// her gün başka bir kapıdan yazmaya çağırıyor.
///
/// NEDEN RASTGELE DEĞİL, GÜNE BAĞLI?
///   • Aynı gün içinde ekranı iki kez açan kullanıcı aynı cümleyi görmeli;
///     her `build`te değişen bir metin ekranı huzursuz yapıyordu.
///   • Rastgelelik test edilemez: `Math.random` ile yazılan bir seçim
///     "hangi cümle çıkacak" diye sorulamayan bir koda dönüşüyor.
///
/// SAF FONKSİYON, `domain/` içinde: girdisi bir tarih, çıktısı bir sayı.
/// Cümlelerin KENDİSİ burada değil çeviride (`presentation/journal_prompts.dart`)
/// — bu dosya hangi cümle olduğunu bilmiyor, kaçıncı olduğunu söylüyor.
library;

/// [date] gününde gösterilecek cümlenin sırası (0..count-1).
///
/// Sayaç GÜN BAZLI: aynı günün her saatinde aynı sonucu veriyor çünkü hesap
/// yalnızca yıl/ay/gün üzerinden yürüyor.
///
/// [count] sıfır ya da negatifse 0 dönüyor — çağıran taraf boş bir listeyle
/// gelirse çökmek yerine ilk elemanı istemiş sayılıyor (liste boşsa zaten
/// kart çizilmiyor).
int journalPromptIndexFor(DateTime date, {required int count}) {
  if (count <= 0) return 0;

  // Sabit bir başlangıçtan geçen GÜN sayısı: ay uzunlukları ve artık yıllar
  // kendiliğinden çözülüyor. "Yılın kaçıncı günü" ile hesaplasaydık 31 Aralık
  // ile 1 Ocak arasında sıçrama olurdu (365 % 5 = 0 değil).
  final days = DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime(2000)).inDays;

  // Negatif tarihlerde de (2000 öncesi) geçerli bir sıra üretiyoruz:
  // Dart'ta `-3 % 5` zaten 2 döner, ama niyeti açık bırakmak için yazıyoruz.
  return days.remainder(count).abs();
}
