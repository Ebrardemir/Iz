/// HESAP İZOLASYONU — aynı cihaz, iki hesap.
///
/// GERÇEK OLAY: kullanıcı hesapsızken bir süre anı yazdı, sonra hesap açtı
/// (geriye dönük doldurma o kayıtları hesabına taşıdı), sonra AYNI TELDE
/// ikinci bir hesap açtı — ve birinci hesabın bütün anılarını, kişilerini,
/// günlüklerini ekranda gördü.
///
/// Sebep: `ownerId` sütunu her sahipli tabloda duruyordu ama HİÇBİR okuma
/// sorgusu ona bakmıyordu. Yerel veritabanı "bu cihaz = tek kişi"
/// varsayımıyla yazılmıştı ve hesap diye bir şey yokken varsayım
/// görünmüyordu.
///
/// Görmek tek başına yeterince kötüydü. Asıl tehlike, gördüğü bir kaydı
/// DÜZENLEMESİ hâlinde o kaydın kuyruğa girip KENDİ hesabına yüklenmesiydi —
/// o noktada sızıntı buluta da çıkardı.
///
/// Bu testler sorgu düzeyinde, gerçek SQL üzerinde koşuyor.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/database/owner_scope.dart';
import 'package:iz/features/collections/domain/repositories/collection_repository.dart';
import 'package:iz/features/journal/domain/repositories/journal_repository.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';
import 'package:iz/features/memories/domain/repositories/memory_repository.dart';
import 'package:iz/features/people/domain/repositories/person_repository.dart';
import 'package:iz/features/rituals/domain/repositories/ritual_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  const ayse = 'kullanici-ayse';
  const bora = 'kullanici-bora';

  late MemoryRepository aniDeposu;

  setUp(() {
    db = createTestDatabase();
    // Depo BİR KEZ kuruluyor: `createTestRepository` her çağrıda sıfırdan bir
    // `SequentialIdGenerator` veriyor ve iki ayrı çağrı AYNI kimliği üretip
    // ikinci kaydın birinciyi ezmesine yol açıyordu.
    aniDeposu = createTestRepository(db);
  });

  tearDown(() => db.close());

  /// O hesabın gözünden bir işi yaptırır.
  Future<T> olarak<T>(String kimlik, Future<T> Function() is_) async {
    db.ownerScope.enter(kimlik);
    return is_();
  }

  Future<String> aniYaz(String baslik) async {
    final sonuc = await aniDeposu.saveDraft(
      MemoryDraft(occurredAt: kTestDatabaseNow, title: baslik),
    );
    return sonuc.valueOrNull!;
  }

  Future<List<String>> aniBasliklari() async {
    final sonuc = await aniDeposu.watchMemories(const MemoryFilter()).first;
    return sonuc.valueOrNull!.map((m) => m.title ?? '').toList();
  }

  group('anılar', () {
    test('BAŞKA hesabın anısı listede GÖRÜNMÜYOR', () async {
      await olarak(ayse, () => aniYaz('Ayşe: anneannemin bahçesi'));

      final boraninGorduleri = await olarak(bora, aniBasliklari);

      expect(boraninGorduleri, isEmpty);
    });

    test('KENDİ anısını görüyor', () async {
      await olarak(ayse, () => aniYaz('Ayşe: bahçe'));
      await olarak(bora, () => aniYaz('Bora: deniz'));

      expect(await olarak(bora, aniBasliklari), ['Bora: deniz']);
      expect(await olarak(ayse, aniBasliklari), ['Ayşe: bahçe']);
    });

    test('BAŞKA hesabın anısı DETAYDA da açılmıyor', () async {
      // Liste süzülüp detay süzülmeseydi, kimliği bir şekilde ele geçen
      // (derin bağlantı, hata ayıklama ekranı) kayıt yine açılabilirdi.
      final id = await olarak(ayse, () => aniYaz('Ayşe: gizli'));

      final detay = await olarak(bora, () => aniDeposu.findDetail(id));

      expect(detay.valueOrNull, isNull);
    });

    test('BAŞKA hesabın anısı ÇÖP KUTUSUNDA da görünmüyor', () async {
      final id = await olarak(ayse, () => aniYaz('Ayşe: silinen'));
      await olarak(ayse, () => aniDeposu.moveToTrash(id));

      final cop = await olarak(bora, () => db.memoryDao.trashedMemories());

      expect(cop, isEmpty);
    });

    test('BAŞKA hesabın anısı DÜZENLENEMİYOR', () async {
      // EN TEHLİKELİ SENARYO: düzenleme kuyruğa girseydi, kayıt öteki
      // hesabın oturumuyla sunucuya yüklenirdi ve sızıntı buluta çıkardı.
      final id = await olarak(ayse, () => aniYaz('Ayşe: dokunma'));

      await olarak(bora, () => aniDeposu.setFavorite(id, isFavorite: true));

      final satir = await (db.select(
        db.memories,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(satir.isFavorite, isFalse, reason: 'satır değişmemeli');

      final kuyruk = await (db.select(
        db.outboxEntries,
      )..where((t) => t.entityId.equals(id))).get();
      expect(
        kuyruk.where((r) => r.op.name == 'update'),
        isEmpty,
        reason: 'kuyruğa girseydi Bora\'nın hesabına yüklenirdi',
      );
    });
  });

  group('diğer kayıt türleri', () {
    test('kişiler süzülüyor', () async {
      await olarak(
        ayse,
        () => createTestPersonRepository(
          db,
        ).save(const PersonDraft(name: 'Ayşe\'nin kardeşi')),
      );

      final borininKisileri = await olarak(
        bora,
        () => createTestPersonRepository(db).watchPeople().first,
      );

      expect(borininKisileri.valueOrNull, isEmpty);
    });

    test('günlük kayıtları süzülüyor', () async {
      await olarak(
        ayse,
        () => createTestJournalRepository(db).save(
          JournalDraft(entryDate: kTestDatabaseNow, text: 'Ayşe\'nin günlüğü'),
        ),
      );

      final borininGunlugu = await olarak(
        bora,
        () => createTestJournalRepository(db).watchEntries().first,
      );

      expect(borininGunlugu.valueOrNull, isEmpty);
    });

    test('koleksiyonlar süzülüyor', () async {
      await olarak(
        ayse,
        () => createTestCollectionRepository(
          db,
        ).save(const CollectionDraft(title: 'Ayşe: Kapadokya 2026')),
      );

      final borininKoleksiyonlari = await olarak(
        bora,
        () => createTestCollectionRepository(db).watchCollections().first,
      );

      expect(borininKoleksiyonlari.valueOrNull, isEmpty);
    });

    test('seriler süzülüyor', () async {
      await olarak(
        ayse,
        () => createTestRitualRepository(
          db,
        ).save(const RitualDraft(title: 'Ayşe: her yıl deniz')),
      );

      final borininSerileri = await olarak(
        bora,
        () => createTestRitualRepository(db).watchRituals().first,
      );

      expect(borininSerileri.valueOrNull, isEmpty);
    });
  });

  group('sistem kategorileri', () {
    test('HER hesapta görünüyor', () async {
      // Cihaz geneli satırlar: kimlikleri sabit, hiç senkronize edilmiyorlar.
      // Sahibe göre süzseydik ikinci hesap HİÇ kategori göremez ve anı
      // kaydetme ekranı boş bir listeyle açılırdı.
      final ayseninkiler = await olarak(
        ayse,
        () => db.categoryDao.watchCategories().first,
      );
      final borininkiler = await olarak(
        bora,
        () => db.categoryDao.watchCategories().first,
      );

      expect(ayseninkiler, isNotEmpty);
      expect(
        borininkiler.map((c) => c.id),
        ayseninkiler.map((c) => c.id),
        reason: 'ikisi de AYNI sistem kategorilerini görmeli',
      );
    });
  });

  group('yazma anında damgalama', () {
    test('yeni kayıt AKTİF hesaba yazılıyor', () async {
      // Satır varsayılan 'local' ile yazılsaydı, hesaplı kullanıcı
      // kaydettiği anıyı ANINDA kaybederdi: süzgeç onu kendi kapsamının
      // dışında sayardı.
      await olarak(bora, () => aniYaz('Bora: yeni'));

      final satir = await db.select(db.memories).getSingle();
      expect(satir.ownerId, bora);
    });

    test('hesapsızken yazılan kayıt local kalıyor', () async {
      // Doldurmanın sinyali buna dayanıyor: hesap açılınca bu satırlar
      // gerçek kimliğe taşınıyor.
      db.ownerScope.leave();
      await aniYaz('Hesapsız');

      final satir = await db.select(db.memories).getSingle();
      expect(satir.ownerId, kLocalOwnerId);
      expect(await db.syncBackfillDao.needsBackfill(), isTrue);
    });
  });

  group('çıkış', () {
    test('çıkıştan sonra hesabın verisi GÖRÜNMÜYOR ama SİLİNMİYOR', () async {
      await olarak(ayse, () => aniYaz('Ayşe: kalıcı'));

      db.ownerScope.leave();
      expect(await aniBasliklari(), isEmpty, reason: 'görünmemeli');

      // Satır diskte DURUYOR — süzgeç hiçbir şey silmiyor.
      expect(await db.select(db.memories).get(), hasLength(1));

      // Aynı hesapla dönünce olduğu gibi geri geliyor.
      expect(await olarak(ayse, aniBasliklari), ['Ayşe: kalıcı']);
    });
  });

  group('doldurma', () {
    test('SİSTEM KATEGORİLERİNİ ilk hesaba YAZMIYOR', () async {
      // Yazsaydı ikinci hesap hiç kategori göremezdi.
      db.ownerScope.leave();
      await aniYaz('Hesapsız');

      await db.syncBackfillDao.run(
        ownerId: ayse,
        now: kTestDatabaseNow,
        nextOutboxId: () => 'kuyruk-${DateTime.now().microsecondsSinceEpoch}',
      );

      final kategoriler = await db.select(db.categories).get();
      expect(
        kategoriler.every((c) => c.ownerId == kLocalOwnerId),
        isTrue,
        reason: 'sistem kategorileri cihaz geneli kalmalı',
      );

      // Ama içerik gerçekten Ayşe'ye taşınmış olmalı.
      expect((await db.select(db.memories).getSingle()).ownerId, ayse);
      expect(await db.syncBackfillDao.needsBackfill(), isFalse);
    });
  });
}
