/// Yeni kişi formunun tepesindeki yuvarlak fotoğraf alanı.
///
/// BOŞKEN BİR DAVET, DOLUYKEN BİR ÖNİZLEME.
/// Boş hâlde soluk bir daire, ortasında kamera ikonu ve altında "Fotoğraf
/// Ekle" yazıyor — dokunulacak bir şey olduğu görünüyor. Fotoğraf seçildikten
/// sonra daire onu gösteriyor ve köşesinde kaldırma düğmesi çıkıyor; yazı da
/// "değiştir"e dönüyor, çünkü artık yapılabilecek şey farklı.
///
/// ⚠️ DAİRE, KARE DEĞİL. Kişi listesindeki avatar yuvarlak (bkz. `PersonRow`);
/// forma kare bir seçici koymak kullanıcının seçtiği kadrajı yanlış
/// göstermek olurdu.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/shared/widgets/media_thumbnail.dart';

class PersonPhotoPicker extends StatelessWidget {
  const PersonPhotoPicker({
    required this.photo,
    required this.onPick,
    required this.onRemove,
    super.key,
  });

  /// Seçilmiş fotoğraf; null ise boş hâl.
  final MediaItem? photo;

  final VoidCallback onPick;
  final VoidCallback onRemove;

  /// Dairenin çapı.
  ///
  /// Referansta ekran genişliğinin ~%30'u; 390 piksellik telefonda 116.
  /// Sabit veriyoruz: bu bir avatar, ekranla birlikte büyümesi gerekmiyor.
  static const double kSize = 116;

  /// Kaldırma düğmesinin çapı.
  static const double _kRemoveSize = 28;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final item = photo;

    // DAİRE VE YAZI BİRLİKTE DOKUNULABİLİR.
    //
    // Önce yalnızca daire `InkWell` içindeydi; "Fotoğraf Ekle" yazısı
    // dokunulabilir görünüyor ama hiçbir şey yapmıyordu — bir testte
    // yazıya dokunup galerinin açılmadığını görünce fark ettik. Yazı bir
    // etiket değil, düğmenin parçası.
    return Semantics(
      button: true,
      label: item == null ? l10n.personPhotoAdd : l10n.personPhotoChange,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPick,
        // Dikdörtgen bir vurgu dairenin dışına taşardı; dokunma alanı geniş,
        // görsel geri bildirim yok.
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              // Kaldırma düğmesi dairenin kenarından taşıyor; taşan pay olmadan
              // kırpılıyordu.
              //
              // PAY YALNIZCA FOTOĞRAF VARKEN: boş hâlde kaldırma düğmesi de
              // yok ve sabit pay daireyi ekranın ortasından sola kaydırıyordu.
              width: item == null ? kSize : kSize + _kRemoveSize / 2,
              height: kSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    child: item == null
                        ? const _EmptyCircle(size: kSize)
                        : MediaThumbnail(
                            media: item,
                            size: kSize,
                            borderRadius: const Radius.circular(kSize / 2),
                          ),
                  ),

                  // KALDIRMA DÜĞMESİ YIĞININ ÜSTÜNDE: dışardaki `InkWell`in
                  // içinde ama `Stack`ta daha sonra çizildiği için dokunuşu
                  // önce o alıyor.
                  if (item != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: _RemoveButton(onTap: onRemove),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            Text(
              item == null ? l10n.personPhotoAdd : l10n.personPhotoChange,
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Boş hâl: soluk daire + kamera ikonu.
class _EmptyCircle extends StatelessWidget {
  const _EmptyCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        // "GÖRSEL EKLE", kamera DEĞİL.
        //
        // Referansta bir fotoğraf makinesi duruyor ama davranış galeriden
        // seçmek: kamera ikonu "şimdi çek" diye yanlış bir söz verirdi.
        // Çekim özelliği geldiğinde ikisini ayıran bir seçim sunulacak.
        AppIcons.addPhoto,
        size: AppIconSize.lg,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}

/// Dairenin köşesindeki kaldırma düğmesi.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: context.l10n.personPhotoRemove,
      child: GestureDetector(
        onTap: onTap,
        // Daire 28 piksel — NFR-033'ün altında; şeffaf bir dolgu parmağa 44
        // piksel veriyor, göze 28. Aynı desen anı formunun fotoğraf
        // şeridinde de var.
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: colors.outlineVariant),
            ),
            child: SizedBox.square(
              dimension: PersonPhotoPicker._kRemoveSize,
              child: Icon(
                AppIcons.clear,
                size: AppIconSize.sm,
                color: colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
