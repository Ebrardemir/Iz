/// Medya deposu + DAO entegrasyon testi — GERÇEK SQLite üzerinde.
///
/// Dosya sistemi sahte ([FakeMediaFileStore]), veritabanı gerçek: şemanın,
/// sürüm artışının ve durum güncellemesinin çalıştığını doğruluyor.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/media/domain/repositories/media_repository.dart';

import '../helpers/fake_media_file_store.dart';
import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeMediaFileStore files;
  late MediaRepository repository;

  setUp(() {
    db = createTestDatabase();
    files = FakeMediaFileStore();
    repository = createTestMediaRepository(db, files);
  });

  tearDown(() async => db.close());

  Future<List<MediaItem>> ice(List<String> paths) async =>
      ((await repository.importPicked(paths)) as Ok<List<MediaItem>>).value;

  group('içe aktarma', () {
    test('dosya uygulama alanına KOPYALANIYOR', () async {
      // TR-M4-11: seçicinin verdiği yol geçici bir önbellek yolu; oraya
      // güvenirsek kullanıcının anısının görseli bir gün sessizce kaybolur.
      final imported = await ice(['/galeri/gecici/foto.jpg']);

      expect(imported, hasLength(1));
      expect(files.stored.values, contains('/galeri/gecici/foto.jpg'));
      expect(
        imported.single.localPreviewPath,
        isNot('/galeri/gecici/foto.jpg'),
      );
    });

    test('veritabanına satır yazılıyor ve geri okunabiliyor', () async {
      final imported = await ice(['/galeri/a.jpg']);
      final id = imported.single.id;

      final found = (await repository.findMedia(id) as Ok<MediaItem?>).value;

      expect(found, isNotNull);
      expect(found!.localPreviewPath, imported.single.localPreviewPath);
    });

    test('birden fazla dosya tek çağrıda', () async {
      final imported = await ice(['/a.jpg', '/b.jpg', '/c.jpg']);

      expect(imported, hasLength(3));
      expect(imported.map((m) => m.id).toSet(), hasLength(3));
    });

    test('durum UNKNOWN — "available" yazmak yalan olurdu', () async {
      // Elimizde kalıcı bir GALERİ kimliği yok (sistem seçicisi yalnız dosya
      // veriyor); orijinalin hâlâ durup durmadığını bugün bilemiyoruz.
      final imported = await ice(['/a.jpg']);

      expect(imported.single.originalStatus, MediaOriginalStatus.unknown);
    });

    test('boş liste hata DEĞİL', () async {
      expect(await ice(const []), isEmpty);
    });

    test('dosya kopyalanamazsa Err dönüyor, satır YAZILMIYOR', () async {
      files.failOnStore = true;

      final result = await repository.importPicked(['/a.jpg']);

      expect(result, isA<Err<List<MediaItem>>>());
      expect(await db.select(db.mediaItems).get(), isEmpty);
    });
  });

  group('doğrulama (TR-M4-12)', () {
    test('dosya duruyorsa AVAILABLE ve tarih yazılıyor', () async {
      final imported = await ice(['/a.jpg']);
      final id = imported.single.id;

      final status =
          (await repository.verify(id) as Ok<MediaOriginalStatus>).value;

      expect(status, MediaOriginalStatus.available);

      final row = await (db.select(
        db.mediaItems,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.lastVerifiedAt, isNotNull);
    });

    test('dosya yoksa MISSING — ama satır SİLİNMİYOR (TR-M4-13)', () async {
      final imported = await ice(['/a.jpg']);
      final id = imported.single.id;
      files.existsOverride = false;

      final status =
          (await repository.verify(id) as Ok<MediaOriginalStatus>).value;

      expect(status, MediaOriginalStatus.missing);
      // Kayıt duruyor: önizleme hâlâ varsa kart anlaşılır kalıyor, kullanıcı
      // yalnızca rozet görüyor.
      final rows = await db.select(db.mediaItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.deletedAt, isNull);
    });

    test('olmayan kimlik UNKNOWN — hata değil', () async {
      final status =
          (await repository.verify('yok') as Ok<MediaOriginalStatus>).value;

      expect(status, MediaOriginalStatus.unknown);
    });
  });

  group('silme', () {
    test('satır tombstone, dosya gerçekten siliniyor', () async {
      final imported = await ice(['/a.jpg']);
      final id = imported.single.id;
      final path = imported.single.localPreviewPath!;

      await repository.delete(id);

      expect(files.deleted, contains(path));

      final row = await (db.select(
        db.mediaItems,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.deletedAt, isNotNull);

      // Silinen kayıt okumalarda görünmüyor.
      expect((await repository.findMedia(id) as Ok<MediaItem?>).value, isNull);
    });
  });

  group('toplu okuma', () {
    test('findMany yalnız istenen kimlikleri veriyor', () async {
      final imported = await ice(['/a.jpg', '/b.jpg']);
      final wanted = imported.first.id;

      final found =
          (await repository.findMany([wanted]) as Ok<List<MediaItem>>).value;

      expect(found, hasLength(1));
      expect(found.single.id, wanted);
    });

    test('boş kimlik listesi boş sonuç — sorgu bile açmıyor', () async {
      expect(
        (await repository.findMany(const []) as Ok<List<MediaItem>>).value,
        isEmpty,
      );
    });
  });
}
