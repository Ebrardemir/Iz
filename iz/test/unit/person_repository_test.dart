/// Kişi deposu + DAO entegrasyon testi — GERÇEK SQLite üzerinde.
///
/// Mock yok: şemanın, sıralamanın, tombstone filtresinin ve sürüm
/// artışının gerçekten çalıştığını doğruluyor. Mock'la yazsaydık yalnız
/// "DAO'yu doğru çağırdım mı"yı ölçerdik.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/people/domain/repositories/person_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late PersonRepository repository;

  setUp(() {
    db = createTestDatabase();
    repository = createTestPersonRepository(db);
  });

  tearDown(() async => db.close());

  Future<String> ekle({
    String name = 'Ayşe',
    String? relationLabel,
    DateTime? birthDate,
    bool isFavorite = false,
  }) async {
    final result = await repository.save(
      PersonDraft(
        name: name,
        relationLabel: relationLabel,
        birthDate: birthDate,
        isFavorite: isFavorite,
      ),
    );
    return (result as Ok<String>).value;
  }

  Future<List<Person>> listele() async =>
      ((await repository.watchPeople().first) as Ok<List<Person>>).value;

  group('kaydetme', () {
    test('yeni kişi kimlik alır ve listede görünür', () async {
      final id = await ekle(name: 'Ayşe');

      final kisiler = await listele();
      expect(kisiler, hasLength(1));
      expect(kisiler.single.id, id);
      expect(kisiler.single.name, 'Ayşe');
    });

    test('kullanıcının yazdığı ilişki adı KAYBOLMUYOR', () async {
      // v6 bu sütun için açıldı. Öncesinde alan entity'de vardı ama
      // sütunu yoktu: kullanıcı "Annem" yazsa kayıt sırasında düşüyordu.
      await ekle(name: 'Zeynep', relationLabel: 'Annem');

      final kisi = (await listele()).single;
      expect(kisi.relationLabel, 'Annem');
    });

    test('ilişki TÜRÜ yazılandan türetiliyor', () async {
      // FR-061: kullanıcı listeden seçmiyor, kendi kelimesini yazıyor.
      // Filtreleme ve doğum günü ritüelleri (FR-064) bir türe ihtiyaç duyuyor.
      await ekle(name: 'Zeynep', relationLabel: 'Annem');

      expect((await listele()).single.relationType, RelationType.parent);
    });

    test('boş ilişki adı null olarak saklanıyor', () async {
      // '' yazmak, her okuma yerinde isEmpty kontrolü gerektirirdi.
      await ekle(name: 'Ayşe', relationLabel: '   ');

      expect((await listele()).single.relationLabel, isNull);
    });

    test('ad ve not baştaki/sondaki boşluklardan arındırılıyor', () async {
      await repository.save(
        const PersonDraft(name: '  Ayşe  ', note: '  komşumuz '),
      );

      final kisi = (await listele()).single;
      expect(kisi.name, 'Ayşe');
      expect(kisi.note, 'komşumuz');
    });

    test('var olan kişi güncellenince YENİ kayıt oluşmuyor', () async {
      final id = await ekle(name: 'Ayşe');

      await repository.save(PersonDraft(id: id, name: 'Ayşe Yılmaz'));

      final kisiler = await listele();
      expect(kisiler, hasLength(1));
      expect(kisiler.single.name, 'Ayşe Yılmaz');
    });

    test('her yazmada sürüm artıyor', () async {
      // TR-C-31: senkronizasyon çakışma çözümü buna dayanacak. Artmazsa
      // sunucu değişikliği görmez ve kayıt sessizce eskimiş kalır.
      final id = await ekle(name: 'Ayşe');
      final ilk = await db.personDao.findPerson(id);

      await repository.save(PersonDraft(id: id, name: 'Ayşe Yılmaz'));
      final ikinci = await db.personDao.findPerson(id);

      expect(ikinci!.version, greaterThan(ilk!.version));
    });
  });

  group('listeleme', () {
    test('favoriler önce, sonra alfabetik', () async {
      await ekle(name: 'Zeynep');
      await ekle(name: 'Ayşe');
      await ekle(name: 'Mehmet', isFavorite: true);

      expect(
        (await listele()).map((p) => p.name),
        ['Mehmet', 'Ayşe', 'Zeynep'],
        reason:
            'Kişisel bir listede salt alfabetik sıra anlamsız; '
            'kullanıcının yakınları başta olmalı.',
      );
    });

    test('kişi yoksa liste BOŞ döner, hata değil', () async {
      // Boş liste ekranda tasarlanmış boş durumu (PeopleEmptyIllustration)
      // tetikliyor. Hata dönseydi kullanıcı hata ekranı görürdü.
      final sonuc = await repository.watchPeople().first;

      expect(sonuc, isA<Ok<List<Person>>>());
      expect((sonuc as Ok<List<Person>>).value, isEmpty);
    });
  });

  group('silme', () {
    test('silinen kişi listeden düşüyor', () async {
      final id = await ekle(name: 'Ayşe');

      await repository.softDelete(id);

      expect(await listele(), isEmpty);
    });

    test('silme FİZİKSEL değil, tombstone', () async {
      // TR-C-32: satır tabloda kalıyor. Senkronizasyon geldiğinde "bu kişiyi
      // sildim" olayının diğer cihaza taşınabilmesi buna bağlı; satır
      // gerçekten silinseydi anlatacak bir şey kalmazdı.
      final id = await ekle(name: 'Ayşe');

      await repository.softDelete(id);

      final hamSatirlar = await db.select(db.people).get();
      expect(hamSatirlar, hasLength(1));
      expect(hamSatirlar.single.deletedAt, isNotNull);
    });

    test('silinen kişi detay sorgusunda da görünmüyor', () async {
      final id = await ekle(name: 'Ayşe');
      await repository.softDelete(id);

      final sonuc = await repository.findPerson(id);

      expect((sonuc as Ok<Person?>).value, isNull);
    });
  });

  group('favori', () {
    test('işaret değişiyor ve sürüm artıyor', () async {
      final id = await ekle(name: 'Ayşe');

      await repository.setFavorite(id, isFavorite: true);

      final kisi = await db.personDao.findPerson(id);
      expect(kisi!.isFavorite, isTrue);
      expect(kisi.version, greaterThan(1));
    });

    test('olmayan kişide sessizce geçiliyor', () async {
      // Silinmiş bir kişiye favori işaretlemek bir hata değil, anlamsız
      // bir istek. Hata döndürmek çağıran tarafı gereksiz yere uğraştırırdı.
      final sonuc = await repository.setFavorite('yok', isFavorite: true);

      expect(sonuc, isA<Ok<Unit>>());
    });
  });

  group('canlı akış', () {
    test('yeni kişi eklenince liste KENDİLİĞİNDEN güncelleniyor', () async {
      // Ekranlar elle yenileme yapmıyor (TR-M2-05 ile aynı ilke).
      final akis = repository.watchPeople();
      final beklenen = expectLater(
        akis.map((r) => (r as Ok<List<Person>>).value.length),
        emitsInOrder([0, 1]),
      );

      await ekle(name: 'Ayşe');
      await beklenen;
    });
  });
}
