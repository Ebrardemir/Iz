/// Kapak alanı: içinde çizim (ya da seçilen fotoğraf), sağ altta yeşil "+"
/// düğmesi, altında "Kapak Görseli Ekle".
///
/// PAYLAŞILAN: seri ve koleksiyon formlarının ikisi de aynı kapak kutusunu
/// kullanıyor — iki kopya iki ayrı görünüm demekti.
///
/// TÜM ALAN TIKLANABİLİR, yalnızca "+" değil.
/// Referansta göz "+" düğmesine gidiyor ama parmak koca kutuya gidiyor.
/// İkisini ayırmak, dokunup hiçbir şey olmadığını gören bir kullanıcı üretir
/// (kişi formunda "Fotoğraf Ekle" yazısı tıklanamıyordu ve testte yakaladık).
///
/// FOTOĞRAF SEÇİLDİĞİNDE çizim gidiyor, kutu aynı yerde ve aynı ölçüde
/// kalıyor: kapak değişince altındaki bütün form aşağı kaysaydı kullanıcı
/// yerini kaybederdi. Metin de "Kapak Görselini Değiştir"e dönüyor — aynı
/// düğmenin işi artık farklı.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/shared/widgets/iz_cover_illustration.dart';
import 'package:iz/shared/widgets/media_thumbnail.dart';

class IzCoverPicker extends StatelessWidget {
  const IzCoverPicker({required this.cover, required this.onPick, super.key});

  /// Seçilen kapak; null ise çizim görünüyor.
  final MediaItem? cover;

  final VoidCallback onPick;

  /// Kutunun en-boy oranı.
  ///
  /// Referansta kutunun TAMAMI 380×247; içindeki görsel alan ~380×200, altındaki
  /// yazı ~47. Oran görsel alana ait olduğu için 1.9 (1.54 kutunun tamamıydı ve
  /// kapak gereğinden uzun çıkıyordu).
  ///
  /// Oran veriyoruz, sabit yükseklik değil: kutu ekranın kenarlarına kadar
  /// uzanıyor ve dar telefonda sabit yükseklik onu tuhaf biçimde uzatırdı.
  static const double kAspectRatio = 1.9;

  /// Yeşil dairenin çapı — referansta ~44, NFR-033'ün de üstünde.
  static const double kAddButtonSize = 44;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final coverMedia = cover;

    return Semantics(
      button: true,
      label: coverMedia == null ? l10n.coverAdd : l10n.coverChange,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPick,
        borderRadius: const BorderRadius.all(AppRadius.xl),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Sayfa zemininden bir ton koyu: kutu bir ALAN olduğunu
            // söylemeli, yoksa yazı boşlukta duruyor.
            color: colors.surfaceContainerHigh,
            borderRadius: const BorderRadius.all(AppRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: kAspectRatio,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(AppRadius.lg),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (coverMedia == null)
                          const IzCoverIllustration()
                        else
                          MediaThumbnail(
                            media: coverMedia,
                            // Köşeyi ClipRRect veriyor: iki kez yuvarlatmak
                            // kenarda tırtık bırakıyor.
                            borderRadius: Radius.zero,
                          ),

                        // "+" düğmesi SAĞ ALTTA ve fotoğrafın üstünde:
                        // seçildikten sonra da değiştirme yolu görünür kalıyor.
                        Positioned(
                          right: AppSpacing.md,
                          bottom: AppSpacing.md,
                          child: _AddButton(onTap: onPick),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                Text(
                  coverMedia == null ? l10n.coverAdd : l10n.coverChange,
                  style: context.text.titleSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kapağın köşesindeki yeşil daire.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox.square(
      dimension: IzCoverPicker.kAddButtonSize,
      child: Material(
        // Dolu MARKA rengi: sayfadaki tek renkli daire ve gözün ilk gittiği
        // yer orası olmalı.
        color: colors.primary,
        shape: const CircleBorder(),
        // Fotoğrafın üstünde de okunsun: açık bir gökyüzünde yeşil daire
        // gölgesiz kaybolabiliyor.
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Icon(
            AppIcons.add,
            size: AppIconSize.md,
            color: colors.onPrimary,
          ),
        ),
      ),
    );
  }
}
