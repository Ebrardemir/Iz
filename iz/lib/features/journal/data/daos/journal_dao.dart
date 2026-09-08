/// Günlük veri erişim nesnesi (DAO).
///
/// SORUMLULUĞU: SQL. Sadece SQL.
/// Burada iş kuralı YOK, domain tipi YOK, `Result` YOK — gerekçesi
/// `memory_dao.dart` başındaki notta.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/journal/data/tables/journal_tables.dart';
import 'package:iz/features/sync/data/daos/outbox_dao.dart';
import 'package:iz/features/sync/data/outbox_payload.dart';
import 'package:iz/features/sync/domain/entities/outbox_operation.dart';

part 'journal_dao.g.dart';

/// Günlük kaydının outbox'taki karşılığı — sunucu bu adla tanıyor.
/// Sabit ve DEĞİŞMEZ: bekleyen eski kuyruk satırları bu adı taşıyor.
const kJournalEntityType = 'journal_entry';

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
    // TR-M13-01 — kuyruk satırının kimliği çağırandan.
    required String outboxId,
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
      if (mediaIds != null) await _replaceMedia(id, mediaIds, now);

      await _enqueue(
        id,
        op: current == null ? OutboxOperation.create : OutboxOperation.update,
        baseVersion: current?.version ?? 0,
        outboxId: outboxId,
        now: now,
      );
    });
  }

  /// Değişikliği outbox'a düşürür — AYNI TRANSACTION İÇİNDEN.
  ///
  /// Gerekçesi `memory_dao.dart`taki aynı adlı fonksiyonun notunda.
  ///
  /// ⚠️ GİZLİLİK BORCU: FR-035'teki `deviceOnly` kayıtlar buraya HİÇ
  /// GİRMEMELİ (TR-M3-02). O süzgeç Faz 3'te, motor yazılırken kurulacak.
  /// Bugün kuyruğu okuyan kimse yok — yani kayıt cihazdan çıkmıyor — ama
  /// motor açılmadan ÖNCE bu satır bir koşul kazanmak zorunda.
  Future<void> _enqueue(
    String entryId, {
    required OutboxOperation op,
    required int baseVersion,
    required String outboxId,
    required DateTime now,
  }) async {
    final row = await (select(
      journalEntries,
    )..where((t) => t.id.equals(entryId))).getSingleOrNull();
    if (row == null) return;

    final medyalar = await (select(
      journalMedia,
    )..where((t) => t.journalEntryId.equals(entryId))).get();

    await OutboxDao(attachedDatabase).enqueue(
      id: outboxId,
      entityType: kJournalEntityType,
      entityId: entryId,
      op: op,
      payloadJson: encodeOutboxPayload(
        entity: outboxRowJson(row),
        links: {
          'journal_media': [for (final link in medyalar) outboxRowJson(link)],
        },
      ),
      baseVersion: baseVersion,
      now: now,
    );
  }

  Future<void> setFavorite(
    String id, {
    required bool isFavorite,
    required DateTime now,
    required String outboxId,
  }) => _patch(
    id,
    now: now,
    outboxId: outboxId,
    (row) => JournalEntriesCompanion(isFavorite: Value(isFavorite)),
  );

  /// TR-C-32 — tombstone.
  Future<void> softDelete(
    String id, {
    required DateTime now,
    required String outboxId,
  }) => _patch(
    id,
    now: now,
    outboxId: outboxId,
    // Sunucuya "sil" diye gitmezse ikinci cihaz silmeyi hiç öğrenmez.
    op: OutboxOperation.delete,
    (row) => JournalEntriesCompanion(deletedAt: Value(now)),
  );

  /// Günlük kaydının medya bağlarını verilen listeyle EŞİTLER — silmeden.
  ///
  /// Deseni ve gerekçesi `memory_dao.dart`taki "Bağ eşitleme" bölümünde.
  Future<void> _replaceMedia(
    String entryId,
    List<String> mediaIds,
    DateTime now,
  ) {
    return transaction(() async {
      final current = await (select(
        journalMedia,
      )..where((t) => t.journalEntryId.equals(entryId))).get();
      final byMedia = {for (final row in current) row.mediaId: row};

      for (final row in current) {
        if (row.deletedAt == null && !mediaIds.contains(row.mediaId)) {
          await (update(journalMedia)..where(
                (t) =>
                    t.journalEntryId.equals(entryId) &
                    t.mediaId.equals(row.mediaId),
              ))
              .write(
                JournalMediaCompanion(
                  deletedAt: Value(now),
                  updatedAt: Value(now),
                  version: Value(row.version + 1),
                ),
              );
        }
      }

      for (final (index, mediaId) in mediaIds.indexed) {
        final existing = byMedia[mediaId];
        await into(journalMedia).insertOnConflictUpdate(
          JournalMediaCompanion.insert(
            journalEntryId: entryId,
            mediaId: mediaId,
            sortOrder: Value(index),
            updatedAt: Value(now),
            deletedAt: const Value(null),
            version: Value((existing?.version ?? 0) + 1),
          ),
        );
      }
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
    required String outboxId,
    OutboxOperation op = OutboxOperation.update,
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

      await _enqueue(
        id,
        op: op,
        baseVersion: current.version,
        outboxId: outboxId,
        now: now,
      );
    });
  }
}
