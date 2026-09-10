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
    return (_kapsam()
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<CategoryRow?> findCategory(String id) =>
      (_kapsam()..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
          .getSingleOrNull();

  /// Aktif hesabın gördüğü kategoriler.
  ///
  /// SİSTEM KATEGORİLERİ HERKESE AÇIK — bilinçli. Kimlikleri sabit
  /// (`cat_travel`…), her kurulumda aynı tohumlanıyorlar ve hiçbir zaman
  /// senkronize edilmiyorlar; yani kullanıcıya ait bir içerik taşımıyorlar.
  /// Onları da sahibe göre süzseydik aynı cihazda ikinci bir hesapla giriş
  /// yapan kullanıcı HİÇ kategori göremezdi ve anı kaydetme ekranı boş bir
  /// listeyle açılırdı.
  ///
  /// Kullanıcının KENDİ kategorisi (FR-071) sahibe göre süzülüyor. Böyle bir
  /// yazma yolu henüz yok ama süzgeç şimdiden doğru yerde duruyor.
  SimpleSelectStatement<$CategoriesTable, CategoryRow> _kapsam() =>
      select(categories)
        ..where((t) => ownedBy(categories.ownerId) | t.isSystem.equals(true));
}
