/// Koleksiyon deposu + DAO entegrasyon testi — GERÇEK SQLite üzerinde.
///
/// Mock yok: şemanın, sıralamanın, tombstone filtresinin, sürüm artışının ve
/// anı bağlarının gerçekten çalıştığını doğruluyor. Mock'la yazsaydık yalnız
/// "DAO'yu doğru çağırdım mı"yı ölçerdik.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/collections/domain/repositories/collection_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CollectionRepository repository;

  setUp(() {
    db = createTestDatabase();
    repository = createTestCollectionRepository(db);
  });

  tearDown(() async => db.close());

  Future<String> ekle({
    String title = 'Kapadokya 2026',
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? memoryIds,
  }) async {
    final result = await repository.save(
      CollectionDraft(
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        memoryIds: memoryIds,
      ),
    );
    return (result as Ok<String>).value;
  }

  Future<List<MemoryCollection>> listele() async =>
      ((await repository.watchCollections().first)
              as Ok<List<MemoryCollection>>)
          .value;

  Future<MemoryCollection> tek() async => (await listele()).single;

  Future<Map<String, List<String>>> baglar() async =>
      ((await repository.watchMemoryLinks().first)
              as Ok<Map<String, List<String>>>)
          .value;

  /// Anı bağı yazabilmek için gerçek anı satırı gerekiyor: `MemoryCollections`
  /// `memoryId`yi `Memories`e foreign key ile bağlıyor.
  Future<void> aniEkle(String id, {required DateTime occurredAt}) {
    return db
        .into(db.memories)
        .insert(
          MemoriesCompanion.insert(
            id: id,
            occurredAt: occurredAt,
            // Ters indeks sütunları (TR-C-33): "bu ayın anıları" gibi sorgular
            // tarihi parçalamadan çalışamıyor.
            occurredYear: occurredAt.year,
            occurredMonth: occurredAt.month,
            occurredDay: occurredAt.day,
          ),
        );
  }

  group('kaydetme', () {
    test('yeni koleksiyon listede görünüyor', () async {
      await ekle(title: 'Kapadokya 2026', description: 'Balonlar');

      final list = await listele();
      expect(list, hasLength(1));
      expect(list.single.title, 'Kapadokya 2026');
      expect(list.single.description, 'Balonlar');
    });

    test('BR-003 — görünürlük varsayılan olarak ÖZEL', () async {
      await ekle();

      final collection = await tek();
      expect(collection.visibility, CollectionVisibility.private);
      expect(collection.isShared, isFalse);
    });

    test('boş açıklama null yazılıyor, boş metin değil', () async {
      // Boş metin ile "yazılmamış" aynı şey; '' yazsaydık her okuma yerinde
      // ayrıca `isEmpty` kontrolü gerekirdi.
      await ekle(description: '   ');

      expect((await tek()).description, isNull);
    });

    test('güncelleme yeni kayıt AÇMIYOR, aynı satırı değiştiriyor', () async {
      final id = await ekle(title: 'İlk ad');

      await repository.save(CollectionDraft(id: id, title: 'Yeni ad'));

      final list = await listele();
      expect(list, hasLength(1));
      expect(list.single.title, 'Yeni ad');
    });

    test('TR-C-31 — her yazmada version artıyor', () async {
      final id = await ekle(title: 'İlk');
      await repository.save(CollectionDraft(id: id, title: 'İkinci'));
      await repository.save(CollectionDraft(id: id, title: 'Üçüncü'));

      final row = await (db.select(
        db.collections,
      )..where((t) => t.id.equals(id))).getSingle();

      expect(row.version, 3);
    });

    test('en yeni koleksiyon listenin BAŞINDA', () async {
      // Koleksiyon çoğu zaman anılardan önce kuruluyor; kullanıcı az önce
      // açtığını hemen görmeli.
      final ilk = await ekle(title: 'Eski');
      // `createdAt` varsayılanı aynı saniyeye düşebiliyor; sırayı belirsiz
      // bırakmamak için açıkça geriye alıyoruz.
      await (db.update(db.collections)..where((t) => t.id.equals(ilk))).write(
        CollectionsCompanion(createdAt: Value(DateTime(2020))),
      );

      await ekle(title: 'Yeni');

      final list = await listele();
      expect(list.first.title, 'Yeni');
      expect(list.last.title, 'Eski');
    });
  });

  group('silme', () {
    test('TR-C-32 — silinen listede yok ama satır DURUYOR', () async {
      final id = await ekle();

      await repository.softDelete(id);

      expect(await listele(), isEmpty);

      final row = await (db.select(
        db.collections,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.deletedAt, isNotNull);
    });

    test('TR-M6-11 — koleksiyon silinince ANILAR SİLİNMİYOR', () async {
      await aniEkle('mem-1', occurredAt: DateTime(2026, 5, 10));
      final id = await ekle(memoryIds: ['mem-1']);

      await repository.softDelete(id);

      final memories = await db.select(db.memories).get();
      expect(memories, hasLength(1));
      expect(memories.single.deletedAt, isNull);
    });

    test('olmayan kaydı silmek hata DEĞİL', () async {
      final result = await repository.softDelete('yok-boyle-bir-sey');

      expect(result, isA<Ok<Unit>>());
    });
  });

  group('anı bağları', () {
    test('formda dizilen sıra korunuyor', () async {
      await aniEkle('mem-a', occurredAt: DateTime(2026, 5, 10));
      await aniEkle('mem-b', occurredAt: DateTime(2026, 5, 12));

      // Tarihe göre TERS sırada bağlıyoruz: sıra anıların tarihinden değil,
      // kullanıcının dizilişinden gelmeli.
      final id = await ekle(memoryIds: ['mem-b', 'mem-a']);

      expect(await baglar(), {
        id: ['mem-b', 'mem-a'],
      });
    });

    test('güncelleme bağları DEĞİŞTİRİYOR', () async {
      await aniEkle('mem-a', occurredAt: DateTime(2026, 5, 10));
      await aniEkle('mem-b', occurredAt: DateTime(2026, 5, 12));
      final id = await ekle(memoryIds: ['mem-a']);

      await repository.save(
        CollectionDraft(id: id, title: 'Kapadokya 2026', memoryIds: ['mem-b']),
      );

      expect(await baglar(), {
        id: ['mem-b'],
      });
    });

    test('memoryIds null ise bağlara DOKUNULMUYOR', () async {
      // Adını değiştirmek için açılan bir form, koleksiyonun tüm anılarını
      // sessizce koparmamalı.
      await aniEkle('mem-a', occurredAt: DateTime(2026, 5, 10));
      final id = await ekle(memoryIds: ['mem-a']);

      await repository.save(CollectionDraft(id: id, title: 'Yeni ad'));

      expect(await baglar(), {
        id: ['mem-a'],
      });
    });

    test('memoryIds boş liste ise bağlar KALDIRILIYOR', () async {
      await aniEkle('mem-a', occurredAt: DateTime(2026, 5, 10));
      final id = await ekle(memoryIds: ['mem-a']);

      await repository.save(
        CollectionDraft(id: id, title: 'Kapadokya 2026', memoryIds: []),
      );

      expect(await baglar(), isEmpty);
    });
  });

  group('okuma', () {
    test('watchCollection silinmiş kayıt için null veriyor', () async {
      final id = await ekle();
      await repository.softDelete(id);

      final result = await repository.watchCollection(id).first;

      expect((result as Ok<MemoryCollection?>).value, isNull);
    });

    test('findCollection olmayan kimlik için null — hata DEĞİL', () async {
      final result = await repository.findCollection('yok');

      expect((result as Ok<MemoryCollection?>).value, isNull);
    });
  });
}
