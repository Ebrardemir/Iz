/// Takvimin üstündeki ay gezinme satırı: ‹ AĞUSTOS 2026 ›
///
/// SAF WIDGET: hangi ayda olduğumuzu BİLMEZ, dışarıdan alır ve oklara
/// dokunulduğunu yukarı bildirir. Görünen ay ekranın durumu; takvim
/// ızgarası da aynı değere bakacak, bu yüzden tek yerde tutuluyor.
///
/// ÖLÇÜLER (Figma, 390 genişlikte çerçeve):
///   satır → 350 × 40, top 128, left 20, dolgu 8, gap 12
///   oklar → 32 × 32, satırın iki ucunda
///   ay adı→ Poppins SemiBold 20/16, Brand-Primary, ortada
///
/// ⚠️ YÜKSEKLİK 40 DEĞİL 48. Figma satırı 40 diyor ama aynı çerçevede
/// 32'lik oklar ve 8'lik dolgu var: 8 + 32 + 8 = 48. Okların boyunu
/// küçültmek yerine satırı gerçek yüksekliğine bırakıyoruz — böylece
/// dokunma hedefi de 48 oluyor (NFR-032) ve okların GÖRSEL kenarları
/// tasarımdaki 8'lik boşluğa kendiliğinden oturuyor.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/extensions/date_x.dart';
import 'package:iz/core/l10n/locale_case.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/my_life/presentation/my_life_layout.dart';
import 'package:iz/shared/widgets/iz_icon_action.dart';

class MonthNavigator extends StatelessWidget {
  const MonthNavigator({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  /// Gösterilen ay. Yalnızca yıl ve ay kullanılır.
  final DateTime month;

  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Figma: oklar 32 × 32.
  static const double kArrowSize = 32;

  /// 8 + 32 + 8 (bkz. dosya başındaki not).
  static const double kHeight = AppSpacing.minTapTarget;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MyLifeLayout.pageInset),
      child: SizedBox(
        height: kHeight,
        child: Row(
          children: [
            IzIconAction(
              icon: AppIcons.back,
              tooltip: context.l10n.myLifePreviousMonth,
              onPressed: onPrevious,
              size: kArrowSize,
              color: context.colors.primary,
            ),

            // Ay adı OKLARDAN BAĞIMSIZ ortalanıyor: `Expanded` + `Center`
            // sayesinde okların genişliği değişse bile başlık tam ortada
            // kalıyor. Aralarına sabit boşluk koysaydık, uzun ay adlarında
            // (KOLEKSİYONLAR gibi) hizası kayardı.
            Expanded(
              child: Center(
                child: Text(
                  // Ay adı ÇALIŞMA ZAMANINDA üretiliyor, çeviri dosyasından
                  // gelmiyor; bu yüzden büyük harfe dile duyarlı biçimde
                  // çeviriyoruz. `toUpperCase()` Türkçede "NİSAN" yerine
                  // "NISAN" üretirdi.
                  localeUpperCase(
                    // DİLİ AÇIKÇA GEÇİYORUZ. `AppDateFormats` boş
                    // bırakılırsa `Intl.defaultLocale` genel değişkenine
                    // düşer; o da uygulama açılışında ayarlanıyor ama
                    // widget'ı tek başına kurunca (test, önizleme)
                    // ayarlanmamış oluyor ve ay adı İngilizce çıkıyor.
                    AppDateFormats.monthYear(
                      month,
                      locale: locale.toLanguageTag(),
                    ),
                    locale,
                  ),
                  // FIGMA: Poppins SemiBold 20/16 → ölçekte `titleLarge`.
                  style: context.text.titleLarge?.copyWith(
                    color: context.colors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            IzIconAction(
              icon: AppIcons.forward,
              tooltip: context.l10n.myLifeNextMonth,
              onPressed: onNext,
              size: kArrowSize,
              color: context.colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
