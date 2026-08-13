/// Tek bir kart, içinde saç teli çizgilerle ayrılmış satırlar.
///
/// İKİ EKRAN PAYLAŞIYOR:
///   • anı formu / anı detayı → etiket–değer satırları (`MemoryInfoCard`)
///   • kişi listesi           → avatar + ad satırları
/// Görünüm ikisinde de aynı olmalı ve referans tasarımlar da öyle söylüyor.
/// Kabuğu kopyalasaydık iki kart zamanla ayrışırdı: birinde düzeltilen köşe
/// yarıçapı ötekinde eski kalırdı.
///
/// ÇİZGİLERİ KART ÇİZİYOR, satırlar değil. Her satır kendi alt çizgisini
/// taşısaydı SON satırda sahipsiz bir çizgi kalırdı.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';

class IzDividedCard extends StatelessWidget {
  const IzDividedCard({required this.rows, this.dividerInset = 0, super.key});

  final List<Widget> rows;

  /// Çizgilerin SOLDAN içeride başlama payı.
  ///
  /// Varsayılan 0 — kenardan kenara. Anı kartı böyle: kenardan kenara giden
  /// çizgi satırları eşit yükseklikte hücrelere bölüyor ve göz değerleri tek
  /// bir kolon olarak okuyor. Kişi listesinde çizgi avatarın hizasından
  /// başlıyor, çünkü orada satırın solu bir görsel ve çizginin altına girmesi
  /// avatarı kesik gösteriyor.
  final double dividerInset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: AppRadius.card,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.only(left: dividerInset),
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: colors.outlineVariant),
                ),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}
