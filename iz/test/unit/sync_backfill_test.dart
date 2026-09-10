/// Hesap açılmadan ÖNCE oluşturulmuş kayıtların kuyruğa taşınması.
///
/// BU DOSYADAKİ TESTLER YAYIN DURDURUCU. Doldurma çalışmazsa mevcut
/// kullanıcının bütün geçmişi sessizce yerelde kalır: uygulama sorunsuz
/// görünür, ikinci cihazda hiçbir şey yoktur ve sebebi hiçbir yerde yazmaz.
/// Yol haritası bunu "Faz 1'in en riskli parçası; testi ilk yazılacak
/// testtir" diye işaretlemiş.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/journal/domain/repositories/journal_repository.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/people/domain/repositories/person_repository.dart';
import 'package:iz/features/sync/data/daos/sync_backfill_dao.dart';

import '../helpers/fake_media_file_store.dart';
import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncBackfillDao dao;

  const sahip = 'kullanici-1';
  final simdi = DateTime.utc(2026, 9, 9, 12);

  setUp(() {
    db = createTestDatabase();
    dao = db.syncBackfillDao;
  });

  tearDown(() => db.close());

  Future<int> doldur() => dao.run(
    ownerId: sahip,
    now: simdi,
    nextOutboxId: SequentialIdGenerator(prefix: 'doldurma-').newId,
  );

  Future<List<OutboxEntryRow>> kuyruk() => db.select(db.outboxEntries).get();

  Future<void> kuyruguBosalt() => db.delete(db.outboxEntries).go();

  Map<String, Object?> zarf(OutboxEntryRow satir) =>
      jsonDecode(satir.payloadJson) as Map<String, Object?>;

  group('sinyal', () {
    test('TAZE kurulumda doldurma GEREKMİYOR', () async {
      // Taşınacak bir şey yok. Sistem kategorileri sayılmıyor: onlar cihaz
      // geneli satırlar ve sahipleri hiçbir zaman bir hesaba yazılmıyor
      // (yazsaydık aynı cihazdaki ikinci hesap hiç kategori göremezdi).
      expect(await dao.needsBackfill(), isFalse);
    });

    test('hesapsızken yazılmış kayıt varsa doldurma GEREKİYOR', () async {
      final repo = createTestRepository(db);
      await repo.saveDraft(
        MemoryDraft(occurredAt: kTestDatabaseNow, title: 'Hesapsız'),
      );

      expect(await dao.needsBackfill(), isTrue);
    });

    test('doldurmadan SONRA sinyal kapanıyor', () async {
      final repo = createTestRepository(db);
      await repo.saveDraft(
        MemoryDraft(occurredAt: kTestDatabaseNow, title: 'Hesapsız'),
      );
      expect(await dao.needsBackfill(), isTrue);

      await doldur();

      expect(await dao.needsBackfill(), isFalse);
    });

    test('ikinci çağrı kuyruğa YENİ satır eklemiyor', () async {
      final repo = createTestRepository(db);
      await repo.saveDraft(
        MemoryDraft(occurredAt: kTestDatabaseNow, title: 'Eski anı'),
      );
      await kuyruguBosalt();

      final ilk = await doldur();
      expect(ilk, greaterThan(0));

      final ikinci = await doldur();
      expect(ikinci, 0, reason: 'sinyal kapandığı için ikinci tur boş');
    });
  });

  group('sahiplik', () {
    test("'local' satırlara GERÇEK kimlik yazılıyor", () async {
      final repo = createTestRepository(db);
      await repo.saveDraft(
        MemoryDraft(occurredAt: kTestDatabaseNow, title: 'Hesapsız yazıldı'),
      );

      expect((await db.select(db.memories).getSingle()).ownerId, 'local');

      await doldur();

      expect((await db.select(db.memories).getSingle()).ownerId, sahip);

      // SİSTEM KATEGORİLERİ DOKUNULMADAN KALIYOR: cihaz geneli satırlar.
      // İlk giriş yapan hesaba yazsaydık aynı cihazdaki İKİNCİ hesap hiç
      // kategori göremezdi — sorgular sahibe göre süzülüyor.
      expect(
        (await db.select(db.categories).get()).every(
          (c) => c.ownerId == 'local',
        ),
        isTrue,
      );
    });

    test('updatedAt TAZELENMİYOR', () async {
      // Kaydın içeriği değişmedi, yalnız kime ait olduğu netleşti.
      // Tazeleseydik kullanıcının bütün anıları "bugün düzenlendi" görünürdü.
      final repo = createTestRepository(db);
      await repo.saveDraft(
        MemoryDraft(occurredAt: kTestDatabaseNow, title: 'Eski'),
      );
      final once = (await db.select(db.memories).getSingle()).updatedAt;

      await doldur();

      expect((await db.select(db.memories).getSingle()).updatedAt, once);
    });
  });

  group('kuyruğa taşıma', () {
    test('hesapsız yazılmış anı kuyruğa giriyor', () async {
      final repo = createTestRepository(db);
      await repo.saveDraft(
        MemoryDraft(occurredAt: kTestDatabaseNow, title: 'Hesapsız anı'),
      );

      // Kuyruk temizleniyor: senaryo "kayıt var ama kuyrukta izi yok".
      await kuyruguBosalt();
      await doldur();

      final ani = (await kuyruk()).where((r) => r.entityType == 'memory');
      expect(ani, hasLength(1));
      expect(ani.single.op.name, 'create');
      expect(ani.single.baseVersion, 0, reason: 'sunucuda hiç yok');
    });

    test('anının BAĞLARI da gövdeye giriyor', () async {
      final kisiRepo = createTestPersonRepository(db);
      final kisi = await kisiRepo.save(const PersonDraft(name: 'Kardeşim'));

      final repo = createTestRepository(db);
      await repo.saveDraft(
        MemoryDraft(
          occurredAt: kTestDatabaseNow,
          title: 'Bağlı anı',
          personIds: [kisi.valueOrNull!],
        ),
      );

      await kuyruguBosalt();
      await doldur();

      final ani = (await kuyruk()).firstWhere((r) => r.entityType == 'memory');
      final baglar = zarf(ani)['links']! as Map<String, Object?>;

      expect(baglar['memory_people'], hasLength(1));
    });

    test('ZATEN kuyrukta olan kayıt İKİNCİ kez eklenmiyor', () async {
      // İkinci satır `baseVersion: 0` ile gider ve tamamen uydurma bir
      // çakışma üretirdi.
      final repo = createTestRepository(db);
      await repo.saveDraft(
        MemoryDraft(occurredAt: kTestDatabaseNow, title: 'Zaten kuyrukta'),
      );

      final oncekiAniSayisi = (await kuyruk())
          .where((r) => r.entityType == 'memory')
          .length;

      await doldur();

      expect(
        (await kuyruk()).where((r) => r.entityType == 'memory').length,
        oncekiAniSayisi,
      );
    });

    test('SİLİNMİŞ kayıt gönderilmiyor', () async {
      // Sunucuda o kayıt hiç var olmadı; "silindi" demenin bir alıcısı yok.
      final repo = createTestRepository(db);
      final id = await repo.saveDraft(
        MemoryDraft(occurredAt: kTestDatabaseNow, title: 'Çöpe gidecek'),
      );
      await repo.moveToTrash(id.valueOrNull!);

      await kuyruguBosalt();
      await doldur();

      expect((await kuyruk()).where((r) => r.entityType == 'memory'), isEmpty);
    });

    test('SİSTEM KATEGORİLERİ gönderilmiyor', () async {
      // Kimlikleri sabit ve her cihazda aynı tohumlanıyor; göndermek her
      // kullanıcı için sekiz gereksiz satır olurdu.
      await doldur();

      expect(
        (await kuyruk()).where((r) => r.entityType == 'category'),
        isEmpty,
      );
    });

    test('medya ve konum da taşınıyor', () async {
      final medyaRepo = createTestMediaRepository(db, FakeMediaFileStore());
      final medya = await medyaRepo.importPicked(const ['/g/f.jpg']);

      final repo = createTestRepository(db);
      await repo.saveDraft(
        MemoryDraft(
          occurredAt: kTestDatabaseNow,
          title: 'Tam kayıt',
          locationLabel: 'Kapadokya',
          mediaIds: [medya.valueOrNull!.single.id],
        ),
      );

      await kuyruguBosalt();
      await doldur();

      final turler = (await kuyruk()).map((r) => r.entityType).toSet();
      expect(turler, containsAll(<String>['memory', 'location', 'media_item']));
    });

    test('medyanın CİHAZA ÖZGÜ alanları yine çıkarılıyor', () async {
      // Normal yazma yolundaki kuralın aynısı; ikisi ayrışırsa aynı kayıt
      // sunucuya iki farklı biçimde ulaşır.
      final medyaRepo = createTestMediaRepository(db, FakeMediaFileStore());
      await medyaRepo.importPicked(const ['/g/f.jpg']);

      await kuyruguBosalt();
      await doldur();

      final medya = (await kuyruk()).firstWhere(
        (r) => r.entityType == 'media_item',
      );
      final entity = zarf(medya)['entity']! as Map<String, Object?>;

      expect(entity.containsKey('local_preview_path'), isFalse);
      expect(entity.containsKey('gallery_asset_id'), isFalse);
    });
  });

  group('deviceOnly', () {
    test('cihazda kalacak günlük kaydı DOLDURMADA da gitmiyor', () async {
      // FR-035'te kullanıcıya verilmiş açık söz. Doldurma, o sözü tam da
      // fark edilmeyecek yerde bozabilecek tek yol.
      final gunlukRepo = createTestJournalRepository(db);
      await gunlukRepo.save(
        JournalDraft(
          entryDate: kTestDatabaseNow,
          text: 'Kimse görmesin',
          privacyMode: JournalPrivacyMode.deviceOnly,
        ),
      );
      await gunlukRepo.save(
        JournalDraft(entryDate: kTestDatabaseNow, text: 'Bu gidebilir'),
      );

      await kuyruguBosalt();
      await doldur();

      final gunlukler = (await kuyruk()).where(
        (r) => r.entityType == 'journal_entry',
      );

      expect(gunlukler, hasLength(1));

      final entity = zarf(gunlukler.single)['entity']! as Map<String, Object?>;
      expect(entity['content'], 'Bu gidebilir');
    });
  });
}
