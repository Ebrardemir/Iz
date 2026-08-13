/// Serinin özeti: kaç yıl, kaç anı, kaç şehir.
///
/// NEDEN AYRI VE SAF BİR FONKSİYON?
/// Referanstaki üç kutu ("4 yıl Birlikte", "12 anı Toplam", "4 şehir
/// Keşfedildi") kullanıcının GİRDİĞİ değerler değil, anılardan TÜRETİLEN
/// sayılar — seri formunda tarih sormamamızla aynı fikir. Türetme kuralı bir
/// widget'ın içinde yaşarsa test etmek için ekran kurmak gerekiyor; burada üç
/// satırlık bir liste ile sınanıyor.
///
/// `domain/` içinde çünkü Flutter'a ihtiyacı yok: girdisi de çıktısı da sade
/// Dart. Aynı sayılar ileride ana sayfadaki sayaçlarda da lazım olabilir.
library;

/// Özetin girdisi — yalnızca ihtiyaç duyulan iki alan.
///
/// Ekranın kendi kaydını (`RitualDetailMemory`) beklemiyoruz: bu fonksiyonun
/// bir başlığı, kapağı ya da tarih metnini bilmesine gerek yok ve bilmemesi
/// onu önizleme verisinden bağımsız tutuyor.
typedef RitualStatInput = ({int year, String? placeLabel});

/// Üç kutunun sayıları.
typedef RitualStats = ({int yearCount, int memoryCount, int cityCount});

/// [memories] listesinden özeti çıkarır.
///
/// YIL ve ŞEHİR **BENZERSİZ** sayılıyor: aynı yaz iki anı eklenmişse bu "2
/// yıl" değil; iki yıl üst üste Çeşme'ye gidilmişse "2 şehir" değil. Kutunun
/// altındaki "Birlikte" ve "Keşfedildi" sözcükleri bunu vaat ediyor.
///
/// KONUMU OLMAYAN anılar şehir sayısına girmiyor: konum opsiyonel (rapor 20.1)
/// ve boş bırakılmış bir alan bir şehir değil.
RitualStats ritualStats(Iterable<RitualStatInput> memories) {
  final years = <int>{};
  final cities = <String>{};
  var count = 0;

  for (final memory in memories) {
    count++;
    years.add(memory.year);

    final place = memory.placeLabel?.trim();
    if (place != null && place.isNotEmpty) cities.add(place);
  }

  return (
    yearCount: years.length,
    memoryCount: count,
    cityCount: cities.length,
  );
}
