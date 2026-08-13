import 'package:drift/drift.dart';
import 'package:iz/core/database/table_mixins.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';

/// Medya **metadata**'sı. Binary veri BURAYA YAZILMAZ —
/// rapor 12.2: "Medya binary verisi DB'ye gömülmemeli; dosya/object storage,
/// DB'de metadata yaklaşımı kullanılmalıdır."
@DataClassName('MediaRow')
class MediaItems extends Table with SyncableTable {
  /// Domain enum'u metin olarak saklanır ('photo'/'video'/'audio').
  /// int yerine text: şemaya bakan biri değeri anlar ve enum sırası
  /// değişince veri bozulmaz.
  TextColumn get type => textEnum<MediaType>()();

  /// FR-042 — iOS PHAsset localIdentifier / Android MediaStore id
  TextColumn get galleryAssetId => text().nullable()();

  /// FR-043 — uygulama sandbox'ındaki önizleme dosyasının yolu
  TextColumn get localPreviewPath => text().nullable()();

  /// V1.5 — bulut nesne anahtarı
  TextColumn get cloudObjectKey => text().nullable()();

  TextColumn get originalStatus =>
      textEnum<MediaOriginalStatus>().withDefault(const Constant('unknown'))();

  TextColumn get mimeType => text().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get sizeBytes => integer().nullable()();

  /// FR-044: en son ne zaman "orijinal hâlâ duruyor mu?" diye baktık.
  DateTimeColumn get lastVerifiedAt => dateTime().nullable()();
}
