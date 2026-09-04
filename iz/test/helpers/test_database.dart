/// Test yardımcıları.
///
/// ÖNEMLİ TEKNİK: Drift'i **bellek içi** çalıştırıyoruz. Bu sayede
/// DAO ve repository testleri mock'suz, gerçek SQL ile koşar —
/// yani sorgularının gerçekten çalıştığını doğrularsın. Mock ile
/// yazılan repository testi sadece "mock'u doğru çağırdım mı"yı ölçer.
library;

import 'package:drift/native.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/repositories/memory_repository.dart';
import 'package:iz/features/people/data/repositories/person_repository_impl.dart';
import 'package:iz/features/people/domain/repositories/person_repository.dart';

/// Her test için taze, boş bir veritabanı.
///
/// `setUp` içinde çağır, `tearDown` içinde `db.close()` yap.
AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      // Foreign key'ler bellek içi veritabanında da açık olmalı,
      // yoksa cascade davranışını test edemezsin.
      setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON'),
    ),
  );
}

/// Sabit saat ve tahmin edilebilir id'lerle repository kurar.
///
/// Testte `DateTime.now()` ve rastgele UUID kullanmak, doğrulama
/// yazmayı imkânsız hâle getirir. Bunları enjekte ediyoruz.
MemoryRepository createTestRepository(AppDatabase db, {DateTime? now}) {
  return MemoryRepositoryImpl(
    database: db,
    idGenerator: SequentialIdGenerator(prefix: 'mem-'),
    clock: FixedClock(now ?? DateTime(2026, 7, 26, 12)),
  );
}

/// Kişi deposunu tahmin edilebilir kimliklerle kurar.
PersonRepository createTestPersonRepository(AppDatabase db) {
  return PersonRepositoryImpl(
    dao: db.personDao,
    idGenerator: SequentialIdGenerator(prefix: 'kisi-'),
  );
}
