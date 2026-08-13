/// Takvimin gün başlığı satırı: PZT SAL ÇAR PER CUM CMT PAZ
///
/// SAF WIDGET: veri almaz. Gün adlarını cihazın dilinden üretir.
///
/// ÖLÇÜLER (Figma, 390 genişlikte çerçeve):
///   satır → 342 × 24, top 180, left 28, space-between
///   etiket→ 24 × 20, Poppins Regular 14/20, Text-Secondary
///
/// ⚠️ HİZAYI TASARIMDAN FARKLI KURDUK — BİLEREK.
///
/// Figma başlık satırını `left: 28, width: 342` ile, gün sayılarını ise
/// başka bir dağılımla veriyor. Referans ekran görüntüsünde ikisinin
/// sütun merkezleri tutmuyor: başlıkların adımı ~52, sayılarınki ~48.
/// Yani "PZT" ile altındaki "27" birbirinden kayıyor.
///
/// Takvimde bu hata gibi okunur. Bu yüzden başlıklar ve günler TEK ızgarayı
/// paylaşıyor: sayfanın standart kenar boşluğundan (20) yedi eşit sütun.
/// İlk sütunun merkezi 45 çıkıyor — referansta ölçülen ilk gün sayısının
/// merkeziyle birebir aynı.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/l10n/locale_case.dart';
import 'package:iz/features/my_life/presentation/my_life_layout.dart';

class CalendarWeekHeader extends StatelessWidget {
  const CalendarWeekHeader({super.key});

  /// Figma: satır 24 yüksekliğinde.
  static const double kHeight = 24;

  /// Haftanın günlerini, haftanın ilk gününden başlayarak kısaltılmış ve
  /// BÜYÜK harfle döndürür.
  ///
  /// Adlar `intl`den geliyor, elle yazılmıyor: Türkçede "Pzt/Sal/Çar",
  /// İngilizcede "Mon/Tue/Wed" — çeviri dosyasına yedi anahtar eklemeye
  /// gerek yok, üstelik yeni bir dil eklendiğinde kendiliğinden doğru olur.
  ///
  /// Büyük harf çevirimi DİLE DUYARLI: `toUpperCase()` Türkçede "Cmt"yi
  /// doğru çevirir ama "Pzt"deki gibi noktalı `i` içeren adlarda (örneğin
  /// bazı dillerde) bozardı — kuralı tek yerde tutuyoruz.
  static List<String> labelsFor(Locale locale) {
    final tag = locale.toLanguageTag();
    final format = DateFormat.E(tag);

    return [
      for (var i = 0; i < MyLifeLayout.weekdayCount; i++)
        localeUpperCase(
          // 2024-01-01 bir PAZARTESİ. Haftanın ilk gününden başlayıp
          // yedi gün ilerliyoruz; hangi tarih olduğu önemsiz, yalnızca
          // gün adı okunuyor.
          format.format(DateTime(2024, 1, MyLifeLayout.firstWeekday + i)),
          locale,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final labels = labelsFor(locale);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MyLifeLayout.pageInset),
      child: SizedBox(
        height: kHeight,
        child: Row(
          children: [
            for (final label in labels)
              // YEDİ EŞİT SÜTUN. Takvim ızgarası da aynı bölmeyi kullanacak;
              // `Expanded` sayesinde hizanın bozulması imkânsız.
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    // FIGMA: Poppins Regular 14/20 → `bodyMedium`.
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
