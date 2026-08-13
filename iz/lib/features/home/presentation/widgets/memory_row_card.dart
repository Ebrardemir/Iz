/// "SON ANILAR" listesindeki tek satır: solda küçük resim, ortada başlık ve
/// tarih, sağda ok.
///
/// SAF WIDGET: veri almaz, verilen [MemoryRowData]'yı çizer ve dokunmayı
/// yukarı bildirir.
///
/// ÖLÇÜLER (Figma, 390 genişlikte çerçeve):
///   kart       → 350 × 68, padding (2, 8, 2, 8), resim–yazı arası 12
///   küçük resim→ 64 × 64, köşe 12, gölge 0 4 12 −1 #0000000A
///   sağ kutu   → 262 × 60, ALT KENARLIK 1px #E8E3D9
///   başlık     → Poppins Regular 16/24, Text-Primary
///   tarih      → Poppins Regular 12/16, Text-Secondary
///   ok         → chevron-right, 28
///
/// ALT ÇİZGİ NEDEN TAM GENİŞLİKTE DEĞİL? Kenarlık kartın değil, SAĞ
/// KUTUNUN altında. Referansta da çizgi küçük resmin hizasından başlıyor;
/// böylece resimler bir sütun gibi okunuyor ve liste hafifliyor.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';

/// Listede gösterilecek anı. [dateLabel] hazır METİN olarak geliyor:
/// "3 gün önce" hesabı bir sunum kararıdır ve ViewModel'e aittir.
///
/// [id] KİMLİK: satıra dokunmak anı detayını açıyor ve detay ekranı kimlik
/// istiyor. Widget'ın kendisi kimliği kullanmıyor — dokunuşu yukarı iletiyor,
/// nereye gidileceğine ekran karar veriyor.
typedef MemoryRowData = ({
  String id,
  String imageAsset,
  String title,
  String dateLabel,
});

class MemoryRowCard extends StatelessWidget {
  const MemoryRowCard({
    required this.memory,
    required this.onTap,
    this.showDivider = true,
    super.key,
  });

  final MemoryRowData memory;
  final VoidCallback onTap;

  /// Listenin SON satırında alt çizgi olmaz; yoksa liste "yarım kalmış"
  /// gibi durur.
  final bool showDivider;

  /// Figma: kart yüksekliği 68 = 2 + 64 + 2.
  static const double kHeight = 68;

  /// Figma: küçük resim 64 × 64, köşe yarıçapı 12.
  static const double kThumbSize = 64;
  static const Radius _kThumbRadius = AppRadius.md;

  /// Figma: kart padding (2, 8, 2, 8).
  static const double _kPaddingHorizontal = AppSpacing.sm;
  static const double _kPaddingVertical = 2;

  /// Figma: resimle yazı arası 12.
  static const double _kThumbGap = 12;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: kHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _kPaddingHorizontal,
            vertical: _kPaddingVertical,
          ),
          child: Row(
            children: [
              _Thumbnail(asset: memory.imageAsset),
              const SizedBox(width: _kThumbGap),

              // Alt çizgi BU kutunun altında — kartın değil.
              //
              // Figma sağ kutuyu 60 veriyor; kartın 64'lük iç alanına 2'şer
              // pay bırakıyoruz. Kutuyu 64 bıraksaydık başlıkla tarih arası
              // 20 yerine 24 olurdu ve çizgi kartın dibine yapışırdı.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: showDivider
                              ? colors.outlineVariant
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            // Figma: kutu 60, başlık 24, tarih 16 → ikisi
                            // uçlara yaslanıyor, arada ~20 nefes kalıyor.
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                memory.title,
                                // FIGMA: Poppins Regular 16/24 → `bodyLarge`.
                                style: context.text.bodyLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                memory.dateLabel,
                                // FIGMA: Poppins Regular 12/16 → `caption`.
                                style: context.textStyles.caption.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          AppIcons.forward,
                          size: AppIconSize.lg,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Anının kapak fotoğrafı.
///
/// ⚠️ Şimdilik asset. Veri bağlandığında burası `Memory.coverMedia`den
/// gelecek ve `Image.asset` yerine ağ/dosya kaynağı kullanılacak —
/// değişecek tek yer bu widget.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.asset});

  final String asset;

  /// Figma: 0px 4px 12px -1px #0000000A. Çok hafif; resmi zeminden
  /// ayırmaya yetiyor, gölge gibi görünmüyor.
  static const List<BoxShadow> _shadow = [
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: -1,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(MemoryRowCard._kThumbRadius),
        boxShadow: _shadow,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(MemoryRowCard._kThumbRadius),
        child: Image.asset(
          asset,
          width: MemoryRowCard.kThumbSize,
          height: MemoryRowCard.kThumbSize,
          fit: BoxFit.cover,
          // Kapak bulunamazsa satır çökmesin, boş bir alan kalsın.
          errorBuilder: (context, error, stack) => ColoredBox(
            color: context.colors.surfaceContainerHigh,
            child: const SizedBox.square(
              dimension: MemoryRowCard.kThumbSize,
              child: Icon(AppIcons.photo, size: AppIconSize.md),
            ),
          ),
        ),
      ),
    );
  }
}
