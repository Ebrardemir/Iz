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
import 'package:iz/features/collections/data/repositories/collection_repository_impl.dart';
import 'package:iz/features/collections/domain/repositories/collection_repository.dart';
import 'package:iz/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:iz/features/journal/domain/repositories/journal_repository.dart';
import 'package:iz/features/media/data/repositories/media_repository_impl.dart';
import 'package:iz/features/media/data/sources/media_file_store.dart';
import 'package:iz/features/media/domain/repositories/media_repository.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/repositories/memory_repository.dart';
import 'package:iz/features/people/data/repositories/person_repository_impl.dart';
import 'package:iz/features/people/domain/repositories/person_repository.dart';
import 'package:iz/features/rituals/data/repositories/ritual_repository_impl.dart';
import 'package:iz/features/rituals/domain/repositories/ritual_repository.dart';

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
    clock: FixedClock(now ?? kTestDatabaseNow),
  );
}

/// Testlerin ortak "şimdi"si.
///
/// Depolar artık saati enjekte alıyor (TR-C-41); hepsinin aynı ana
/// bakması, `updatedAt` karşılaştıran iddiaları tahmin edilebilir kılıyor.
final kTestDatabaseNow = DateTime(2026, 7, 26, 12);

/// Kişi deposunu tahmin edilebilir kimliklerle kurar.
PersonRepository createTestPersonRepository(AppDatabase db) {
  return PersonRepositoryImpl(
    dao: db.personDao,
    idGenerator: SequentialIdGenerator(prefix: 'kisi-'),
    clock: FixedClock(kTestDatabaseNow),
  );
}

/// Koleksiyon deposunu tahmin edilebilir kimliklerle kurar.
CollectionRepository createTestCollectionRepository(AppDatabase db) {
  return CollectionRepositoryImpl(
    dao: db.collectionDao,
    idGenerator: SequentialIdGenerator(prefix: 'kol-'),
    // SABİT SAAT: `updatedAt` artık depodan geliyor ve testin gerçek saatle
    // koşması iddiaları tahmin edilemez kılardı (TR-C-41).
    clock: FixedClock(kTestDatabaseNow),
  );
}

/// Medya deposunu SAHTE dosya sistemiyle kurar.
///
/// Dosya işlemleri dışarıdan geliyor: testin gerçek diske yazması koşuları
/// birbirine karıştırır ve `getApplicationDocumentsDirectory` eklenti ister.
MediaRepository createTestMediaRepository(
  AppDatabase db,
  MediaFileStore fileStore, {
  DateTime? now,
}) {
  return MediaRepositoryImpl(
    dao: db.mediaDao,
    fileStore: fileStore,
    idGenerator: SequentialIdGenerator(prefix: 'medya-'),
    clock: FixedClock(now ?? DateTime(2026, 7, 26, 12)),
  );
}

/// Günlük deposunu tahmin edilebilir kimliklerle kurar.
JournalRepository createTestJournalRepository(AppDatabase db) {
  return JournalRepositoryImpl(
    dao: db.journalDao,
    idGenerator: SequentialIdGenerator(prefix: 'gunluk-'),
    clock: FixedClock(kTestDatabaseNow),
  );
}

/// Seri deposunu tahmin edilebilir kimliklerle kurar.
RitualRepository createTestRitualRepository(AppDatabase db) {
  return RitualRepositoryImpl(
    dao: db.ritualDao,
    idGenerator: SequentialIdGenerator(prefix: 'seri-'),
    clock: FixedClock(kTestDatabaseNow),
  );
}
