/// Medya domain modeli.
///
/// Rapor 3.2 / ilke: "Fotoğraf temel nesne değil; **anı** temel nesnedir.
/// Medya, anının bileşenidir." Bu yüzden MediaItem tek başına listelenmez,
/// her zaman bir anıya bağlı görünür.
library;

import 'package:equatable/equatable.dart';

enum MediaType {
  photo,
  video, // FR-048 — İZ+
  audio; // FR-049 — İZ+

  bool get isPremium => this != MediaType.photo;
}

/// FR-044 / BR-007: orijinal galeri dosyasının durumu.
///
/// Bu alan olmadan uygulama silinmiş bir fotoğrafı açmaya çalışır ve çöker
/// (NFR-021'in engellemek istediği tam olarak budur).
enum MediaOriginalStatus {
  /// Galeride mevcut, okunabilir.
  available,

  /// Galeriden silinmiş. Elimizde yalnızca önizleme var.
  missing,

  /// Yalnızca bulutta (V1.5, başka cihazdan yüklenmiş).
  cloudOnly,

  /// Henüz doğrulanmadı — uygulama açılışında tembel kontrol edilir.
  unknown,
}

final class MediaItem extends Equatable {
  const MediaItem({
    required this.id,
    required this.type,
    required this.originalStatus,
    this.galleryAssetId,
    this.localPreviewPath,
    this.cloudObjectKey,
    this.mimeType,
    this.width,
    this.height,
    this.durationMs,
    this.sizeBytes,
  });

  final String id;
  final MediaType type;

  /// FR-042: "Uygulama mümkünse orijinal galeri öğesinin platform asset
  /// kimliğini/referansını saklamalıdır." Orijinali kopyalamıyoruz —
  /// local-first stratejisinin temeli bu (NFR-040, maliyet).
  final String? galleryAssetId;

  /// FR-043: uygulama sandbox'ındaki küçük önizleme. Orijinal silinse bile
  /// anı kartı anlamlı kalsın diye.
  final String? localPreviewPath;

  /// V1.5 — bulut nesne anahtarı.
  final String? cloudObjectKey;

  final MediaOriginalStatus originalStatus;
  final String? mimeType;
  final int? width;
  final int? height;
  final int? durationMs;
  final int? sizeBytes;

  /// Baskı öncesi çözünürlük kontrolü (FR-045, FR-123, BR-008).
  bool get isPrintable =>
      originalStatus == MediaOriginalStatus.available &&
      (width ?? 0) >= 1200 &&
      (height ?? 0) >= 1200;

  /// Ekranda gösterilebilecek bir şey var mı?
  bool get hasDisplayableSource =>
      originalStatus == MediaOriginalStatus.available ||
      localPreviewPath != null;

  bool get isMissing => originalStatus == MediaOriginalStatus.missing;

  MediaItem copyWith({
    MediaType? type,
    String? galleryAssetId,
    String? localPreviewPath,
    String? cloudObjectKey,
    MediaOriginalStatus? originalStatus,
    String? mimeType,
    int? width,
    int? height,
    int? durationMs,
    int? sizeBytes,
  }) => MediaItem(
    id: id,
    type: type ?? this.type,
    galleryAssetId: galleryAssetId ?? this.galleryAssetId,
    localPreviewPath: localPreviewPath ?? this.localPreviewPath,
    cloudObjectKey: cloudObjectKey ?? this.cloudObjectKey,
    originalStatus: originalStatus ?? this.originalStatus,
    mimeType: mimeType ?? this.mimeType,
    width: width ?? this.width,
    height: height ?? this.height,
    durationMs: durationMs ?? this.durationMs,
    sizeBytes: sizeBytes ?? this.sizeBytes,
  );

  @override
  List<Object?> get props => [
    id,
    type,
    galleryAssetId,
    localPreviewPath,
    cloudObjectKey,
    originalStatus,
    mimeType,
    width,
    height,
    durationMs,
    sizeBytes,
  ];
}
