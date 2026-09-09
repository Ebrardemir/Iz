/// Outbox DOLUYOR — Faz 2'nin çıkış kriteri.
///
/// NE SINANIYOR:
///   • her yazma yolu kuyruğa bir satır düşürüyor mu
///   • satır AYNI TRANSACTION'da mı yazılıyor (veri var, kuyruk yoksa kayıp)
///   • gövde bağları da taşıyor mu — tombstone'lananlar dâhil (rapor §1.1)
///
/// NE SINANMIYOR: kuyruğun BOŞALMASI. Motor Faz 3'te geliyor (TR-M13-01);
/// bugün kuyruğu okuyan kimse yok ve hiçbir veri cihazdan çıkmıyor.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/collections/domain/repositories/collection_repository.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/journal/domain/repositories/journal_repository.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/repositories/memory_repository.dart';
import 'package:iz/features/people/domain/repositories/person_repository.dart';
import 'package:iz/features/rituals/domain/repositories/ritual_repository.dart';
import 'package:iz/features/sync/domain/entities/outbox_operation.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MemoryRepository memories;
  late PersonRepository people;
  late CollectionRepository collections;
  late RitualRepository rituals;
  late JournalRepository journal;

  setUp(() {
    db = createTestDatabase();
    memories = createTestRepository(db);
    people = createTestPersonRepository(db);
    collections = createTestCollectionRepository(db);
    rituals = createTestRitualRepository(db);
    journal = createTestJournalRepository(db);
  });

  tearDown(() async => db.close());

  Future<List<OutboxEntryRow>> kuyruk() => db.select(db.outboxEntries).get();

  Map<String, Object?> govde(OutboxEntryRow row) =>
      jsonDecode(row.payloadJson) as Map<String, Object?>;

  Future<String> yeniAni({List<String> personIds = const []}) async {
    final result = await memories.saveDraft(
      MemoryDraft(
        occurredAt: DateTime(2026, 3, 12),
        title: 'Kahve Molası',
        personIds: personIds,
      ),
    );
    return result.valueOrNull!;
  }

  group('kuyruk doluyor', () {
    test('yeni anı CREATE olarak kuyruğa giriyor', () async {
      final id = await yeniAni();

      final satirlar = await kuyruk();
      expect(satirlar, hasLength(1));
      expect(satirlar.single.entityType, 'memory');
      expect(satirlar.single.entityId, id);
      expect(satirlar.single.op, OutboxOperation.create);
      // Yeni kayıt hiçbir sürümün üstüne yazmıyor.
      expect(satirlar.single.baseVersion, 0);
      expect(satirlar.single.attemptCount, 0);
      expect(satirlar.single.lastError, isNull);
    });

    test('düzenleme UPDATE, silme DELETE olarak giriyor', () async {
      final id = await yeniAni();
      await memories.saveDraft(
        MemoryDraft(
          id: id,
          occurredAt: DateTime(2026, 3, 12),
          title: 'Kahve Molası — düzeltildi',
        ),
      );
      await memories.moveToTrash(id);

      final satirlar = await kuyruk();
      expect(satirlar.map((e) => e.op), [
        OutboxOperation.create,
        OutboxOperation.update,
        OutboxOperation.delete,
      ]);

      // `baseVersion` her adımda bir önceki sürüm: sunucu bununla araya
      // birinin girip girmediğini anlıyor (TR-M13-10).
      expect(satirlar.map((e) => e.baseVersion), [0, 1, 2]);
    });

    test('KİMLİKLER BENZERSİZ — her satır kendi Idempotency-Key\'i', () async {
      // TR-M13-04: yeniden denemede AYNI anahtar gidiyor. İki değişiklik
      // aynı anahtarı paylaşsaydı sunucu ikincisini "tekrar" sanıp atardı.
      final id = await yeniAni();
      await memories.setFavorite(id, isFavorite: true);
      await memories.setArchived(id, isArchived: true);

      final kimlikler = (await kuyruk()).map((e) => e.id).toSet();
      expect(kimlikler, hasLength(3));
    });

    test('kişi, koleksiyon, seri ve günlük de kuyruğa giriyor', () async {
      await people.save(const PersonDraft(name: 'Annem'));
      await collections.save(const CollectionDraft(title: 'Yaz'));
      await rituals.save(const RitualDraft(title: 'Aile Yemeklerimiz'));
      await journal.save(
        JournalDraft(entryDate: DateTime(2026, 3, 12), text: 'Bugün.'),
      );

      final tipler = (await kuyruk()).map((e) => e.entityType).toList();
      expect(tipler, ['person', 'collection', 'ritual', 'journal_entry']);
    });
  });

  group('gövde', () {
    test('anının gövdesi satırın kendisi — domain nesnesi değil', () async {
      await yeniAni();

      final entity =
          govde((await kuyruk()).single)['entity']! as Map<String, Object?>;
      // Sütun adları: gövde satırdan üretiliyor.
      expect(entity['title'], 'Kahve Molası');
      expect(entity, contains('occurred_year'));
      expect(entity, contains('version'));
    });

    test('ÇIKARILAN KİŞİ gövdede tombstone olarak gidiyor', () async {
      // Rapor §1.1'in kalbi: yalnız canlı bağları gönderseydik sunucu
      // "eksik olan henüz gelmemiş" ile "eksik olan silinmiş"i ayırt
      // edemez, ikinci cihaz çıkarılan kişiyi geri eklerdi.
      final kisiId = (await people.save(
        const PersonDraft(name: 'Annem'),
      )).valueOrNull!;
      final aniId = await yeniAni(personIds: [kisiId]);

      await memories.saveDraft(
        MemoryDraft(
          id: aniId,
          occurredAt: DateTime(2026, 3, 12),
          title: 'Kahve Molası',
        ),
      );

      final sonAni = (await kuyruk())
          .where((e) => e.entityType == 'memory')
          .last;
      final links = govde(sonAni)['links']! as Map<String, Object?>;
      final kisiBaglari = links['memory_people']! as List<Object?>;

      expect(kisiBaglari, hasLength(1), reason: 'bağ gövdeden düşmüş');
      final bag = kisiBaglari.single! as Map<String, Object?>;
      expect(bag['person_id'], kisiId);
      expect(
        bag['deleted_at'],
        isNotNull,
        reason: 'tombstone gövdeye "silinmiş" olarak girmemiş',
      );
    });

    test('gövde SÜRÜM ETİKETİ taşıyor', () async {
      // Kuyruk uygulama güncellemesinden sağ çıkıyor; biçim değişirse
      // okuyan taraf bunu buradan anlar.
      await yeniAni();
      expect(govde((await kuyruk()).single)['v'], 1);
    });
  });

  group('gizlilik — TR-M3-02 / FR-035', () {
    // YAYIN DURDURUCU (TRD → Ek B, TR-B-01): "`deviceOnly` kayıt outbox'a
    // girmiyor". Bu testler kırmızıysa sürüm çıkmaz.

    Future<String> gunlukYaz({
      required JournalPrivacyMode mod,
      String? id,
      String text = 'Kimseye söylemedim.',
    }) async {
      final r = await journal.save(
        JournalDraft(
          id: id,
          entryDate: DateTime(2026, 3, 12),
          text: text,
          privacyMode: mod,
        ),
      );
      return r.valueOrNull!;
    }

    test('baştan deviceOnly olan kayıt kuyruğa HİÇ girmiyor', () async {
      await gunlukYaz(mod: JournalPrivacyMode.deviceOnly);
      expect(await kuyruk(), isEmpty);
    });

    test('deviceOnly kayıt DÜZENLENİNCE de kuyruğa girmiyor', () async {
      final id = await gunlukYaz(mod: JournalPrivacyMode.deviceOnly);
      await gunlukYaz(
        id: id,
        mod: JournalPrivacyMode.deviceOnly,
        text: 'Yeniden yazdım.',
      );
      expect(await kuyruk(), isEmpty);
    });

    test('deviceOnly kayıt SİLİNİNCE de kuyruğa girmiyor', () async {
      final id = await gunlukYaz(mod: JournalPrivacyMode.deviceOnly);
      await journal.softDelete(id);
      expect(await kuyruk(), isEmpty);
    });

    test('deviceOnly kayıt YILDIZLANINCA da kuyruğa girmiyor', () async {
      final id = await gunlukYaz(mod: JournalPrivacyMode.deviceOnly);
      await journal.setFavorite(id, isFavorite: true);
      expect(await kuyruk(), isEmpty);
    });

    test('standard → deviceOnly çevrilince SİLME düşüyor', () async {
      // Kayıt daha önce senkronize edilebilirdi, yani sunucuda bir kopyası
      // olabilir. Hiçbir şey yazmasaydık o kopya orada kalır ve kullanıcı
      // "bu cihazda kalsın" dediği hâlde veri buluttan silinmezdi.
      final id = await gunlukYaz(mod: JournalPrivacyMode.standard);
      await gunlukYaz(id: id, mod: JournalPrivacyMode.deviceOnly);

      final satirlar = await kuyruk();
      expect(satirlar, hasLength(2));
      expect(satirlar.last.op, OutboxOperation.delete);
    });

    test('o SİLME isteği METNİ TAŞIMIYOR', () async {
      // Tam gövdeyi koysaydık, "bu cihazda kalsın" denen metni silme
      // isteğinin İÇİNDE buluta göndermiş olurduk.
      final id = await gunlukYaz(mod: JournalPrivacyMode.standard);
      await gunlukYaz(
        id: id,
        mod: JournalPrivacyMode.deviceOnly,
        text: 'ÇOK GİZLİ',
      );

      final silme = (await kuyruk()).last;
      expect(silme.payloadJson, isNot(contains('GİZLİ')));

      final entity = govde(silme)['entity']! as Map<String, Object?>;
      expect(entity.keys, ['id']);
      expect(entity['id'], id);
    });

    test('deviceOnly → standard çevrilince NORMAL yoldan gidiyor', () async {
      // Kullanıcı fikrini değiştirdi; artık senkronize edilebilir.
      final id = await gunlukYaz(mod: JournalPrivacyMode.deviceOnly);
      await gunlukYaz(id: id, mod: JournalPrivacyMode.standard);

      final satirlar = await kuyruk();
      expect(satirlar, hasLength(1));
      expect(satirlar.single.op, OutboxOperation.update);
      expect(govde(satirlar.single), contains('entity'));
    });
  });

  group('atomiklik', () {
    test('veri ve kuyruk satırı AYNI ANDA var oluyor', () async {
      // Ayrı transaction olsaydı ikisinin arasında çöken bir uygulama
      // değişikliği kalıcı olarak kaybederdi (TR-M13-01).
      final id = await yeniAni();

      final ani = await (db.select(
        db.memories,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      expect(ani, isNotNull);
      expect((await kuyruk()).single.entityId, id);
    });

    test('OLMAYAN kayda dokunmak kuyruğa satır DÜŞÜRMÜYOR', () async {
      // Silinmiş bir kişiye favori işaretlemek anlamsız bir istek; sunucuya
      // gönderilecek bir değişiklik yok.
      await memories.setFavorite('yok-boyle-bir-ani', isFavorite: true);
      expect(await kuyruk(), isEmpty);
    });
  });
}
