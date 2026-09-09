/// Kuyruk KAPSAMI: hangi kayıt türleri sunucuya gidiyor?
///
/// NEDEN AYRI BİR TEST DOSYASI?
/// Bu, tek tek DAO'ların davranışı değil bir BÜTÜNLÜK sorusu: sunucu on dört
/// tür kabul ediyor, istemci kaçını gönderiyor? Eksik bir tür hiçbir testi
/// kırmıyor — yalnız ikinci cihazda yarım veri olarak görünüyor ve sebebi
/// aylarca anlaşılmıyor.
///
/// Nitekim bu dosya yazılmadan önce KONUM ve MEDYA hiç gönderilmiyordu: bir
/// anıya "Anneannemin bahçesi" yazan kullanıcı ikinci cihazında anıyı
/// konumsuz görüyordu.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';

import '../helpers/fake_media_file_store.dart';
import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<List<OutboxEntryRow>> kuyruk(String tur) async =>
      (await db.select(db.outboxEntries).get())
          .where((r) => r.entityType == tur)
          .toList();

  Map<String, Object?> govdesi(OutboxEntryRow satir) =>
      (jsonDecode(satir.payloadJson) as Map<String, Object?>)['entity']!
          as Map<String, Object?>;

  group('konum', () {
    test('anıya konum yazılınca KONUM da kuyruğa giriyor', () async {
      // Anı yalnız `locationId` taşıyor; satırın kendisi gönderilmezse
      // ikinci cihazda o kimlik hiçbir şeye karşılık gelmez.
      final repo = createTestRepository(db);

      await repo.saveDraft(
        MemoryDraft(
          occurredAt: kTestDatabaseNow,
          title: 'Bahçedeki gün',
          locationLabel: 'Anneannemin bahçesi',
        ),
      );

      final satirlar = await kuyruk('location');
      expect(satirlar, hasLength(1));
      expect(govdesi(satirlar.single)['label'], 'Anneannemin bahçesi');
    });

    test('aynı etiket ikinci kez yazılınca YENİ satır açılmıyor', () async {
      // Var olan konum bulunuyor (findLocationByLabel); ikinci bir kuyruk
      // satırı, sunucuda da ikinci bir konum demek olurdu.
      final repo = createTestRepository(db);

      await repo.saveDraft(
        MemoryDraft(
          occurredAt: kTestDatabaseNow,
          title: 'Bir',
          locationLabel: 'Aynı yer',
        ),
      );
      await repo.saveDraft(
        MemoryDraft(
          occurredAt: kTestDatabaseNow,
          title: 'İki',
          locationLabel: 'Aynı yer',
        ),
      );

      expect(await kuyruk('location'), hasLength(1));
    });

    test('konumsuz anı konum satırı üretmiyor', () async {
      final repo = createTestRepository(db);
      await repo.saveDraft(
        MemoryDraft(occurredAt: kTestDatabaseNow, title: 'Konumsuz'),
      );

      expect(await kuyruk('location'), isEmpty);
    });
  });

  group('medya', () {
    test('içe aktarılan medya kuyruğa giriyor', () async {
      final repo = createTestMediaRepository(db, FakeMediaFileStore());

      await repo.importPicked(const ['/galeri/foto.jpg']);

      final satirlar = await kuyruk('media_item');
      expect(satirlar, hasLength(1));
      expect(satirlar.single.op.name, 'create');
    });

    test('CİHAZA ÖZGÜ alanlar gövdeden ÇIKARILIYOR', () async {
      // Kullanıcının cihazındaki bir dosya yolunu ağa çıkarmanın hiçbir
      // gerekçesi yok; sunucuda sütunu bile yok (§4.6).
      final repo = createTestMediaRepository(db, FakeMediaFileStore());

      await repo.importPicked(const ['/galeri/foto.jpg']);

      final govde = govdesi((await kuyruk('media_item')).single);

      expect(govde.containsKey('local_preview_path'), isFalse);
      expect(govde.containsKey('gallery_asset_id'), isFalse);
      expect(govde.containsKey('last_verified_at'), isFalse);

      // Sunucunun BEKLEDİĞİ alanlar duruyor.
      expect(govde['type'], isNotNull);
      expect(govde['original_status'], isNotNull);
    });

    test('silme kuyruğa DELETE olarak giriyor', () async {
      final repo = createTestMediaRepository(db, FakeMediaFileStore());
      final iceAktarilan = await repo.importPicked(const ['/g/f.jpg']);
      final id = iceAktarilan.valueOrNull!.single.id;

      await repo.delete(id);

      final silme = (await kuyruk(
        'media_item',
      )).where((r) => r.op.name == 'delete');
      expect(silme, hasLength(1));
    });

    test('ORİJİNAL DURUMU kuyruğa GİRMİYOR', () async {
      // Bu kontrolün cevabı cihaza özgü: A telefonunda orijinal duruyor
      // olabilirken B'de silinmiş olabilir. Gönderseydik iki cihaz aynı alanı
      // sırayla ezer, her eşitlemede birbirine "kayıp"/"duruyor" derdi.
      final store = FakeMediaFileStore();
      final repo = createTestMediaRepository(db, store);
      final iceAktarilan = await repo.importPicked(const ['/g/f.jpg']);
      final id = iceAktarilan.valueOrNull!.single.id;

      final oncekiSayi = (await kuyruk('media_item')).length;
      await repo.verify(id);

      expect(await kuyruk('media_item'), hasLength(oncekiSayi));
    });
  });

  group('kapsam', () {
    test('anı kaydı ilgili TÜM türleri kuyruğa koyuyor', () async {
      // Uçtan uca: bir anı + konumu + medyası. Üçü de gitmezse ikinci
      // cihazda anı yarım görünür.
      final medyaRepo = createTestMediaRepository(db, FakeMediaFileStore());
      final iceAktarilan = await medyaRepo.importPicked(const ['/g/f.jpg']);
      final medyaId = iceAktarilan.valueOrNull!.single.id;

      final repo = createTestRepository(db);
      await repo.saveDraft(
        MemoryDraft(
          occurredAt: kTestDatabaseNow,
          title: 'Tam kayıt',
          locationLabel: 'Kapadokya',
          mediaIds: [medyaId],
        ),
      );

      final turler = (await db.select(db.outboxEntries).get())
          .map((r) => r.entityType)
          .toSet();

      expect(turler, containsAll(<String>['memory', 'location', 'media_item']));
    });
  });

  group('saat', () {
    test('satır ve kuyruk AYNI ana damgalanıyor', () async {
      // DAO kendi saatini okusaydı ikisi milisaniyelerle ayrışırdı; sıralama
      // ve çakışma karşılaştırması o farka takılır.
      final repo = createTestMediaRepository(db, FakeMediaFileStore());
      await repo.importPicked(const ['/g/f.jpg']);

      final satir = (await db.select(db.mediaItems).get()).single;
      final kuyrukSatiri = (await kuyruk('media_item')).single;

      expect(kuyrukSatiri.createdAt, satir.updatedAt);
    });
  });
}
