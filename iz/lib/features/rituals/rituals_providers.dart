/// Seriler feature'ının DIŞARI AÇILAN yüzü.
///
/// NEDEN AYRI DOSYA?
/// Anı formu "bu anı hangi seriye ait?" diye soruyor ve composition root
/// serileri anılarıyla birleştiriyor — ikisi de serinin İÇİNİ değil, yalnız
/// sözleşmesini tanımalı (ARCHITECTURE.md §2 / TR-C-03).
///
/// Medya, kişiler ve koleksiyonlar tarafında da aynı kapı var; desen bu.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/rituals/data/repositories/ritual_repository_impl.dart';
import 'package:iz/features/rituals/domain/repositories/ritual_repository.dart';

/// Domain arayüzü üzerinden veriyoruz: çağıranlar `RitualRepositoryImpl`i
/// değil `RitualRepository`yi görür.
final ritualRepositoryProvider = Provider<RitualRepository>((ref) {
  return RitualRepositoryImpl(
    dao: ref.watch(appDatabaseProvider).ritualDao,
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});
