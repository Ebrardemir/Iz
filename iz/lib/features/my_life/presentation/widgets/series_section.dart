/// SERİLERİM sekmesinin gövdesi: seri kartlarının listesi.
///
/// KOLEKSİYONLARDAN FARKI — BURADA KATLAMA YOK.
/// Koleksiyon kartları akordeon: içleri uzun bir anı listesi olduğu için
/// aynı anda tek kart açık kalıyor. Seri kartı ise ZATEN özet: dört yıl
/// yan yana ve gerisi yatay kayıyor. Katlanacak bir şey yok, hepsi açık.
///
/// `StatelessWidget` olması bunun sonucu — bir durum tutmuyor.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/my_life/presentation/my_life_layout.dart';
import 'package:iz/features/my_life/presentation/widgets/series_card.dart';
import 'package:iz/shared/widgets/app_empty_state.dart';

class SeriesSection extends StatelessWidget {
  const SeriesSection({
    required this.series,
    required this.onOpenSeries,
    required this.onOpenYear,
    super.key,
  });

  /// Boş liste → boş durum çizilir (NFR-035).
  final List<SeriesCardData> series;

  final ValueChanged<SeriesCardData> onOpenSeries;
  final ValueChanged<SeriesYearData> onOpenYear;

  /// Kartlar arası boşluk — koleksiyon listesiyle aynı ritim.
  static const double kCardGap = 12;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      final l10n = context.l10n;
      return AppEmptyState(
        icon: AppIcons.series,
        title: l10n.seriesEmptyTitle,
        message: l10n.seriesEmptyMessage,
      );
    }

    return Padding(
      // Tasarım bu bloğu 24'ten başlatıyor ama ekrandaki her şey (sekme
      // çubuğu, koleksiyon kartları) 20'de. Aynı uzlaşmayı burada da
      // yapıyoruz — bkz. `collections_section.dart`.
      padding: const EdgeInsets.symmetric(horizontal: MyLifeLayout.pageInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in series) ...[
            if (item != series.first) const SizedBox(height: kCardGap),
            SeriesCard(
              // `ValueKey` ŞART: kartların içinde kendi `ScrollController`ı
              // olan yatay şeritler var. Anahtar olmadan liste sıralanınca
              // Flutter durumu konuma göre eşler ve bir serinin kaydırma
              // konumu başka bir seride görünür.
              key: ValueKey(item.id),
              series: item,
              onOpen: () => onOpenSeries(item),
              onOpenYear: onOpenYear,
            ),
          ],

          // Listenin dibinde nefes payı: son kart alt çubuğa yapışmasın.
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
