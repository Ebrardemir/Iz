/// Bellekte çalışan sahte kategori deposu.
///
/// NEDEN GERÇEK DEPO DEĞİL? Gerekçesi `fake_collection_repository.dart`
/// başındaki notta.
///
/// VARSAYILAN İÇERİK, SİSTEM KATEGORİLERİ: gerçek veritabanı da ilk açılışta
/// bunları tohumluyor, yani "liste hiçbir zaman boş değil" sözü testte de
/// geçerli olsun.
library;

import 'dart:async';

import 'package:iz/core/result/result.dart';
import 'package:iz/features/categories/domain/entities/memory_category.dart';
import 'package:iz/features/categories/domain/repositories/category_repository.dart';

class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository([List<MemoryCategory>? categories])
    : _categories = categories ?? defaultSeed();

  /// Sistem kategorileri — `AppDatabase.onCreate`teki tohumun aynısı.
  static List<MemoryCategory> defaultSeed() => [
    for (final (index, category) in DefaultCategories.seed.indexed)
      MemoryCategory(
        id: category.id,
        // İSİM DEĞİL ANAHTAR: sistem kategorilerinin adı dile göre değişiyor.
        name: category.nameKey,
        iconKey: category.iconKey,
        sortOrder: index,
        isSystem: true,
      ),
  ];

  final List<MemoryCategory> _categories;

  @override
  Stream<Result<List<MemoryCategory>>> watchCategories() =>
      Stream.value(Ok(List.unmodifiable(_categories)));

  @override
  Future<Result<MemoryCategory?>> findCategory(String id) async {
    for (final category in _categories) {
      if (category.id == id) return Ok(category);
    }
    return const Ok(null);
  }
}
