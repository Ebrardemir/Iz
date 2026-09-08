/// Koleksiyonlar feature'ının DIŞARI AÇILAN yüzü.
///
/// NEDEN AYRI DOSYA?
/// Anı formu "bu anı hangi koleksiyona girsin?" diye soruyor ve composition
/// root koleksiyonları anılarıyla birleştiriyor — ikisi de koleksiyonun
/// İÇİNİ değil, yalnız sözleşmesini tanımalı (ARCHITECTURE.md §2 / TR-C-03).
///
/// Medya ve kişiler tarafında da aynı kapı var; desen bu.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/collections/data/repositories/collection_repository_impl.dart';
import 'package:iz/features/collections/domain/repositories/collection_repository.dart';

/// Domain arayüzü üzerinden veriyoruz: çağıranlar
/// `CollectionRepositoryImpl`i değil `CollectionRepository`yi görür.
final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return CollectionRepositoryImpl(
    dao: ref.watch(appDatabaseProvider).collectionDao,
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});
