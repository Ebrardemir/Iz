/// Kişi veri erişim nesnesi (DAO).
///
/// SORUMLULUĞU: SQL. Sadece SQL.
/// Burada iş kuralı YOK, domain tipi YOK, `Result` YOK — gerekçesi
/// `memory_dao.dart` başındaki notta.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/people/data/tables/person_tables.dart';
import 'package:iz/features/sync/data/daos/outbox_dao.dart';
import 'package:iz/features/sync/data/outbox_payload.dart';
import 'package:iz/features/sync/domain/entities/outbox_operation.dart';

part 'person_dao.g.dart';

/// Kişinin outbox'taki karşılığı — sunucu bu adla tanıyor.
/// Sabit ve DEĞİŞMEZ: bekleyen eski kuyruk satırları bu adı taşıyor.
const kPersonEntityType = 'person';

@DriftAccessor(tables: [People])
class PersonDao extends DatabaseAccessor<AppDatabase> with _$PersonDaoMixin {
  PersonDao(super.db);

  /// FR-060 — kişi listesi.
  ///
  /// SIRALAMA: favoriler önce, sonra ada göre. Kullanıcının "yakınları"
  /// listenin başında olsun; alfabetik tek başına kişisel bir listede
  /// anlamsız bir düzen.
  ///
  /// `deletedAt IS NULL` filtresi ZORUNLU (TR-C-32): silme tombstone olduğu
  /// için satır tabloda kalmaya devam ediyor. Filtreyi unutan bir sorgu
  /// silinmiş kişiyi ekranda gösterir.
  Stream<List<PersonRow>> watchPeople() {
    return (selectOwned(people, people.ownerId)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.isFavorite),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  Stream<PersonRow?> watchPerson(String id) => _byId(id).watchSingleOrNull();

  Future<PersonRow?> findPerson(String id) => _byId(id).getSingleOrNull();

  SimpleSelectStatement<$PeopleTable, PersonRow> _byId(String id) =>
      selectOwned(people, people.ownerId)
        ..where((t) => t.id.equals(id) & t.deletedAt.isNull());

  /// Oluşturur veya günceller.
  ///
  /// `version` YAZAN TARAF artırır (TR-C-31). Bunu DAO'da yapıyoruz çünkü
  /// tek yazma yolu burası; çağıran tarafa bırakılsaydı bir gün biri
  /// unuturdu ve o kayıt senkronizasyonda "değişmemiş" görünürdü.
  Future<void> upsertPerson(
    PeopleCompanion person, {
    // TR-C-41 — saat dışarıdan; TR-M13-01 — kuyruk satırının kimliği
    // çağırandan (`IdGenerator` DAO'nun bağımlılığı değil).
    required DateTime now,
    required String outboxId,
  }) {
    return transaction(() async {
      final id = person.id.value;
      final current = await (selectOwned(
        people,
        people.ownerId,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      await into(people).insertOnConflictUpdate(
        person.copyWith(
          updatedAt: Value(now),
          version: Value((current?.version ?? 0) + 1),
          // Sahip YAZMA ANINDA damgalanıyor; gerekçesi `activeOwnerId`de.
          ownerId: Value(activeOwnerId),
        ),
      );

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
  Future<void> softDelete(
    String id, {
    required DateTime now,
    required String outboxId,
  }) => _patch(
    id,
    (row) => PeopleCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
      version: Value(row.version + 1),
    ),
    now: now,
    outboxId: outboxId,
    // Sunucuya "sil" diye gitmezse ikinci cihaz silmeyi hiç öğrenmez.
    op: OutboxOperation.delete,
  );

  Future<void> setFavorite(
    String id, {
    required bool isFavorite,
    required DateTime now,
    required String outboxId,
  }) => _patch(
    id,
    (row) => PeopleCompanion(
      isFavorite: Value(isFavorite),
      updatedAt: Value(now),
      version: Value(row.version + 1),
    ),
    now: now,
    outboxId: outboxId,
  );

  /// Değişikliği outbox'a düşürür — AYNI TRANSACTION İÇİNDEN.
  ///
  /// Gerekçesi `memory_dao.dart`taki aynı adlı fonksiyonun notunda.
  /// Kişinin bağ tablosu yok: anı ↔ kişi bağı ANININ gövdesiyle gidiyor.
  Future<void> _enqueue(
    String personId, {
    required OutboxOperation op,
    required int baseVersion,
    required String outboxId,
    required DateTime now,
  }) async {
    final row = await (selectOwned(
      people,
      people.ownerId,
    )..where((t) => t.id.equals(personId))).getSingleOrNull();
    if (row == null) return;

    await OutboxDao(attachedDatabase).enqueue(
      id: outboxId,
      entityType: kPersonEntityType,
      entityId: personId,
      op: op,
      payloadJson: encodeOutboxPayload(entity: outboxRowJson(row)),
      baseVersion: baseVersion,
      now: now,
    );
  }

  /// Var olan satırı okuyup üzerine yazar.
  ///
  /// Okumadan güncelleyemiyoruz çünkü `version`ı bir artırmak için mevcut
  /// değeri bilmek gerekiyor. Kayıt yoksa sessizce hiçbir şey yapılmıyor:
  /// silinmiş bir kişiye favori işaretlemek hata değil, anlamsız bir istek.
  Future<void> _patch(
    String id,
    PeopleCompanion Function(PersonRow current) build, {
    required DateTime now,
    required String outboxId,
    OutboxOperation op = OutboxOperation.update,
  }) {
    return transaction(() async {
      final current = await (selectOwned(
        people,
        people.ownerId,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (current == null) return;

      await (update(people)
            ..where((t) => t.id.equals(id) & ownedBy(people.ownerId)))
          .write(build(current));

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
