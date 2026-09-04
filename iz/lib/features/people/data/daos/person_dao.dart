/// Kişi veri erişim nesnesi (DAO).
///
/// SORUMLULUĞU: SQL. Sadece SQL.
/// Burada iş kuralı YOK, domain tipi YOK, `Result` YOK — gerekçesi
/// `memory_dao.dart` başındaki notta.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/people/data/tables/person_tables.dart';

part 'person_dao.g.dart';

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
    return (select(people)
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
      select(people)..where((t) => t.id.equals(id) & t.deletedAt.isNull());

  /// Oluşturur veya günceller.
  ///
  /// `version` YAZAN TARAF artırır (TR-C-31). Bunu DAO'da yapıyoruz çünkü
  /// tek yazma yolu burası; çağıran tarafa bırakılsaydı bir gün biri
  /// unuturdu ve o kayıt senkronizasyonda "değişmemiş" görünürdü.
  Future<void> upsertPerson(PeopleCompanion person) async {
    final id = person.id.value;
    final current = await (select(
      people,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    await into(people).insertOnConflictUpdate(
      person.copyWith(
        updatedAt: Value(DateTime.now()),
        version: Value((current?.version ?? 0) + 1),
      ),
    );
  }

  /// TR-C-32 — tombstone. Satır silinmiyor, işaretleniyor.
  Future<void> softDelete(String id) => _patch(
    id,
    (row) => PeopleCompanion(
      deletedAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
      version: Value(row.version + 1),
    ),
  );

  Future<void> setFavorite(String id, {required bool isFavorite}) => _patch(
    id,
    (row) => PeopleCompanion(
      isFavorite: Value(isFavorite),
      updatedAt: Value(DateTime.now()),
      version: Value(row.version + 1),
    ),
  );

  /// Var olan satırı okuyup üzerine yazar.
  ///
  /// Okumadan güncelleyemiyoruz çünkü `version`ı bir artırmak için mevcut
  /// değeri bilmek gerekiyor. Kayıt yoksa sessizce hiçbir şey yapılmıyor:
  /// silinmiş bir kişiye favori işaretlemek hata değil, anlamsız bir istek.
  Future<void> _patch(
    String id,
    PeopleCompanion Function(PersonRow current) build,
  ) {
    return transaction(() async {
      final current = await (select(
        people,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (current == null) return;

      await (update(
        people,
      )..where((t) => t.id.equals(id))).write(build(current));
    });
  }
}
