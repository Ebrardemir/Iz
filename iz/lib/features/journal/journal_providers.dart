/// Günlük feature'ının DIŞARI AÇILAN yüzü.
///
/// NEDEN AYRI DOSYA?
/// Ana sayfa günlük SAYACINI gösteriyor ama günlüğün İÇİNİ (DAO, uygulama
/// sınıfı) görmemeli (ARCHITECTURE.md §2 / TR-C-03). Öteki feature'larda da
/// aynı kapı var; desen bu.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:iz/features/journal/domain/repositories/journal_repository.dart';

/// Domain arayüzü üzerinden veriyoruz: çağıranlar `JournalRepositoryImpl`i
/// değil `JournalRepository`yi görür.
final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepositoryImpl(
    dao: ref.watch(appDatabaseProvider).journalDao,
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});
