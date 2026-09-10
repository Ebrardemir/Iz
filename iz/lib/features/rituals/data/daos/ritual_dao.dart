/// Seri (ritüel) veri erişim nesnesi (DAO).
///
/// SORUMLULUĞU: SQL. Sadece SQL.
/// Burada iş kuralı YOK, domain tipi YOK, `Result` YOK — gerekçesi
/// `memory_dao.dart` başındaki notta.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/memories/data/tables/memory_tables.dart';
import 'package:iz/features/rituals/data/tables/ritual_tables.dart';
import 'package:iz/features/sync/data/daos/outbox_dao.dart';
import 'package:iz/features/sync/data/outbox_payload.dart';
import 'package:iz/features/sync/domain/entities/outbox_operation.dart';

part 'ritual_dao.g.dart';

/// Serinin outbox'taki karşılığı — sunucu bu adla tanıyor.
/// Sabit ve DEĞİŞMEZ: bekleyen eski kuyruk satırları bu adı taşıyor.
const kRitualEntityType = 'ritual';

@DriftAccessor(tables: [Rituals, MemoryRituals, RitualPeople])
class RitualDao extends DatabaseAccessor<AppDatabase> with _$RitualDaoMixin {
  RitualDao(super.db);

  /// FR-075 — seri listesi.
  ///
  /// SIRALAMA: en yeni oluşturulan başta — koleksiyonlardaki kararın aynısı.
  /// Seri de çoğu zaman anılarından önce kuruluyor ("Yaz Tatillerimiz"),
  /// yani kullanıcı az önce açtığını hemen görmeli.
  ///
  /// `deletedAt IS NULL` ZORUNLU (TR-C-32): silme tombstone.
  Stream<List<RitualRow>> watchRituals() {
    return (selectOwned(rituals, rituals.ownerId)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<RitualRow?> watchRitual(String id) => _byId(id).watchSingleOrNull();

  Future<RitualRow?> findRitual(String id) => _byId(id).getSingleOrNull();

  SimpleSelectStatement<$RitualsTable, RitualRow> _byId(String id) =>
      selectOwned(rituals, rituals.ownerId)
        ..where((t) => t.id.equals(id) & t.deletedAt.isNull());

  /// Seri kimliği → bağlı anılar ve yılları.
  ///
  /// Yıla göre sıralı: seri görünümü yılları karşılaştırıyor (FR-076), yani
  /// listeyi ekranın istediği düzende vermek en ucuzu.
  Stream<Map<String, List<({String memoryId, int year})>>> watchOccurrences() {
    // `deletedAt IS NULL` ZORUNLU (şema v8): bağlar artık silinmiyor,
    // tombstone'lanıyor. Süzgeci atlayan sorgu koparılmış ilişkiyi
    // ekranda göstermeye devam eder.
    final query = select(memoryRituals)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.occurrenceYear)]);

    return query.watch().map((rows) {
      final links = <String, List<({String memoryId, int year})>>{};
      for (final row in rows) {
        (links[row.ritualId] ??= []).add((
          memoryId: row.memoryId,
          year: row.occurrenceYear,
        ));
      }
      return links;
    });
  }

  /// Seri kimliği → bağlı kişi kimlikleri.
  ///
  /// Anı bağlarından AYRI akış: kişi değişince anı listesini yeniden çekmek
  /// gereksiz iş olurdu.
  Stream<Map<String, Set<String>>> watchPeopleLinks() {
    return (select(
      ritualPeople,
    )..where((t) => t.deletedAt.isNull())).watch().map((rows) {
      final links = <String, Set<String>>{};
      for (final row in rows) {
        (links[row.ritualId] ??= {}).add(row.personId);
      }
      return links;
    });
  }

  /// Seriyi, anı bağlarını VE kişi bağlarını tek transaction'da yazar.
  ///
  /// `version` YAZAN TARAF artırır (TR-C-31) — tek yazma yolu burası.
  Future<void> upsertRitual(
    RitualsCompanion ritual, {
    List<({String memoryId, int year})>? occurrences,
    Set<String>? personIds,
    // TR-C-41 — saat dışarıdan. Seri ve bağları AYNI ana damgalanmalı.
    required DateTime now,
    // TR-M13-01 — kuyruk satırının kimliği çağırandan.
    required String outboxId,
  }) {
    return transaction(() async {
      final id = ritual.id.value;
      final current = await (selectOwned(
        rituals,
        rituals.ownerId,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      await into(rituals).insertOnConflictUpdate(
        ritual.copyWith(
          updatedAt: Value(now),
          version: Value((current?.version ?? 0) + 1),
          // Sahip YAZMA ANINDA damgalanıyor; gerekçesi `activeOwnerId`de.
          ownerId: Value(activeOwnerId),
        ),
      );

      // `null` = "bağlara dokunma". Boş liste = "hepsini kaldır".
      if (occurrences != null) {
        await _replaceOccurrences(id, occurrences, now);
      }
      if (personIds != null) {
        await _replacePeople(id, personIds, now);
      }

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
  /// Kişi ve anı bağları tombstone'lananlar dâhil gövdeye giriyor.
  Future<void> _enqueue(
    String ritualId, {
    required OutboxOperation op,
    required int baseVersion,
    required String outboxId,
    required DateTime now,
  }) async {
    final row = await (selectOwned(
      rituals,
      rituals.ownerId,
    )..where((t) => t.id.equals(ritualId))).getSingleOrNull();
    if (row == null) return;

    final kisiler = await (select(
      ritualPeople,
    )..where((t) => t.ritualId.equals(ritualId))).get();
    final anilar = await (select(
      memoryRituals,
    )..where((t) => t.ritualId.equals(ritualId))).get();

    await OutboxDao(attachedDatabase).enqueue(
      id: outboxId,
      entityType: kRitualEntityType,
      entityId: ritualId,
      op: op,
      payloadJson: encodeOutboxPayload(
        entity: outboxRowJson(row),
        links: {
          'ritual_people': [for (final link in kisiler) outboxRowJson(link)],
          'memory_rituals': [for (final link in anilar) outboxRowJson(link)],
        },
      ),
      baseVersion: baseVersion,
      now: now,
    );
  }

  /// Serinin kişi bağlarını verilen kümeyle EŞİTLER — silmeden.
  ///
  /// Deseni ve gerekçesi `memory_dao.dart`taki "Bağ eşitleme" bölümünde:
  /// bağı gerçekten silersek ikinci cihaz onu geri ekler (rapor §1.1).
  Future<void> _replacePeople(
    String ritualId,
    Set<String> personIds,
    DateTime now,
  ) {
    return transaction(() async {
      final current = await (select(
        ritualPeople,
      )..where((t) => t.ritualId.equals(ritualId))).get();
      final byPerson = {for (final row in current) row.personId: row};

      for (final row in current) {
        if (row.deletedAt == null && !personIds.contains(row.personId)) {
          await (update(ritualPeople)..where(
                (t) =>
                    t.ritualId.equals(ritualId) &
                    t.personId.equals(row.personId),
              ))
              .write(
                RitualPeopleCompanion(
                  deletedAt: Value(now),
                  updatedAt: Value(now),
                  version: Value(row.version + 1),
                ),
              );
        }
      }

      for (final personId in personIds) {
        final existing = byPerson[personId];
        if (existing != null && existing.deletedAt == null) continue;

        await into(ritualPeople).insertOnConflictUpdate(
          RitualPeopleCompanion.insert(
            ritualId: ritualId,
            personId: personId,
            updatedAt: Value(now),
            deletedAt: const Value(null),
            version: Value((existing?.version ?? 0) + 1),
          ),
        );
      }
    });
  }

  /// TR-C-32 — tombstone. TR-M6-11'in seri karşılığı: anılar silinmiyor.
  Future<void> softDelete(
    String id, {
    required DateTime now,
    required String outboxId,
  }) {
    return transaction(() async {
      final current = await (selectOwned(
        rituals,
        rituals.ownerId,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (current == null) return;

      await (update(
        rituals,
      )..where((t) => t.id.equals(id) & ownedBy(rituals.ownerId))).write(
        RitualsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          version: Value(current.version + 1),
        ),
      );

      // Sunucuya "sil" diye gitmezse ikinci cihaz silmeyi hiç öğrenmez.
      await _enqueue(
        id,
        op: OutboxOperation.delete,
        baseVersion: current.version,
        outboxId: outboxId,
        now: now,
      );
    });
  }

  /// Serinin anı bağlarını verilen listeyle DEĞİŞTİRİR.
  ///
  /// TR-M6-12 — AYNI YILA EN FAZLA BİR ANI. Birincil anahtar
  /// `(memoryId, ritualId)` bunu kendiliğinden garanti etmiyor: aynı seriye
  /// FARKLI iki anı aynı yılla bağlanabilirdi. Kuralı burada uyguluyoruz;
  /// aynı yıl ikinci kez gelirse SONUNCUSU kazanıyor (form zaten kullanıcıya
  /// tek liste gösteriyor, ikinci giriş bir düzeltmedir).
  Future<void> _replaceOccurrences(
    String ritualId,
    List<({String memoryId, int year})> occurrences,
    DateTime now,
  ) {
    return transaction(() async {
      final byYear = <int, String>{};
      for (final occurrence in occurrences) {
        byYear[occurrence.year] = occurrence.memoryId;
      }
      final istenen = {for (final entry in byYear.entries) entry.value};

      final current = await (select(
        memoryRituals,
      )..where((t) => t.ritualId.equals(ritualId))).get();
      final byMemory = {for (final row in current) row.memoryId: row};

      // Listeden çıkan bağlar tombstone (silme DEĞİL — bkz. memory_dao.dart).
      for (final row in current) {
        if (row.deletedAt == null && !istenen.contains(row.memoryId)) {
          await (update(memoryRituals)..where(
                (t) =>
                    t.ritualId.equals(ritualId) &
                    t.memoryId.equals(row.memoryId),
              ))
              .write(
                MemoryRitualsCompanion(
                  deletedAt: Value(now),
                  updatedAt: Value(now),
                  version: Value(row.version + 1),
                ),
              );
        }
      }

      for (final entry in byYear.entries) {
        final existing = byMemory[entry.value];
        await into(memoryRituals).insertOnConflictUpdate(
          MemoryRitualsCompanion.insert(
            memoryId: entry.value,
            ritualId: ritualId,
            // Yıl HER ZAMAN yazılıyor: canlı bir bağın yılı düzeltilmiş
            // olabilir.
            occurrenceYear: entry.key,
            updatedAt: Value(now),
            deletedAt: const Value(null),
            version: Value((existing?.version ?? 0) + 1),
          ),
        );
      }
    });
  }
}
