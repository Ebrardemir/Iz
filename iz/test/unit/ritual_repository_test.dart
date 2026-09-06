/// Seri deposu + DAO entegrasyon testi — GERÇEK SQLite üzerinde.
///
/// Mock yok: şemanın, sıralamanın, tombstone filtresinin, sürüm artışının ve
/// "aynı yıla tek anı" kuralının gerçekten çalıştığını doğruluyor.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/features/rituals/domain/repositories/ritual_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late RitualRepository repository;

  setUp(() {
    db = createTestDatabase();
    repository = createTestRitualRepository(db);
  });

  tearDown(() async => db.close());

  Future<String> ekle({
    String title = 'Yaz Tatillerimiz',
    RecurrenceType recurrenceType = RecurrenceType.yearly,
    int? anchorMonth,
    int? anchorDay,
    List<RitualOccurrence>? occurrences,
  }) async {
    final result = await repository.save(
      RitualDraft(
        title: title,
        recurrenceType: recurrenceType,
        anchorMonth: anchorMonth,
        anchorDay: anchorDay,
        occurrences: occurrences,
      ),
    );
    return (result as Ok<String>).value;
  }

  Future<List<Ritual>> listele() async =>
      ((await repository.watchRituals().first) as Ok<List<Ritual>>).value;

  Future<Map<String, List<RitualOccurrence>>> baglar() async =>
      ((await repository.watchOccurrences().first)
              as Ok<Map<String, List<RitualOccurrence>>>)
          .value;

  /// Bağ yazabilmek için gerçek anı satırı gerekiyor: `MemoryRituals`
  /// `memoryId`yi `Memories`e foreign key ile bağlıyor.
  Future<void> aniEkle(String id, {required DateTime occurredAt}) {
    return db
        .into(db.memories)
        .insert(
          MemoriesCompanion.insert(
            id: id,
            occurredAt: occurredAt,
            occurredYear: occurredAt.year,
            occurredMonth: occurredAt.month,
            occurredDay: occurredAt.day,
          ),
        );
  }

  group('kaydetme', () {
    test('yeni seri listede görünüyor', () async {
      await ekle(title: 'Yaz Tatillerimiz', anchorMonth: 7);

      final list = await listele();
      expect(list, hasLength(1));
      expect(list.single.title, 'Yaz Tatillerimiz');
      expect(list.single.anchorMonth, 7);
    });

    test('tekrar türü varsayılan olarak YILLIK', () async {
      await ekle();

      expect((await listele()).single.recurrenceType, RecurrenceType.yearly);
    });

    test('güncelleme yeni kayıt AÇMIYOR', () async {
      final id = await ekle(title: 'İlk ad');

      await repository.save(RitualDraft(id: id, title: 'Yeni ad'));

      final list = await listele();
      expect(list, hasLength(1));
      expect(list.single.title, 'Yeni ad');
    });

    test('TR-C-31 — her yazmada version artıyor', () async {
      final id = await ekle(title: 'İlk');
      await repository.save(RitualDraft(id: id, title: 'İkinci'));

      final row = await (db.select(
        db.rituals,
      )..where((t) => t.id.equals(id))).getSingle();

      expect(row.version, 2);
    });

    test('en yeni seri listenin BAŞINDA', () async {
      final ilk = await ekle(title: 'Eski');
      await (db.update(db.rituals)..where((t) => t.id.equals(ilk))).write(
        RitualsCompanion(createdAt: Value(DateTime(2020))),
      );

      await ekle(title: 'Yeni');

      final list = await listele();
      expect(list.first.title, 'Yeni');
      expect(list.last.title, 'Eski');
    });
  });

  group('yıl bağları', () {
    test('BR-012 — bağ hangi YILA ait olduğunu taşıyor', () async {
      await aniEkle('mem-2024', occurredAt: DateTime(2024, 7, 15));
      final id = await ekle(occurrences: [(memoryId: 'mem-2024', year: 2024)]);

      expect(await baglar(), {
        id: [(memoryId: 'mem-2024', year: 2024)],
      });
    });

    test('yıla göre sıralı geliyor', () async {
      // Seri görünümü yılları karşılaştırıyor (FR-076); listeyi ekranın
      // istediği düzende vermek en ucuzu.
      await aniEkle('mem-a', occurredAt: DateTime(2026, 7));
      await aniEkle('mem-b', occurredAt: DateTime(2024, 7));

      final id = await ekle(
        occurrences: [
          (memoryId: 'mem-a', year: 2026),
          (memoryId: 'mem-b', year: 2024),
        ],
      );

      expect(await baglar(), {
        id: [(memoryId: 'mem-b', year: 2024), (memoryId: 'mem-a', year: 2026)],
      });
    });

    test('TR-M6-12 — aynı yıla EN FAZLA BİR anı', () async {
      // Birincil anahtar `(memoryId, ritualId)` bunu garanti ETMİYOR: aynı
      // seriye farklı iki anı aynı yılla bağlanabilirdi.
      await aniEkle('mem-a', occurredAt: DateTime(2026, 7));
      await aniEkle('mem-b', occurredAt: DateTime(2026, 8));

      final id = await ekle(
        occurrences: [
          (memoryId: 'mem-a', year: 2026),
          (memoryId: 'mem-b', year: 2026),
        ],
      );

      final links = (await baglar())[id]!;
      expect(links, hasLength(1));
      // Sonuncusu kazanıyor: form tek liste gösteriyor, ikinci giriş bir
      // düzeltmedir.
      expect(links.single.memoryId, 'mem-b');
    });

    test('occurrences null ise bağlara DOKUNULMUYOR', () async {
      await aniEkle('mem-a', occurredAt: DateTime(2026, 7));
      final id = await ekle(occurrences: [(memoryId: 'mem-a', year: 2026)]);

      await repository.save(RitualDraft(id: id, title: 'Yeni ad'));

      expect((await baglar())[id], hasLength(1));
    });

    test('occurrences boş liste ise bağlar KALDIRILIYOR', () async {
      await aniEkle('mem-a', occurredAt: DateTime(2026, 7));
      final id = await ekle(occurrences: [(memoryId: 'mem-a', year: 2026)]);

      await repository.save(
        RitualDraft(id: id, title: 'Yaz Tatillerimiz', occurrences: const []),
      );

      expect(await baglar(), isEmpty);
    });
  });

  group('silme', () {
    test('TR-C-32 — silinen listede yok ama satır DURUYOR', () async {
      final id = await ekle();

      await repository.softDelete(id);

      expect(await listele(), isEmpty);

      final row = await (db.select(
        db.rituals,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.deletedAt, isNotNull);
    });

    test('seri silinince ANILAR SİLİNMİYOR', () async {
      await aniEkle('mem-a', occurredAt: DateTime(2026, 7));
      final id = await ekle(occurrences: [(memoryId: 'mem-a', year: 2026)]);

      await repository.softDelete(id);

      final memories = await db.select(db.memories).get();
      expect(memories, hasLength(1));
      expect(memories.single.deletedAt, isNull);
    });

    test('olmayan kaydı silmek hata DEĞİL', () async {
      expect(await repository.softDelete('yok'), isA<Ok<Unit>>());
    });
  });

  group('okuma', () {
    test('watchRitual silinmiş kayıt için null veriyor', () async {
      final id = await ekle();
      await repository.softDelete(id);

      final result = await repository.watchRitual(id).first;

      expect((result as Ok<Ritual?>).value, isNull);
    });

    test('findRitual olmayan kimlik için null — hata DEĞİL', () async {
      final result = await repository.findRitual('yok');

      expect((result as Ok<Ritual?>).value, isNull);
    });
  });
}
