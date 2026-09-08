/// Koleksiyon veri erişim nesnesi (DAO).
///
/// SORUMLULUĞU: SQL. Sadece SQL.
/// Burada iş kuralı YOK, domain tipi YOK, `Result` YOK — gerekçesi
/// `memory_dao.dart` başındaki notta.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/collections/data/tables/collection_tables.dart';
import 'package:iz/features/memories/data/tables/memory_tables.dart';
import 'package:iz/features/sync/data/daos/outbox_dao.dart';
import 'package:iz/features/sync/data/outbox_payload.dart';
import 'package:iz/features/sync/domain/entities/outbox_operation.dart';

part 'collection_dao.g.dart';

/// Koleksiyonun outbox'taki karşılığı — sunucu bu adla tanıyor.
/// Sabit ve DEĞİŞMEZ: bekleyen eski kuyruk satırları bu adı taşıyor.
const kCollectionEntityType = 'collection';

@DriftAccessor(tables: [Collections, MemoryCollections])
class CollectionDao extends DatabaseAccessor<AppDatabase>
    with _$CollectionDaoMixin {
  CollectionDao(super.db);

  /// FR-073 — koleksiyon listesi.
  ///
  /// SIRALAMA: en yeni oluşturulan başta. Koleksiyon çoğu zaman anılardan
  /// ÖNCE kuruluyor ("Kapadokya 2026" seyahate çıkmadan açılıyor), yani
  /// kullanıcı az önce açtığını hemen görmeli. Alfabetik sıra burada
  /// kişisel bir listede anlamsız bir düzen olurdu.
  ///
  /// `deletedAt IS NULL` filtresi ZORUNLU (TR-C-32): silme tombstone olduğu
  /// için satır tabloda kalmaya devam ediyor.
  Stream<List<CollectionRow>> watchCollections() {
    return (select(collections)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<CollectionRow?> watchCollection(String id) =>
      _byId(id).watchSingleOrNull();

  Future<CollectionRow?> findCollection(String id) =>
      _byId(id).getSingleOrNull();

  SimpleSelectStatement<$CollectionsTable, CollectionRow> _byId(String id) =>
      select(collections)..where((t) => t.id.equals(id) & t.deletedAt.isNull());

  /// Koleksiyon kimliği → içindeki anı kimlikleri.
  ///
  /// NEDEN ANI SATIRLARINI DEĞİL, SADECE KİMLİKLERİ?
  /// Anının kapak görseli, medya sayısı ve konumu `MemoryDao`nun işi ve o
  /// sorgu zaten yazılmış (`watchMemories`). Burada aynı join'i ikinci kez
  /// kurmak, bir gün ikisinin ayrışması demekti. DAO yalnız BAĞI söylüyor;
  /// anıların kendisini çağıran taraf mevcut yoldan alıyor.
  ///
  /// Sıra korunuyor (`sortOrder`): kullanıcının formda dizdiği düzen.
  Stream<Map<String, List<String>>> watchMemoryLinks() {
    // `deletedAt IS NULL` ZORUNLU (şema v8): bağlar artık silinmiyor,
    // tombstone'lanıyor. Süzgeci atlayan sorgu koleksiyondan çıkarılmış
    // anıyı göstermeye devam eder.
    final query = select(memoryCollections)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);

    return query.watch().map((rows) {
      final links = <String, List<String>>{};
      for (final row in rows) {
        (links[row.collectionId] ??= []).add(row.memoryId);
      }
      return links;
    });
  }

  /// Koleksiyonu VE anı bağlarını tek transaction'da yazar.
  ///
  /// NFR-020'nin koleksiyon karşılığı: koleksiyon yazılıp anı bağları
  /// yazılamazsa kullanıcı boş bir koleksiyon görür ve bunu asla fark etmez.
  ///
  /// `version` YAZAN TARAF artırır (TR-C-31) — tek yazma yolu burası.
  Future<void> upsertCollection(
    CollectionsCompanion collection, {
    // TR-C-41 — saat dışarıdan. Koleksiyon ve bağları AYNI ana damgalanmalı.
    required DateTime now,
    // TR-M13-01 — kuyruk satırının kimliği çağırandan.
    required String outboxId,
    List<String>? memoryIds,
  }) {
    return transaction(() async {
      final id = collection.id.value;
      final current = await (select(
        collections,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      await into(collections).insertOnConflictUpdate(
        collection.copyWith(
          updatedAt: Value(now),
          version: Value((current?.version ?? 0) + 1),
        ),
      );

      // `null` = "bağlara dokunma". Boş liste = "hepsini kaldır". İkisi ayrı
      // niyet: yalnız başlığı düzenleyen bir form anıları silmemeli.
      if (memoryIds != null) {
        await _replaceMemories(id, memoryIds, now);
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

  /// TR-C-32 — tombstone. Satır silinmiyor, işaretleniyor.
  ///
  /// TR-M6-11: koleksiyon silindiğinde ANILAR SİLİNMEZ. Bağları da
  /// bilerek bırakıyoruz: tombstone'un amacı "bu kaydı sildim" olayını
  /// senkronizasyonda taşımak; bağları şimdi silsek, silme geri alınamaz
  /// hâle gelirdi.
  Future<void> softDelete(
    String id, {
    required DateTime now,
    required String outboxId,
  }) {
    return transaction(() async {
      final current = await (select(
        collections,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (current == null) return;

      await (update(collections)..where((t) => t.id.equals(id))).write(
        CollectionsCompanion(
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

  /// Değişikliği outbox'a düşürür — AYNI TRANSACTION İÇİNDEN.
  ///
  /// Gerekçesi `memory_dao.dart`taki aynı adlı fonksiyonun notunda.
  /// Anı bağları tombstone'lananlar dâhil gövdeye giriyor.
  Future<void> _enqueue(
    String collectionId, {
    required OutboxOperation op,
    required int baseVersion,
    required String outboxId,
    required DateTime now,
  }) async {
    final row = await (select(
      collections,
    )..where((t) => t.id.equals(collectionId))).getSingleOrNull();
    if (row == null) return;

    final baglar = await (select(
      memoryCollections,
    )..where((t) => t.collectionId.equals(collectionId))).get();

    await OutboxDao(attachedDatabase).enqueue(
      id: outboxId,
      entityType: kCollectionEntityType,
      entityId: collectionId,
      op: op,
      payloadJson: encodeOutboxPayload(
        entity: outboxRowJson(row),
        links: {
          'memory_collections': [
            for (final link in baglar) outboxRowJson(link),
          ],
        },
      ),
      baseVersion: baseVersion,
      now: now,
    );
  }

  /// Koleksiyonun anı bağlarını verilen listeyle EŞİTLER — silmeden.
  ///
  /// Deseni ve gerekçesi `memory_dao.dart`taki "Bağ eşitleme" bölümünde:
  /// bağı gerçekten silersek ikinci cihaz onu geri ekler (rapor §1.1).
  Future<void> _replaceMemories(
    String collectionId,
    List<String> memoryIds,
    DateTime now,
  ) {
    return transaction(() async {
      final current = await (select(
        memoryCollections,
      )..where((t) => t.collectionId.equals(collectionId))).get();
      final byMemory = {for (final row in current) row.memoryId: row};

      for (final row in current) {
        if (row.deletedAt == null && !memoryIds.contains(row.memoryId)) {
          await (update(memoryCollections)..where(
                (t) =>
                    t.collectionId.equals(collectionId) &
                    t.memoryId.equals(row.memoryId),
              ))
              .write(
                MemoryCollectionsCompanion(
                  deletedAt: Value(now),
                  updatedAt: Value(now),
                  version: Value(row.version + 1),
                ),
              );
        }
      }

      for (final (index, memoryId) in memoryIds.indexed) {
        final existing = byMemory[memoryId];
        await into(memoryCollections).insertOnConflictUpdate(
          MemoryCollectionsCompanion.insert(
            memoryId: memoryId,
            collectionId: collectionId,
            // Kullanıcının formdaki sırası korunuyor. HER ZAMAN yazılıyor:
            // canlı bir bağın yeri değişmiş olabilir.
            sortOrder: Value(index),
            updatedAt: Value(now),
            deletedAt: const Value(null),
            version: Value((existing?.version ?? 0) + 1),
          ),
        );
      }
    });
  }
}
