/// Kavisin altındaki 2×2 sayaç ızgarası: GÜNLÜK / KİŞİLER / SERİLER /
/// KOLEKSİYONLAR.
///
/// SAF WIDGET: veri almaz, verilen [HomeStat] listesini çizer. Sayıların
/// nereden geleceğine (yerel veritabanı mı, servis mi) henüz karar
/// verilmedi; ekran o karardan bağımsız kalsın diye değerler dışarıdan
/// geliyor.
///
/// ÖLÇÜLER (Figma, 390 genişlikte çerçeve):
///   ızgara → left 20, width 350, height 168 (iki satır × 84)
///   hücre  → padding (12, 16, 12, 20), ikon 32, ikon–yazı arası 16
///   yazı   → etiket 12/16 Medium, sayı 20/24 Medium, birim 12/16 Regular
///
/// Referans ekran görüntüsünden doğrulandı: dikey ayırıcı tam ortada
/// (x = 194 ≈ 20 + 350/2), metin sütunu x = 89 ≈ 20 + 20 + 32 + 16.
///
/// ⚠️ Figma'da hücre genişliği 179 yazıyor ama 2 × 179 = 358 > 350; sabit
/// genişlik yerine iki eşit sütun kullanıyoruz (ölçümde ayırıcı tam ortada
/// çıkıyor). Böylece her ekran genişliğinde de doğru çalışıyor.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/home/presentation/home_layout.dart';

/// Tek bir sayaç. [value] biçimlenmiş METİN olarak geliyor: binlik ayıracı
/// dile göre değişir ("1.234" / "1,234") ve bu bir sunum kararıdır.
///
/// [onTap] sayaç bir BÖLÜME açılıyorsa verilir; ızgara o zaman hücreyi
/// dokunulabilir yapıyor. Widget nereye gidileceğini bilmiyor — sayaç bir
/// özet ve özetin arkasında hangi ekranın durduğuna ekran karar veriyor.
typedef HomeStat = ({
  IconData icon,
  String label,
  String value,
  String unit,
  VoidCallback? onTap,
});

class HomeStatsGrid extends StatelessWidget {
  const HomeStatsGrid({required this.stats, super.key});

  /// Dört sayaç: sırayla sol üst, sağ üst, sol alt, sağ alt.
  final List<HomeStat> stats;

  @override
  Widget build(BuildContext context) {
    assert(stats.length == 4, 'Izgara 2×2: tam dört sayaç bekleniyor.');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HomeLayout.pageInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatRow(left: stats[0], right: stats[1]),

          // Satırları ayıran ince çizgi. Referans ölçümünde ızgaranın sol
          // ve sağ kenarına kadar gidiyor (19..369 ≈ 20..370), içeride
          // durmuyor.
          Divider(
            height: 1,
            thickness: 1,
            color: context.colors.outlineVariant,
          ),

          _StatRow(left: stats[2], right: stats[3]),
        ],
      ),
    );
  }
}

/// İki hücre + aralarındaki dikey ayırıcı.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.left, required this.right});

  final HomeStat left;
  final HomeStat right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      // `IntrinsicHeight` OLMADAN dikey ayırıcı çizilmez: `VerticalDivider`
      // yüksekliğini sınırsız bir alanda hesaplayamaz. Satırda yalnızca iki
      // hücre olduğu için maliyeti önemsiz.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // İki EŞİT sütun: Figma'nın 179'u 350'ye sığmıyor, ölçümde ayırıcı
          // tam ortada. `Expanded` her ekran genişliğinde bunu korur.
          Expanded(child: _StatCell(stat: left)),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: context.colors.outlineVariant,
          ),
          Expanded(child: _StatCell(stat: right)),
        ],
      ),
    );
  }
}

/// Solda ikon, sağda üç satır yazı.
class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat});

  final HomeStat stat;

  /// Hücre dokunulabilir mi?
  ///
  /// Dört sayacın hepsi bir bölümü özetliyor ve hepsi o bölüme açılıyor; ama
  /// hedefi olmayan bir sayaç gelirse (yeni bir sayaç eklenip ekranı henüz
  /// yazılmadıysa) hücre sessizce dokunulamaz kalıyor — dokunulup hiçbir şey
  /// olmayan bir hücreden iyi.
  bool get _isTappable => stat.onTap != null;

  /// Figma: padding (12, 16, 12, 20).
  ///
  /// SAĞ DOLGU 16 DEĞİL 8. En uzun etiket ("KOLEKSİYONLAR") bizim
  /// çizimimizde 93 px; Figma'nın bıraktığı 95'lik kutuya referansta 89 px
  /// olarak sığıyor ama bizde kırpılıyordu. Sağda hizalanan bir şey
  /// olmadığı için dolguyu kısmak gözle fark edilmiyor, etiket ise tam
  /// görünüyor. Alternatifi etiketi küçültmekti — okunurluğu bozardı.
  static const double kPaddingRight = AppSpacing.sm;
  static const double _kPaddingLeft = 20;
  static const double _kPaddingVertical = 12;

  /// Figma: ikon 32×32, yazıyla arası 16.
  static const double _kIconSize = 32;
  static const double _kIconGap = AppSpacing.md;

  /// Yazı satırları arası.
  ///
  /// Figma kutuyu 62 yüksekliğinde veriyor; satırlar 16 + 24 + 16 = 56
  /// ettiğine göre iki boşluğa toplam 6 kalıyor.
  static const double _kLineGap = 3;

  @override
  Widget build(BuildContext context) {
    final content = _content(context);
    if (!_isTappable) return content;

    return Semantics(
      button: true,
      // Ekran okuyucu "GÜNLÜK 128 kayıt" duyuyor; ayrıca düğme olduğunu da
      // bilmesi gerekiyor (NFR-032).
      child: InkWell(onTap: stat.onTap, child: content),
    );
  }

  Widget _content(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kPaddingLeft,
        _kPaddingVertical,
        kPaddingRight,
        _kPaddingVertical,
      ),
      child: Row(
        children: [
          Icon(
            stat.icon,
            size: _kIconSize,
            // Altın vurgu rengi — tasarımdaki `Brand/Accent`.
            color: context.colors.tertiary,
          ),
          const SizedBox(width: _kIconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stat.label,
                  // FIGMA: Poppins Medium 12/16 → `labelMedium`.
                  style: context.text.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: _kLineGap),
                Text(
                  stat.value,
                  // FIGMA: Poppins Medium 20/24 → ölçekteki `statValue`.
                  style: context.textStyles.statValue,
                  maxLines: 1,
                ),
                const SizedBox(height: _kLineGap),
                Text(
                  stat.unit,
                  // FIGMA: Poppins Regular 12/16 → ölçekteki `caption`.
                  // Birim sayının destekçisi, o yüzden bir ton geride.
                  style: context.textStyles.caption.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
