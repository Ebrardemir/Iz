/// Medya veri erişim nesnesi (DAO).
///
/// SORUMLULUĞU: SQL. Sadece SQL.
/// Burada iş kuralı YOK, domain tipi YOK, `Result` YOK — gerekçesi
/// `memory_dao.dart` başındaki notta.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/media/data/tables/media_tables.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';

part 'media_dao.g.dart';

@DriftAccessor(tables: [MediaItems])
class MediaDao extends DatabaseAccessor<AppDatabase> with _$MediaDaoMixin {
  MediaDao(super.db);

  Future<MediaRow?> findMedia(String id) => (select(
    mediaItems,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  Future<List<MediaRow>> findMany(List<String> ids) {
    if (ids.isEmpty) return Future.value(const []);

    return (select(
      mediaItems,
    )..where((t) => t.id.isIn(ids) & t.deletedAt.isNull())).get();
  }

  /// Oluşturur veya günceller.
  ///
  /// `version` YAZAN TARAF artırır (TR-C-31) — tek yazma yolu burası.
  Future<void> upsertMedia(MediaItemsCompanion media) async {
    final id = media.id.value;
    final current = await (select(
      mediaItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    await into(mediaItems).insertOnConflictUpdate(
      media.copyWith(
        updatedAt: Value(DateTime.now()),
        version: Value((current?.version ?? 0) + 1),
      ),
    );
  }

  /// TR-M4-13 — orijinal bulunamadı. Satır SİLİNMİYOR.
  ///
  /// Önizleme hâlâ duruyor olabilir ve kart onunla anlaşılır kalıyor;
  /// kullanıcıya yalnızca rozet gösteriliyor. Kaydı silmek, anının
  /// görselini bir daha geri getirilemez şekilde koparmak olurdu.
  Future<void> markOriginalStatus(
    String id,
    MediaOriginalStatus status, {
    required DateTime verifiedAt,
  }) async {
    final current = await (select(
      mediaItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (current == null) return;

    await (update(mediaItems)..where((t) => t.id.equals(id))).write(
      MediaItemsCompanion(
        originalStatus: Value(status),
        lastVerifiedAt: Value(verifiedAt),
        updatedAt: Value(DateTime.now()),
        version: Value(current.version + 1),
      ),
    );
  }

  /// TR-C-32 — tombstone.
  Future<void> softDelete(String id) async {
    final current = await (select(
      mediaItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (current == null) return;

    await (update(mediaItems)..where((t) => t.id.equals(id))).write(
      MediaItemsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        version: Value(current.version + 1),
      ),
    );
  }
}
