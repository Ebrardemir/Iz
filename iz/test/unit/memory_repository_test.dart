/// Repository + DAO entegrasyon testi — GERÇEK SQLite üzerinde.
///
/// Rapor 18.1: "Integration test: local DB migration, media asset adapter,
/// export/restore."
///
/// Buradaki testler mock kullanmaz. Şemanın, join'lerin, transaction'ların
/// ve FTS5 trigger'larının gerçekten çalıştığını doğrular.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';
import 'package:iz/features/memories/domain/repositories/memory_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MemoryRepository repository;

  setUp(() {
    db = createTestDatabase();
    repository = createTestRepository(db);
  });

  tearDown(() async => db.close());

  Future<String> seedMemory({
    String? title,
    String? note,
    DateTime? occurredAt,
    bool isFavorite = false,
  }) async {
    final result = await repository.saveDraft(
      MemoryDraft(
        occurredAt: occurredAt ?? DateTime(2026, 3, 12),
        title: title,
        note: note,
        isFavorite: isFavorite,
      ),
    );
    return result.valueOrNull!;
  }

  test('FR-070 — varsayılan kategoriler ilk açılışta tohumlanır', () async {
    final categories = await db.select(db.categories).get();

    expect(categories, hasLength(8));
    expect(categories.every((c) => c.isSystem), isTrue);

    // ÇOK DİLLİLİK SÖZLEŞMESİ: veritabanına ÇEVRİLMİŞ ad değil, çeviri
    // ANAHTARI yazılır. Buraya 'Seyahat' yazılsaydı İngilizce arayüzde de
    // Türkçe görünürdü ve düzeltmek migration gerektirirdi.
    expect(
      categories.map((c) => c.name),
      containsAll(<String>['travel', 'family', 'celebrations']),
    );
  });

  test('anı kaydedilir ve akışta görünür', () async {
    await seedMemory(title: 'Kapadokya balon turu');

    final memories = await repository.watchMemories(MemoryFilter.all).first;

    expect(memories.valueOrNull, hasLength(1));
    expect(memories.valueOrNull!.first.title, 'Kapadokya balon turu');
  });

  test(
    'FR-015 — çöp kutusundaki anı listede görünmez, geri alınabilir',
    () async {
      final id = await seedMemory(title: 'Silinecek anı');

      await repository.moveToTrash(id);
      var memories = await repository.watchMemories(MemoryFilter.all).first;
      expect(memories.valueOrNull, isEmpty);

      await repository.restoreFromTrash(id);
      memories = await repository.watchMemories(MemoryFilter.all).first;
      expect(memories.valueOrNull, hasLength(1));
    },
  );

  test('rapor 12.2 — her yazmada version artar', () async {
    final id = await seedMemory(title: 'Sürüm testi');

    final before = await (db.select(
      db.memories,
    )..where((t) => t.id.equals(id))).getSingle();

    await repository.setFavorite(id, isFavorite: true);

    final after = await (db.select(
      db.memories,
    )..where((t) => t.id.equals(id))).getSingle();

    expect(after.version, greaterThan(before.version));
    expect(after.isFavorite, isTrue);
  });

  test('createdAt güncellemede korunur, updatedAt tazelenir', () async {
    // Mapper `createdAt`i bilerek yazmaz. Yazsaydı her düzenleme
    // "oluşturulma tarihi"ni sıfırlar ve timeline sıralaması bozulurdu.
    final id = await seedMemory(note: 'ilk hâli');

    final before = await (db.select(
      db.memories,
    )..where((t) => t.id.equals(id))).getSingle();

    await repository.saveDraft(
      MemoryDraft(
        id: id,
        occurredAt: DateTime(2026, 3, 12),
        note: 'düzenlendi',
      ),
    );

    final after = await (db.select(
      db.memories,
    )..where((t) => t.id.equals(id))).getSingle();

    expect(after.createdAt, before.createdAt, reason: 'createdAt değişmemeli');
    expect(after.note, 'düzenlendi');
    expect(after.version, before.version + 1);
  });

  test('FR-090/092 — FTS5 araması başlıkta çalışır', () async {
    await seedMemory(title: 'Kapadokya balon turu');
    await seedMemory(title: 'İzmir sahil yürüyüşü');

    final results = await repository
        .watchMemories(const MemoryFilter(query: 'kapadokya'))
        .first;

    expect(results.valueOrNull, hasLength(1));
    expect(results.valueOrNull!.first.title, contains('Kapadokya'));
  });

  test(
    'arama sonucu CANLI — arama açıkken eklenen eşleşme listeye girer',
    () async {
      // REGRESYON: FTS eşleşen id'leri bir kez hesaplanıp donduruluyordu.
      // Arama açıkken yeni bir anı eklendiğinde liste onu göremiyordu.
      await seedMemory(title: 'Kapadokya balon turu');

      final emissions = <int>[];
      final sub = repository
          .watchMemories(const MemoryFilter(query: 'kapadokya'))
          .listen((r) => emissions.add(r.valueOrNull?.length ?? -1));

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(emissions.last, 1, reason: 'ilk arama sonucu');

      // Arama akışı hâlâ açıkken eşleşen ikinci bir anı ekle.
      await seedMemory(title: 'Kapadokya gün batımı');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(
        emissions.last,
        2,
        reason: 'yeni eşleşme arama sonucuna girmeliydi',
      );

      await sub.cancel();
    },
  );

  test('arama girdisi SQL bozmaz — özel karakterler temizlenir', () async {
    await seedMemory(title: 'Kapadokya balon turu');
    await seedMemory(title: 'İzmir sahil yürüyüşü');

    // 1) Tırnak içeren normal girdi çalışmaya devam etmeli.
    //    `kapadokya'` → tırnak atılır → "kapadokya"* → eşleşir.
    final quoted = await repository
        .watchMemories(const MemoryFilter(query: "kapadokya'"))
        .first;

    expect(quoted.isOk, isTrue, reason: 'sorgu hata vermemeli');
    expect(quoted.valueOrNull, hasLength(1));

    // 2) Klasik injection denemesi: ne patlamalı ne de her şeyi dökmeli.
    //    Tırnaklar atıldığı için geriye "kapadokya" AND "OR" AND "11" kalır
    //    ve hiçbir anı üçünü birden içermez.
    final injected = await repository
        .watchMemories(const MemoryFilter(query: "kapadokya' OR '1'='1"))
        .first;

    expect(injected.isOk, isTrue, reason: 'sorgu hata vermemeli');
    expect(
      injected.valueOrNull,
      isEmpty,
      reason: 'injection denemesi kayıt sızdırmamalı',
    );
  });

  test('FTS5 araması notta da çalışır ve Türkçe aksanı yok sayar', () async {
    await seedMemory(title: 'Bir gün', note: 'Annemle çay içtik');

    // "annemle" → aksansız yazımla da bulunmalı (remove_diacritics 2)
    final results = await repository
        .watchMemories(const MemoryFilter(query: 'annemle'))
        .first;

    expect(results.valueOrNull, hasLength(1));
  });

  test('anı silinince FTS indeksi de temizlenir', () async {
    final id = await seedMemory(title: 'Geçici kayıt');

    await repository.moveToTrash(id);

    final results = await repository
        .watchMemories(const MemoryFilter(query: 'geçici'))
        .first;

    expect(results.valueOrNull, isEmpty);
  });

  test('FR-080 — Bugünün İzi yalnızca geçmiş yılları getirir', () async {
    await seedMemory(
      title: '2020 doğum günü',
      occurredAt: DateTime(2020, 7, 26),
    );
    await seedMemory(
      title: '2023 doğum günü',
      occurredAt: DateTime(2023, 7, 26),
    );
    // Aynı yıl → dahil edilmemeli
    await seedMemory(
      title: '2026 doğum günü',
      occurredAt: DateTime(2026, 7, 26),
    );
    // Farklı gün → dahil edilmemeli
    await seedMemory(title: 'Başka gün', occurredAt: DateTime(2021, 8, 26));

    final result = await repository.findOnThisDay(DateTime(2026, 7, 26));

    expect(result.valueOrNull, hasLength(2));
    expect(
      result.valueOrNull!.map((m) => m.occurredAt.year),
      containsAll(<int>[2020, 2023]),
    );
  });

  test('FR-091 — favori filtresi çalışır', () async {
    await seedMemory(title: 'Favori', isFavorite: true);
    await seedMemory(title: 'Normal');

    final results = await repository
        .watchMemories(const MemoryFilter(onlyFavorites: true))
        .first;

    expect(results.valueOrNull, hasLength(1));
    expect(results.valueOrNull!.first.title, 'Favori');
  });

  test('NFR-020 — ilişkiler anı ile aynı transaction içinde yazılır', () async {
    // Önce bir kişi oluştur.
    await db
        .into(db.people)
        .insert(PeopleCompanion.insert(id: 'p1', name: 'Annem'));

    final result = await repository.saveDraft(
      MemoryDraft(
        occurredAt: DateTime(2026, 3, 12),
        note: 'Annemle kahvaltı',
        personIds: const ['p1'],
      ),
    );

    final detail = await repository.findDetail(result.valueOrNull!);

    expect(detail.valueOrNull!.people, hasLength(1));
    expect(detail.valueOrNull!.people.first.name, 'Annem');
    expect(detail.valueOrNull!.memory.personCount, 1);
  });

  test('BR-001 — aynı anı iki kişide de görünür, kopyalanmaz', () async {
    await db.batch((b) {
      b.insertAll(db.people, [
        PeopleCompanion.insert(id: 'p1', name: 'Annem'),
        PeopleCompanion.insert(id: 'p2', name: 'Babam'),
      ]);
    });

    await repository.saveDraft(
      MemoryDraft(
        occurredAt: DateTime(2026, 3, 12),
        note: 'Aile yemeği',
        personIds: const ['p1', 'p2'],
      ),
    );

    final forMom = await repository
        .watchMemories(const MemoryFilter(personIds: {'p1'}))
        .first;
    final forDad = await repository
        .watchMemories(const MemoryFilter(personIds: {'p2'}))
        .first;
    final all = await repository.watchMemories(MemoryFilter.all).first;

    expect(forMom.valueOrNull, hasLength(1));
    expect(forDad.valueOrNull, hasLength(1));
    // Tek kayıt — çoğaltma yok.
    expect(all.valueOrNull, hasLength(1));
  });

  test('anı güncellendiğinde ilişkiler değiştirilir, çoğaltılmaz', () async {
    await db.batch((b) {
      b.insertAll(db.people, [
        PeopleCompanion.insert(id: 'p1', name: 'Annem'),
        PeopleCompanion.insert(id: 'p2', name: 'Babam'),
      ]);
    });

    final id = await seedMemory(note: 'Yemek');

    await repository.saveDraft(
      MemoryDraft(
        id: id,
        occurredAt: DateTime(2026, 3, 12),
        note: 'Yemek',
        personIds: const ['p1', 'p2'],
      ),
    );
    await repository.saveDraft(
      MemoryDraft(
        id: id,
        occurredAt: DateTime(2026, 3, 12),
        note: 'Yemek',
        personIds: const ['p2'],
      ),
    );

    final detail = await repository.findDetail(id);
    expect(detail.valueOrNull!.people, hasLength(1));
    expect(detail.valueOrNull!.people.first.id, 'p2');
  });

  test('watchMemories veri değişince yeniden yayınlar', () async {
    final stream = repository.watchMemories(MemoryFilter.all);

    // İlk değer: boş
    expect((await stream.first).valueOrNull, isEmpty);

    await seedMemory(title: 'Yeni anı');

    // Stream yeni değeri kendiliğinden yayınlamalı.
    final updated = await stream.first;
    expect(updated.valueOrNull, hasLength(1));
  });
}
