/// Uygulamanın desteklediği diller — **tek kaynak**.
///
/// NEDEN AYRI BİR DOSYA?
/// `AppL10n.supportedLocales` üretilen koddan gelir ve sadece dil *kodlarını*
/// bilir (`tr`, `en`). Ayarlar ekranında ise kullanıcıya dilin **kendi
/// dilindeki adını** göstermemiz gerekir. İkisini burada eşleştiriyoruz.
///
/// YENİ DİL EKLEME REÇETESİ:
///   1. `lib/core/l10n/arb/app_<kod>.arb` dosyasını oluştur (app_tr.arb'yi
///      kopyalayıp çevir — anahtarların HEPSİ bulunmalı).
///   2. Aşağıdaki [AppLanguages.all] listesine bir satır ekle.
///   3. `flutter gen-l10n` çalıştır.
///   4. `flutter test` — `l10n_test.dart` eksik anahtar varsa seni uyarır.
library;

/// Bir dilin kodu ve kendi dilindeki adı.
typedef AppLanguage = ({String code, String nativeName});

abstract final class AppLanguages {
  /// DİKKAT: `nativeName` ÇEVRİLMEZ ve çevrilmemelidir.
  /// Bir dil her zaman kendi adıyla listelenir; İngilizce arayüzde "Turkish"
  /// yazsaydı Türkçe bilen bir kullanıcı kendi dilini bulamazdı. Bu yüzden
  /// bu metinler arb dosyalarında DEĞİL, burada duruyor.
  static const List<AppLanguage> all = [
    (code: 'tr', nativeName: 'Türkçe'),
    (code: 'en', nativeName: 'English'),
  ];

  // NOT: Burada ayrıca bir `codes = ['tr', 'en']` listesi vardı. Hiçbir yerden
  // okunmuyordu ve [all]'un ikinci bir kopyasıydı: yeni dil eklerken ikisini
  // birden güncellemek gerekiyordu, oysa yukarıdaki reçete tek listeden
  // söz ediyor. Kod listesi gerekirse türet: `all.map((l) => l.code)`.
}
