/// Fotoğraf şeridi: yatay kaydırılan kareler + kesikli çerçeveli ekleme kutusu.
///
/// PAYLAŞILAN BİLEŞEN. Anı formu (3–30 fotoğraf) ve kişi formu (tek fotoğraf)
/// aynı şeridi kullanıyor: referans tasarımlarda ikisi de aynı kareyi, aynı
/// çarpıyı ve aynı kesikli "+" kutusunu gösteriyor. İki ayrı kopya iki ayrı
/// görünüm demekti — biri düzeltilir, öteki geride kalırdı.
///
/// EKRAN OKUYUCU ETİKETLERİ DIŞARIDAN GELİYOR (`removeLabel`, `addLabel`):
/// `shared/` yalnızca `core/`yi tanıyor, bir feature'ın çeviri anahtarını
/// bilemez.
///
/// YATAY KAYDIRMA, SARMA DEĞİL.
/// Kareleri alt satıra sarmak (`Wrap`) da bir seçenekti; şerit seçtik çünkü
/// bu ekranda fotoğraflar formun BAŞLIĞI değil, GİRİŞİ: sabit yükseklikte tek
/// bir bant olarak kalınca altındaki alanlar hep aynı yerde duruyor. Sarma
/// olsaydı üçüncü fotoğrafı ekleyen kullanıcının bütün formu aşağı kayardı.
///
/// HER KARENİN SAĞ ÜSTÜNDE X.
/// Uzun basma ya da gizli bir düzenleme kipi yok: silme tek dokunuşluk ve
/// görünür. Kaza riskini kabul ediyoruz çünkü kayıp küçük (fotoğraf yeniden
/// eklenebilir) ve alternatifi keşfedilemez bir jest olurdu.
///
/// SONDAKİ "+" KUTUSU KESİKLİ ÇERÇEVELİ.
/// Dolu bir kare gibi görünmemesi lazım: kesikli kenar "burası henüz boş"
/// diyor — fotoğraf seçim adımındaki illüstrasyonun aynı dili
/// (bkz. `photo_prompt_illustration.dart`).
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/shared/widgets/media_thumbnail.dart';

class IzPhotoStrip extends StatelessWidget {
  const IzPhotoStrip({
    required this.photos,
    required this.limit,
    required this.onRemove,
    required this.onAdd,
    required this.removeLabel,
    required this.addLabel,
    this.showAddWhenFull = false,
    super.key,
  });

  final List<MediaItem> photos;

  /// FR-041 — plana göre en fazla kaç fotoğraf (Free 3, İZ+ 30).
  final int limit;

  final void Function(MediaItem photo) onRemove;
  final VoidCallback onAdd;

  /// Silme düğmesinin ekran okuyucu etiketi.
  final String removeLabel;

  /// Ekleme kutusunun ekran okuyucu etiketi.
  final String addLabel;

  /// Sınıra ULAŞILMIŞKEN de "+" kutusu görünsün mü?
  ///
  /// Anı formunda GÖRÜNMÜYOR (varsayılan): kota dolduğunda basılacak bir şey
  /// bırakmak, basınca hiçbir şey olmayan bir düğme demek — orada bunun yerine
  /// sınırı anlatan bir not çıkıyor.
  ///
  /// Kişi formunda GÖRÜNÜYOR: kişinin tek bir fotoğrafı var ve oradaki "+"
  /// "ekle" değil "DEĞİŞTİR" anlamına geliyor. Kullanıcı fotoğrafı değiştirmek
  /// için önce silmek zorunda kalmamalı.
  final bool showAddWhenFull;

  /// Kare ölçüsü.
  ///
  /// Referanstaki şeritte ekran genişliğinin ~%22'si kadar kare var; 390
  /// piksellik bir telefonda üç kare + ekleme kutusu tam sığıyor. Sabit
  /// veriyoruz, oranla değil: kaydırılabilir bir şeritte kare boyu ekran
  /// genişliğine bağlı olmamalı, yoksa tablette dev kutular çıkıyor.
  static const double kTileSize = 84;

  /// Kareler arası boşluk.
  static const double kGap = AppSpacing.sm;

  /// Silme düğmesinin çapı.
  static const double _kRemoveSize = 24;

  /// Şeridin toplam yüksekliği.
  ///
  /// Silme düğmesi karenin ÜST KENARINDAN TAŞIYOR (yarısı dışta); taşan pay
  /// olmadan düğme kırpılıyordu.
  static double get height => kTileSize + _kRemoveSize / 2;

  bool get _canAddMore => showAddWhenFull || photos.length < limit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Kırpılma olmasın: taşan silme düğmesi için üstte pay var.
        clipBehavior: Clip.none,
        itemCount: photos.length + (_canAddMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: kGap),
        itemBuilder: (context, index) {
          if (index == photos.length) {
            return _AddTile(onTap: onAdd, label: addLabel);
          }

          final photo = photos[index];
          return _PhotoTile(
            photo: photo,
            onRemove: () => onRemove(photo),
            removeLabel: removeLabel,
          );
        },
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.onRemove,
    required this.removeLabel,
  });

  final MediaItem photo;
  final VoidCallback onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    const size = IzPhotoStrip.kTileSize;
    const remove = IzPhotoStrip._kRemoveSize;

    return SizedBox(
      width: size,
      height: IzPhotoStrip.height,
      child: Stack(
        // TAŞMAYA İZİN: silme düğmesinin yarısı karenin dışında duruyor.
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            child: MediaThumbnail(
              media: photo,
              size: size,
              borderRadius: AppRadius.md,
            ),
          ),
          Positioned(
            top: 0,
            right: -remove / 3,
            child: _RemoveButton(onTap: onRemove, label: removeLabel),
          ),
        ],
      ),
    );
  }
}

/// Karenin köşesindeki silme düğmesi.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        // DOKUNMA HEDEFİ GÖRÜNENDEN BÜYÜK.
        //
        // Daire 24 piksel — referanstaki ölçü ve karenin köşesinde bundan
        // büyüğü fotoğrafı yutuyor. Ama 24, NFR-033'ün altında; şeffaf bir
        // dolgu parmağa 40 piksel veriyor, göze 24.
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // Fotoğrafın üstünde duruyor ve fotoğrafın rengini bilemeyiz:
              // dolu bir daire ikonu her karede okunur kılıyor.
              color: colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: colors.outlineVariant),
            ),
            child: SizedBox.square(
              dimension: IzPhotoStrip._kRemoveSize,
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

/// Şeridin sonundaki ekleme kutusu.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: IzPhotoStrip.kTileSize,
      height: IzPhotoStrip.height,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(AppRadius.md),
            child: CustomPaint(
              painter: _DashedBorderPainter(color: colors.outline),
              child: SizedBox.square(
                dimension: IzPhotoStrip.kTileSize,
                child: Icon(
                  AppIcons.add,
                  size: AppIconSize.lg,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kesikli kenarlık.
///
/// Flutter'da `Border`ın kesikli biçimi YOK; yolu parçalayıp çizmek gerekiyor.
/// Aynı teknik fotoğraf seçim adımındaki çerçevede de kullanılıyor
/// (`photo_prompt_illustration.dart`) — iki ekran aynı "burası boş" dilini
/// paylaşıyor.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, AppRadius.md));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
