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

part 'ritual_dao.g.dart';

@DriftAccessor(tables: [Rituals, MemoryRituals])
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
    return (select(rituals)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<RitualRow?> watchRitual(String id) => _byId(id).watchSingleOrNull();

  Future<RitualRow?> findRitual(String id) => _byId(id).getSingleOrNull();

  SimpleSelectStatement<$RitualsTable, RitualRow> _byId(String id) =>
      select(rituals)..where((t) => t.id.equals(id) & t.deletedAt.isNull());

  /// Seri kimliği → bağlı anılar ve yılları.
  ///
  /// Yıla göre sıralı: seri görünümü yılları karşılaştırıyor (FR-076), yani
  /// listeyi ekranın istediği düzende vermek en ucuzu.
  Stream<Map<String, List<({String memoryId, int year})>>> watchOccurrences() {
    final query = select(memoryRituals)
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

  /// Seriyi VE anı bağlarını tek transaction'da yazar.
  ///
  /// `version` YAZAN TARAF artırır (TR-C-31) — tek yazma yolu burası.
  Future<void> upsertRitual(
    RitualsCompanion ritual, {
    List<({String memoryId, int year})>? occurrences,
  }) {
    return transaction(() async {
      final id = ritual.id.value;
      final current = await (select(
        rituals,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      await into(rituals).insertOnConflictUpdate(
        ritual.copyWith(
          updatedAt: Value(DateTime.now()),
          version: Value((current?.version ?? 0) + 1),
        ),
      );

      // `null` = "bağlara dokunma". Boş liste = "hepsini kaldır".
      if (occurrences != null) {
        await _replaceOccurrences(id, occurrences);
      }
    });
  }

  /// TR-C-32 — tombstone. TR-M6-11'in seri karşılığı: anılar silinmiyor.
  Future<void> softDelete(String id) {
    return transaction(() async {
      final current = await (select(
        rituals,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (current == null) return;

      await (update(rituals)..where((t) => t.id.equals(id))).write(
        RitualsCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          version: Value(current.version + 1),
        ),
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
  ) {
    return transaction(() async {
      await (delete(
        memoryRituals,
      )..where((t) => t.ritualId.equals(ritualId))).go();

      final byYear = <int, String>{};
      for (final occurrence in occurrences) {
        byYear[occurrence.year] = occurrence.memoryId;
      }

      await batch((batch) {
        batch.insertAll(memoryRituals, [
          for (final entry in byYear.entries)
            MemoryRitualsCompanion.insert(
              memoryId: entry.value,
              ritualId: ritualId,
              occurrenceYear: entry.key,
            ),
        ]);
      });
    });
  }
}
