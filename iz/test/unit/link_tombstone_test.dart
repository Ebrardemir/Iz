/// Bağ tabloları SİLMİYOR, tombstone bırakıyor — şema v8, TR-M2-01.
///
/// NEDEN AYRI BİR DOSYA?
/// Bu kural tek bir feature'ın işi değil: anı↔kişi, anı↔koleksiyon,
/// anı↔seri, anı↔medya, seri↔kişi ve günlük↔medya bağlarının HEPSİ aynı
/// sözü veriyor. Kuralı bir arada sınamak, yarısına uygulanıp yarısına
/// unutulmasını engelliyor.
///
/// NEDEN ÖNEMLİ (rapor §1.1):
/// Bağı gerçekten silersek ikinci cihaz o satırı hiç görmez ve "bende var,
/// sende yok" durumunu "sen henüz almamışsın" diye okur — çıkarılan kişiyi
/// geri ekler. Kullanıcı anıdan kişiyi çıkarır, bir sonraki eşitlemede kişi
/// geri gelir. Bu testler o senaryonun ön koşulunu koruyor.
///
/// GERÇEK SQLite üzerinde koşuyor: iddiaların yarısı tam da Drift'in
/// ürettiği SQL hakkında.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/collections/domain/repositories/collection_repository.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';
import 'package:iz/features/memories/domain/repositories/memory_repository.dart';
import 'package:iz/features/people/domain/repositories/person_repository.dart';
import 'package:iz/features/rituals/domain/repositories/ritual_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MemoryRepository memories;
  late PersonRepository people;
  late CollectionRepository collections;
  late RitualRepository rituals;

  setUp(() {
    db = createTestDatabase();
    memories = createTestRepository(db);
    people = createTestPersonRepository(db);
    collections = createTestCollectionRepository(db);
    rituals = createTestRitualRepository(db);
  });

  tearDown(() async => db.close());

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

  Future<String> yeniKisi(String ad) async {
    final result = await people.save(PersonDraft(name: ad));
    return result.valueOrNull!;
  }

  group('anı ↔ kişi', () {
    test('kişi çıkarılınca satır SİLİNMİYOR, tombstone oluyor', () async {
      final kisiId = await yeniKisi('Annem');
      final aniId = await yeniAni(personIds: [kisiId]);

      // Kişiyi çıkar.
      await memories.saveDraft(
        MemoryDraft(
          id: aniId,
          occurredAt: DateTime(2026, 3, 12),
          title: 'Kahve Molası',
        ),
      );

      final satirlar = await db.select(db.memoryPeople).get();
      expect(
        satirlar,
        hasLength(1),
        reason:
            'satır silinmiş. Silinirse ikinci cihaz bağın kaldırıldığını hiç '
            'öğrenemez ve kişiyi geri ekler (rapor §1.1).',
      );
      expect(satirlar.single.deletedAt, isNotNull);
      // TR-C-31 — her yazmada +1.
      expect(satirlar.single.version, greaterThan(1));
    });

    test('tombstone bağ EKRANDA görünmüyor', () async {
      final kisiId = await yeniKisi('Annem');
      final aniId = await yeniAni(personIds: [kisiId]);
      await memories.saveDraft(
        MemoryDraft(
          id: aniId,
          occurredAt: DateTime(2026, 3, 12),
          title: 'Kahve Molası',
        ),
      );

      // Detay ekranı.
      final detay = await memories.findDetail(aniId);
      expect(detay.valueOrNull!.people, isEmpty);

      // Kişiye göre süzgeç — kişi yaşam çizgisi bunu kullanıyor.
      final suzulmus = await memories
          .watchMemories(MemoryFilter(personIds: {kisiId}))
          .first;
      expect(suzulmus.valueOrNull, isEmpty);

      // Liste kartındaki kişi sayacı.
      final liste = await memories.watchMemories(const MemoryFilter()).first;
      expect(liste.valueOrNull!.single.personCount, 0);
    });

    test('aynı kişi geri eklenince bağ DİRİLİYOR', () async {
      // Yeni bir satır AÇILAMAZ: birincil anahtar `(memoryId, personId)`.
      // Diriltmeseydik "UNIQUE constraint failed" ile çökerdi.
      final kisiId = await yeniKisi('Annem');
      final aniId = await yeniAni(personIds: [kisiId]);

      await memories.saveDraft(
        MemoryDraft(
          id: aniId,
          occurredAt: DateTime(2026, 3, 12),
          title: 'Kahve Molası',
        ),
      );
      await memories.saveDraft(
        MemoryDraft(
          id: aniId,
          occurredAt: DateTime(2026, 3, 12),
          title: 'Kahve Molası',
          personIds: [kisiId],
        ),
      );

      final satirlar = await db.select(db.memoryPeople).get();
      expect(satirlar, hasLength(1));
      expect(satirlar.single.deletedAt, isNull, reason: 'bağ dirilmedi');

      final detay = await memories.findDetail(aniId);
      expect(detay.valueOrNull!.people.single.name, 'Annem');
    });
  });

  group('anı ↔ koleksiyon', () {
    test('koleksiyondan çıkarılan anı tombstone oluyor', () async {
      final aniId = await yeniAni();
      final kolId = (await collections.save(
        CollectionDraft(title: 'Yaz', memoryIds: [aniId]),
      )).valueOrNull!;

      await collections.save(
        CollectionDraft(id: kolId, title: 'Yaz', memoryIds: const []),
      );

      final satirlar = await db.select(db.memoryCollections).get();
      expect(satirlar, hasLength(1));
      expect(satirlar.single.deletedAt, isNotNull);

      // Koleksiyon detayı artık anıyı göstermiyor.
      final baglar = await collections.watchMemoryLinks().first;
      expect(baglar.valueOrNull![kolId] ?? const [], isEmpty);
    });
  });

  group('seri ↔ kişi', () {
    test('seriden çıkarılan kişi tombstone oluyor ve görünmüyor', () async {
      final kisiId = await yeniKisi('Babam');
      final seriId = (await rituals.save(
        RitualDraft(title: 'Aile Yemeklerimiz', personIds: {kisiId}),
      )).valueOrNull!;

      await rituals.save(
        RitualDraft(
          id: seriId,
          title: 'Aile Yemeklerimiz',
          personIds: const {},
        ),
      );

      final satirlar = await db.select(db.ritualPeople).get();
      expect(satirlar, hasLength(1));
      expect(satirlar.single.deletedAt, isNotNull);

      final baglar = await rituals.watchPeopleLinks().first;
      expect(baglar.valueOrNull![seriId] ?? const <String>{}, isEmpty);
    });
  });

  group('sayaçlar', () {
    test(
      'bağ eşitleme CANLI satıra dokunmuyor — sürüm boşuna artmıyor',
      () async {
        // Formu değiştirmeden ikinci kez kaydetmek, kişi bağını "değişti" diye
        // işaretlememeli: outbox'a (Faz 3) sahte bir değişiklik düşerdi.
        final kisiId = await yeniKisi('Annem');
        final aniId = await yeniAni(personIds: [kisiId]);

        final once = (await db.select(db.memoryPeople).get()).single.version;

        await memories.saveDraft(
          MemoryDraft(
            id: aniId,
            occurredAt: DateTime(2026, 3, 12),
            title: 'Kahve Molası',
            personIds: [kisiId],
          ),
        );

        final sonra = (await db.select(db.memoryPeople).get()).single.version;
        expect(sonra, once, reason: 'canlı bağ boşuna yeniden yazıldı');
      },
    );
  });
}
