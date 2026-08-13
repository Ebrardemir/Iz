/// Medya önizlemesi.
///
/// BR-007 / FR-044'ün UI karşılığı: orijinal galeri dosyası silinmiş olsa
/// bile kullanıcıya anlamlı bir şey göstermeliyiz — ya cache'lenmiş
/// önizleme ya da açıklayıcı bir yer tutucu. Asla boş kutu veya çökme.
///
/// NOT: Gerçek galeri erişimi (photo_manager gibi bir paketle) MVP
/// geliştirmesinde eklenecek. Şimdilik dosya yolundan okuma + yer tutucu
/// mantığı kurulu; `MediaSource` adaptörü bağlanınca burası değişmeyecek.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';

class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({
    required this.media,
    this.size = 64,
    this.width,
    this.height,
    this.borderRadius = AppRadius.md,
    super.key,
  });

  final MediaItem? media;

  /// Kare ölçü — [width] ve [height] verilmediğinde ikisi de bu olur.
  final double size;

  /// DİKDÖRTGEN ölçü.
  ///
  /// Anı detayının kapak görseli 16:9; kare bir önizleme kapak olamıyordu.
  /// [size]ı kaldırıp her çağrıyı ikiye çıkarmak yerine kısayolu bıraktık:
  /// çağrıların büyük çoğunluğu kare (liste kartları, şeritler) ve orada
  /// `size: 64` tek satırda daha okunur.
  final double? width;
  final double? height;

  final Radius borderRadius;

  double get _width => width ?? size;
  double get _height => height ?? size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.all(borderRadius),
      child: SizedBox(
        width: _width,
        height: _height,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final item = media;

    if (item == null) {
      return _Placeholder(icon: AppIcons.photo, size: _shortestSide);
    }

    final previewPath = item.localPreviewPath;
    if (previewPath != null && _canShow(previewPath)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (_isAsset(previewPath))
            // ⚠️ GEÇİCİ — TASARIM ÖNİZLEMESİ.
            //
            // Ana sayfa ve "Hayatım" henüz veri kaynağına bağlı değil;
            // gösterdikleri anıların "önizlemesi" paketle gelen bir görsel
            // (`assets/images/...`). Dosya sisteminde böyle bir yol yok, o
            // yüzden `Image.file` her seferinde yer tutucuya düşüyordu ve
            // detay ekranının kapağı boş bir kutu olarak açılıyordu.
            //
            // Gerçek medya hattı kurulduğunda `localPreviewPath` her zaman
            // sandbox içinde bir dosya olacak ve bu dal silinecek.
            Image.asset(
              previewPath,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _Placeholder(
                icon: AppIcons.mediaMissing,
                size: _shortestSide,
              ),
            )
          else
            Image.file(
              File(previewPath),
              fit: BoxFit.cover,
              // Dosya bozuksa çökme — NFR-021.
              errorBuilder: (_, _, _) => _Placeholder(
                icon: AppIcons.mediaMissing,
                size: _shortestSide,
              ),
            ),
          // Orijinal kayıpsa önizlemenin üstünde küçük bir işaret.
          if (item.isMissing)
            Positioned(
              right: 2,
              bottom: 2,
              child: _MissingBadge(color: context.semanticColors.warning),
            ),
          if (item.type == MediaType.video)
            const Center(child: Icon(AppIcons.play, color: Colors.white70)),
        ],
      );
    }

    // Önizleme de yoksa duruma göre yer tutucu.
    return _Placeholder(
      icon: switch (item.originalStatus) {
        MediaOriginalStatus.missing => AppIcons.mediaMissing,
        MediaOriginalStatus.cloudOnly => AppIcons.cloud,
        _ => switch (item.type) {
          MediaType.video => AppIcons.video,
          MediaType.audio => AppIcons.audio,
          MediaType.photo => AppIcons.photo,
        },
      },
      size: _shortestSide,
    );
  }

  /// Bu yol paketle gelen bir görsel mi? (bkz. `Image.asset` dalı)
  static bool _isAsset(String path) => path.startsWith('assets/');

  /// Gösterilebilir bir önizleme var mı?
  ///
  /// Asset için dosya sistemine bakmıyoruz — paket içinde olup olmadığını
  /// `Image.asset`in kendi hata dalı söylüyor.
  static bool _canShow(String path) =>
      _isAsset(path) || File(path).existsSync();

  /// Yer tutucu ikonunun ölçüsü KISA KENARDAN geliyor.
  ///
  /// Uzun kenardan hesaplasaydık 16:9 bir kapakta ikon kutunun dışına
  /// taşardı; kare çağrılarda ikisi de aynı sayı olduğu için davranış
  /// değişmiyor.
  double get _shortestSide => _width < _height ? _width : _height;
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surfaceContainerHighest,
      child: Icon(
        icon,
        size: size * 0.4,
        color: context.colors.onSurfaceVariant,
      ),
    );
  }
}

class _MissingBadge extends StatelessWidget {
  const _MissingBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(AppRadius.xs),
      ),
      child: const Padding(
        padding: EdgeInsets.all(2),
        child: Icon(AppIcons.warning, size: 12, color: Colors.white),
      ),
    );
  }
}
