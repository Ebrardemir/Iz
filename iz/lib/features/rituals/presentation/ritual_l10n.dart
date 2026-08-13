/// [Ritual] → ekranda görünecek tekrar açıklaması köprüsü.
///
/// NEDEN AYRI DOSYA?
/// `category_l10n.dart` ve `failure_l10n.dart` ile aynı gerekçe: entity
/// domain katmanında yaşar ve dili bilmez. "Her yıl 3 Mart'ta" ise hem dile
/// hem de o dilin GRAMERİNE bağlı. İkisini burada, presentation katmanında
/// birleştiriyoruz.
///
/// TÜRKÇE EK SORUNU — BU DOSYA NEDEN "Mart" + "'ta" YAPMIYOR?
/// Bulunma hâli eki aya göre değişiyor: Mart'ta, Nisan'da, Eylül'de. Ünlü ve
/// ünsüz uyumuna bağlı olduğu için burada bir ek tablosu tutmak, Türkçe
/// dilbilgisini Dart koduna gömmek olurdu — üstelik yeni bir dil eklendiğinde
/// o dilin kuralı için de bir yer aramak gerekirdi. Bu yüzden 12 ayın hepsi
/// çeviri dosyasında ICU `select` dalı olarak duruyor; burası yalnızca hangi
/// dalın seçileceğini söylüyor.
///
/// FEATURE'LAR ARASI KULLANIM
/// "Hayatım" ekranı bu dosyayı import ediyor. ARCHITECTURE.md bir feature'ın
/// başka feature'ın yalnızca `domain/`ini import etmesini söylüyor; buradaki
/// istisna bilinçli ve sınırlı: bu dosya SAF BİR FONKSİYON — widget yok,
/// state yok, `Navigator` yok. Yasağın koruduğu şey (bir ekranın başka bir
/// ekranın iç yapısına bağlanması) burada yok. Aynı köprü `category_l10n.dart`
/// için de kurulmuştu (bkz. ARCHITECTURE.md, çok dillilik bölümü).
library;

import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';

/// Kuzey yarımküre mevsimleri — ay numarasından türetiliyor.
///
/// Anahtarlar ARB'deki `select` dallarıyla BİREBİR aynı olmalı; yazım hatası
/// sessizce `other` dalına düşer ve ekranda yalnızca "Her yıl" görünür.
/// (`ritual_l10n_test.dart` her mevsimi tek tek doğruluyor.)
String _seasonKeyOf(int month) => switch (month) {
  3 || 4 || 5 => 'spring',
  6 || 7 || 8 => 'summer',
  9 || 10 || 11 => 'autumn',
  _ => 'winter',
};

extension RitualL10nX on Ritual {
  /// Kartın başlığının altındaki satır: "Her yıl 3 Mart'ta".
  ///
  /// Tekrar tipine göre değişiyor:
  ///   yearly + tarih  → "Her yıl 3 Mart'ta"
  ///   seasonal + ay   → "Her yıl yaz aylarında"
  ///   monthly         → "Her ay"
  ///   weekly          → "Her hafta"
  ///   custom          → "Belirli bir tarihi yok"
  ///
  /// TARİH EKSİK OLABİLİR: `anchorMonth`/`anchorDay` domain'de nullable
  /// (kullanıcı ritüeli tarih vermeden açabilir). O durumda tipine uygun
  /// genel bir metne düşüyoruz — boş satır bırakmıyoruz.
  String recurrenceLabel(AppL10n l10n) {
    final month = anchorMonth;

    return switch (recurrenceType) {
      RecurrenceType.yearly => switch ((month, anchorDay)) {
        (final int m, final int d) => l10n.ritualEveryYearOn(m.toString(), d),
        // Yıllık ama tarihi girilmemiş: `other` dalı "Her yıl aynı tarihte".
        _ => l10n.ritualEveryYearOn('', 0),
      },

      RecurrenceType.seasonal => l10n.ritualEveryYearInSeason(
        // Ay yoksa hangi mevsim olduğunu bilemeyiz; `other` dalı devreye
        // girsin diye tanınmayan bir anahtar geçiyoruz.
        month == null ? '' : _seasonKeyOf(month),
      ),

      // Aylık ve haftalık ritüellerde TARİH YOK, yalnızca sıklık var: "her
      // ayın 3'ü" gibi bir çapa tutmuyoruz çünkü kullanıcı ritüeli tarihle
      // değil alışkanlıkla tanımlıyor (pazar kahvaltısı hep pazar, ama ayın
      // kaçı olduğu değişiyor).
      RecurrenceType.monthly => l10n.ritualEveryMonth,
      RecurrenceType.weekly => l10n.ritualEveryWeek,

      RecurrenceType.custom => l10n.ritualCustomSchedule,
    };
  }
}
