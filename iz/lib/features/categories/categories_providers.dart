/// Kategoriler feature'ının DIŞARI AÇILAN yüzü.
///
/// NEDEN AYRI DOSYA?
/// Anı formu ve takvim kategori adını gösteriyor ama kategorilerin İÇİNİ
/// (DAO, uygulama sınıfı) görmemeli (ARCHITECTURE.md §2 / TR-C-03).
/// Medya, kişiler, koleksiyonlar ve serilerde de aynı kapı var; desen bu.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/categories/data/repositories/category_repository_impl.dart';
import 'package:iz/features/categories/domain/repositories/category_repository.dart';

/// Domain arayüzü üzerinden veriyoruz: çağıranlar `CategoryRepositoryImpl`i
/// değil `CategoryRepository`yi görür.
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(
    dao: ref.watch(appDatabaseProvider).categoryDao,
  );
});
