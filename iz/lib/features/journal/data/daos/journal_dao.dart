/// Günlük veri erişim nesnesi (DAO).
///
/// SORUMLULUĞU: SQL. Sadece SQL.
/// Burada iş kuralı YOK, domain tipi YOK, `Result` YOK — gerekçesi
/// `memory_dao.dart` başındaki notta.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/journal/data/tables/journal_tables.dart';

part 'journal_dao.g.dart';

@DriftAccessor(tables: [JournalEntries, JournalMedia])
class JournalDao extends DatabaseAccessor<AppDatabase> with _$JournalDaoMixin {
  JournalDao(super.db);

  /// FR-030 — günlük listesi, EN YENİ GÜN ÜSTTE.
  ///
  /// `entryDate`e göre sıralıyoruz, `createdAt`e göre değil: kullanıcı dün
  /// yaşadığı bir günü bugün yazabilir ve o kayıt dünün yerinde durmalı.
  ///
  /// `deletedAt IS NULL` ZORUNLU (TR-C-32): silme tombstone.
  Stream<List<JournalEntryRow>> watchEntries() {
    return (select(journalEntries)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.entryDate)]))
        .watch();
  }

  Stream<JournalEntryRow?> watchEntry(String id) =>
      _byId(id).watchSingleOrNull();

  Future<JournalEntryRow?> findEntry(String id) => _byId(id).getSingleOrNull();

  SimpleSelectStatement<$JournalEntriesTable, JournalEntryRow> _byId(
    String id,
  ) =>
      select(journalEntries)
        ..where((t) => t.id.equals(id) & t.deletedAt.isNull());

  /// Kaç günlük kaydı var? Ana sayfadaki sayaç için.
  ///
  /// Listeyi çekip uzunluğuna bakmıyoruz: 2.000 kayıtta hepsini belleğe
  /// almak bir sayı için ağır olurdu (NFR-003).
  Stream<int> watchCount() {
    final query = selectOnly(journalEntries)
      ..addColumns([journalEntries.id.count()])
      ..where(journalEntries.deletedAt.isNull());

    return query
        .map((row) => row.read(journalEntries.id.count()) ?? 0)
        .watchSingle();
  }

  /// Oluşturur veya günceller.
  ///
  /// `version` YAZAN TARAF artırır (TR-C-31) — tek yazma yolu burası.
  /// [now] DIŞARIDAN GELİYOR (TR-C-41): `DateTime.now()` çağırsaydık zaman
  /// damgası testte sabitlenemez olurdu.
  Future<void> upsertEntry(
    JournalEntriesCompanion entry, {
    required DateTime now,
    List<String>? mediaIds,
  }) {
    return transaction(() async {
      final id = entry.id.value;
      final current = await (select(
        journalEntries,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      await into(journalEntries).insertOnConflictUpdate(
        entry.copyWith(
          updatedAt: Value(now),
          version: Value((current?.version ?? 0) + 1),
        ),
      );

      // `null` = "bağlara dokunma". Boş liste = "hepsini kaldır".
      if (mediaIds != null) await _replaceMedia(id, mediaIds);
    });
  }

  Future<void> setFavorite(
    String id, {
    required bool isFavorite,
    required DateTime now,
  }) => _patch(
    id,
    now: now,
    (row) => JournalEntriesCompanion(isFavorite: Value(isFavorite)),
  );

  /// TR-C-32 — tombstone.
  Future<void> softDelete(String id, {required DateTime now}) => _patch(
    id,
    now: now,
    (row) => JournalEntriesCompanion(deletedAt: Value(now)),
  );

  /// Günlük kaydının medya bağlarını verilen listeyle DEĞİŞTİRİR.
  Future<void> _replaceMedia(String entryId, List<String> mediaIds) {
    return transaction(() async {
      await (delete(
        journalMedia,
      )..where((t) => t.journalEntryId.equals(entryId))).go();

      await batch((batch) {
        batch.insertAll(journalMedia, [
          for (final (index, mediaId) in mediaIds.indexed)
            JournalMediaCompanion.insert(
              journalEntryId: entryId,
              mediaId: mediaId,
              sortOrder: Value(index),
            ),
        ]);
      });
    });
  }

  /// Var olan satırı okuyup üzerine yazar.
  ///
  /// Okumadan güncelleyemiyoruz çünkü `version`ı bir artırmak için mevcut
  /// değeri bilmek gerekiyor. Kayıt yoksa sessizce hiçbir şey yapılmıyor.
  Future<void> _patch(
    String id,
    JournalEntriesCompanion Function(JournalEntryRow current) build, {
    required DateTime now,
  }) {
    return transaction(() async {
      final current = await (select(
        journalEntries,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (current == null) return;

      await (update(journalEntries)..where((t) => t.id.equals(id))).write(
        build(
          current,
        ).copyWith(updatedAt: Value(now), version: Value(current.version + 1)),
      );
    });
  }
}
