/// Dile duyarlı büyük harf çevirimi.
///
/// SORUN: Dart'ın `String.toUpperCase()` metodu dili BİLMEZ. Türkçede iki
/// ayrı `i` harfi vardır ve büyük karşılıkları çaprazdır:
///   i → İ   (noktalı)
///   ı → I   (noktasız)
/// Dart ikisini de İngilizce kurala göre çevirir: `i → I`, `ı → I`. Sonuç
/// "NİSAN" yerine "NISAN", "İZMİR" yerine "IZMIR" olur — Türkçe okuyan
/// için apaçık yanlış.
///
/// SABİT METİNLERDE gerek yok: onları çeviri dosyasına doğrudan büyük
/// harfle yazıyoruz ("BUGÜNÜN İZİ", "HAYATIM"). Bu yardımcı, metnin
/// ÇALIŞMA ZAMANINDA üretildiği yerler için: ay adı, kullanıcı başlığı,
/// kategori adı gibi.
library;

import 'dart:ui' show Locale;

/// [text]'i [locale]'e göre büyük harfe çevirir.
///
/// Türkçede önce iki `i` harfini doğru büyük karşılıklarıyla değiştiriyor,
/// sonra kalanı standart çevirime bırakıyoruz. Öteki dillerde davranış
/// değişmiyor.
String localeUpperCase(String text, Locale locale) {
  if (locale.languageCode != 'tr') return text.toUpperCase();

  return text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}
