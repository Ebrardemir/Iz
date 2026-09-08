/// Kategori veri erişim nesnesi (DAO).
///
/// SORUMLULUĞU: SQL. Sadece SQL.
/// Burada iş kuralı YOK, domain tipi YOK, `Result` YOK — gerekçesi
/// `memory_dao.dart` başındaki notta.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/categories/data/tables/category_tables.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  /// FR-070 — kategori listesi.
  ///
  /// SIRALAMA `sortOrder`: sistem kategorileri tohumlanırken bu alana
  /// tanımlı bir düzen yazılıyor (bkz. `DefaultCategories.seed`). Alfabetik
  /// sıralasaydık o düzen kaybolurdu ve kullanıcı her dilde başka bir sıra
  /// görürdü — sistem kategorilerinin adı çeviriden geliyor.
  ///
  /// `deletedAt IS NULL` ZORUNLU (TR-C-32): silme tombstone.
  Stream<List<CategoryRow>> watchCategories() {
    return (select(categories)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<CategoryRow?> findCategory(String id) => (select(
    categories,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
}
