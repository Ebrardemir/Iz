/// Veritabanı satırı ↔ domain nesnesi çevirisi.
///
/// NEDEN BURADA, `memory_mapper.dart`TA DEĞİL?
/// Bu sınıf bir süre anılar feature'ının mapper dosyasında yaşadı, çünkü tek
/// kullanıcısı anı detayıydı. Artık medyanın kendi veri hattı var; iki ayrı
/// kopya tutmak, birinin gün gelip ötekinden ayrışması demekti. Koleksiyon
/// tarafında da aynı taşımayı yaptık.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';

abstract final class MediaMapper {
  static MediaItem toDomain(MediaRow row) => MediaItem(
    id: row.id,
    type: row.type,
    galleryAssetId: row.galleryAssetId,
    localPreviewPath: row.localPreviewPath,
    cloudObjectKey: row.cloudObjectKey,
    originalStatus: row.originalStatus,
    mimeType: row.mimeType,
    width: row.width,
    height: row.height,
    durationMs: row.durationMs,
    sizeBytes: row.sizeBytes,
  );

  /// Galeriden alınıp uygulama alanına kopyalanmış bir dosyayı satıra çevirir.
  ///
  /// [originalStatus] `unknown`: elimizde kalıcı bir GALERİ kimliği yok
  /// (sistem seçicisi yalnız dosya veriyor), yani "orijinal hâlâ duruyor mu?"
  /// sorusunu bugün cevaplayamıyoruz. `available` yazmak yalan olurdu —
  /// kullanıcı fotoğrafı galeriden silmiş olabilir ve biz bilmiyoruz.
  /// TR-M4-12'deki tembel doğrulama bu alanı sonradan güncelleyecek.
  static MediaItemsCompanion toCompanion({
    required String id,
    required String previewPath,
    String? mimeType,
    int? sizeBytes,
  }) => MediaItemsCompanion.insert(
    id: id,
    type: MediaType.photo,
    localPreviewPath: Value(previewPath),
    originalStatus: const Value(MediaOriginalStatus.unknown),
    mimeType: Value(mimeType),
    sizeBytes: Value(sizeBytes),
  );
}
