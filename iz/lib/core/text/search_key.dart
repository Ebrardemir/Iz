/// Karşılaştırma (arama, eşleştirme) için metni sadeleştirir.
///
/// NEDEN AYRI DOSYA, NEDEN `core/l10n/locale_case.dart` DEĞİL?
/// O dosya `dart:ui`den `Locale` import ediyor; bu fonksiyon ise SAF DART ve
/// domain katmanından da çağrılıyor (bkz. `relation_guess.dart`). Domain'in
/// kuralı "Flutter'a bağımlı olmayacak" — bu yüzden kural burada, bağımsız
/// duruyor. `localeUpperCase` ile aynı sorunun öteki yarısı.
library;

/// [text]'i küçük harfe çevirir — TÜRKÇEYİ doğru sayarak.
///
/// Dart'ın `toLowerCase()`i Türkçeyi bilmiyor: noktasız büyük `I`'yı noktalı
/// küçük `i`'ye çeviriyor.
///   "IRMAK".toLowerCase() → "irmak"   ("ırmak" olmalıydı)
/// Sonuç: "ırmak" arayan kullanıcı "Irmak"ı bulamıyor. Küçültmeden ÖNCE iki
/// harfi kendi küçük karşılıklarına elle çeviriyoruz.
///
/// DİL PARAMETRESİ ALMIYOR: dönüşüm Türkçe için doğru, öteki dillerde
/// zararsız. "İ" ya da "I" geçmeyen metin hiç değişmiyor; geçen bir metinde de
/// aranan şey aynı dönüşümden geçtiği için iki taraf tutuyor.
String localeSearchKey(String text) =>
    text.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().trim();
