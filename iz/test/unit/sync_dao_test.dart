/// Sunucudan inen değişikliğin yerele yazılması.
///
/// GERÇEK SQL üzerinde koşuyor (bellek içi Drift): mock ile yazsaydık yalnız
/// "doğru metodu çağırdım mı"yı ölçerdik, oysa buradaki asıl risk sütun
/// eşlemesi — yanlış eşlenen bir alan kullanıcının ikinci cihazında BOŞ
/// görünür ve hiçbir hata üretmez.
///
/// Gövdeler sunucunun gerçekten ürettiği biçimde: snake_case anahtarlar,
/// ISO-8601 tarihler.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/sync/data/daos/sync_dao.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncDao dao;

  const sahip = 'kullanici-1';
  final simdi = DateTime.utc(2026, 9, 9, 12);

  setUp(() {
    db = createTestDatabase();
    dao = db.syncDao;
  });

  tearDown(() => db.close());

  Map<String, Object?> aniGovdesi({
    String id = 'ani-1',
    String? baslik = 'Kahve molası',
    int version = 1,
    String? silindi,
  }) => {
    'id': id,
    'owner_id': 'sunucudaki-baska-kimlik',
    'title': baslik,
    'note': null,
    'occurred_at': '2026-03-12T10:00:00.000Z',
    'occurred_year': 2026,
    'occurred_month': 3,
    'occurred_day': 12,
    'is_favorite': true,
    'is_archived': false,
    'created_at': '2026-03-01T08:00:00.000Z',
    'updated_at': '2026-03-12T10:00:00.000Z',
    'deleted_at': silindi,
    'version': version,
  };

  /// Bağın ebeveynlerini açar.
  ///
  /// GEREKLİ: istemcide bağ tablolarının YABANCI ANAHTARI var (sunucuda
  /// bilinçli olarak yok). Ebeveynsiz bir bağ yazmak SQLite kısıtını
  /// patlatıyor — motorun sayfayı uygularken çözmesi gereken sıralama
  /// sorununun kaynağı da bu.
  Future<void> ebeveynleriAc() async {
    await dao.applyUpsert(
      entityType: 'memory',
      entityId: 'ani-1',
      payload: aniGovdesi(),
      ownerId: sahip,
    );
    await dao.applyUpsert(
      entityType: 'person',
      entityId: 'kisi-9',
      payload: {
        'id': 'kisi-9',
        'name': 'Kardeşim',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
        'version': 1,
      },
      ownerId: sahip,
    );
    await dao.applyUpsert(
      entityType: 'media_item',
      entityId: 'medya-3',
      payload: {
        'id': 'medya-3',
        'type': 'photo',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
        'version': 1,
      },
      ownerId: sahip,
    );
  }

  group('upsert', () {
    test('anı tüm alanlarıyla yazılıyor', () async {
      final yazildi = await dao.applyUpsert(
        entityType: 'memory',
        entityId: 'ani-1',
        payload: aniGovdesi(),
        ownerId: sahip,
      );

      expect(yazildi, isTrue);

      final satir = await (db.select(
        db.memories,
      )..where((t) => t.id.equals('ani-1'))).getSingle();

      expect(satir.title, 'Kahve molası');
      expect(satir.isFavorite, isTrue);
      expect(satir.version, 1);
      expect(satir.deletedAt, isNull);

      // TARİH PARÇALARI GÖVDEDEN, occurredAt'ten HESAPLANMIYOR: onlar kaydın
      // YEREL gününü taşıyor ve UTC'den türetmek anıyı yanlış güne düşürürdü.
      expect(satir.occurredYear, 2026);
      expect(satir.occurredMonth, 3);
      expect(satir.occurredDay, 12);
    });

    test('SAHİPLİK gövdeden DEĞİL, oturumdan yazılıyor', () async {
      // Sunucu `owner_id`yi kendi kimliğiyle dolduruyor; yerel tabloya
      // yazılması gereken ise bu cihazda oturum açmış kullanıcınınki.
      await dao.applyUpsert(
        entityType: 'memory',
        entityId: 'ani-1',
        payload: aniGovdesi(),
        ownerId: sahip,
      );

      final satir = await (db.select(
        db.memories,
      )..where((t) => t.id.equals('ani-1'))).getSingle();

      expect(satir.ownerId, sahip);
      expect(satir.ownerId, isNot('sunucudaki-baska-kimlik'));
    });

    test('aynı gövde iki kez uygulanabiliyor — idempotent', () async {
      // Pull yarıda kesilirse aynı sayfa tekrar gelir; uygulama idempotent
      // olmasaydı ikinci deneme ya patlar ya kopya üretirdi.
      await dao.applyUpsert(
        entityType: 'memory',
        entityId: 'ani-1',
        payload: aniGovdesi(),
        ownerId: sahip,
      );
      await dao.applyUpsert(
        entityType: 'memory',
        entityId: 'ani-1',
        payload: aniGovdesi(),
        ownerId: sahip,
      );

      expect(await db.select(db.memories).get(), hasLength(1));
    });

    test('var olan kaydın üzerine yazılıyor', () async {
      await dao.applyUpsert(
        entityType: 'memory',
        entityId: 'ani-1',
        payload: aniGovdesi(baslik: 'İlk'),
        ownerId: sahip,
      );
      await dao.applyUpsert(
        entityType: 'memory',
        entityId: 'ani-1',
        payload: aniGovdesi(baslik: 'Sunucudaki hâli', version: 5),
        ownerId: sahip,
      );

      final satir = await (db.select(
        db.memories,
      )..where((t) => t.id.equals('ani-1'))).getSingle();

      expect(satir.title, 'Sunucudaki hâli');
      expect(satir.version, 5);
    });

    test('bağ satırı BİLEŞİK kimlikten çözülüyor', () async {
      await ebeveynleriAc();
      final yazildi = await dao.applyUpsert(
        entityType: 'memory_people',
        entityId: 'ani-1:kisi-9',
        payload: {
          'memory_id': 'ani-1',
          'person_id': 'kisi-9',
          'role': 'kardeşim',
          'updated_at': '2026-03-12T10:00:00.000Z',
          'deleted_at': null,
          'version': 1,
        },
        ownerId: sahip,
      );

      expect(yazildi, isTrue);

      final bag = await (db.select(
        db.memoryPeople,
      )..where((t) => t.memoryId.equals('ani-1'))).getSingle();

      expect(bag.personId, 'kisi-9');
      expect(bag.role, 'kardeşim');
    });

    test('TANIMADIĞIMIZ tür istisna atmıyor, false dönüyor', () async {
      // Sunucudan yeni bir tablo geldiğinde o satırı atlayıp devam etmek,
      // bütün sayfayı uygulanamaz yapmaktan iyidir: cursor ilerlemezse
      // kullanıcı bir daha asla eşitlenemez.
      final yazildi = await dao.applyUpsert(
        entityType: 'gelecekteki_tablo',
        entityId: 'x',
        payload: const {},
        ownerId: sahip,
      );

      expect(yazildi, isFalse);
    });

    test('bozuk bağ kimliği yazmıyor', () async {
      // "uuid:uuid" değil tekil bir kimlik geldiğinde bağı varsayılan bir
      // anahtarla yazmak, kullanıcının anısını tanımadığı bir kişiye
      // bağlamak olurdu.
      expect(
        await dao.applyUpsert(
          entityType: 'memory_people',
          entityId: 'ayirac-yok',
          payload: const {},
          ownerId: sahip,
        ),
        isFalse,
      );

      expect(await db.select(db.memoryPeople).get(), isEmpty);
    });
  });

  group('enum alanları', () {
    test('bilinen değer çözülüyor', () async {
      await dao.applyUpsert(
        entityType: 'person',
        entityId: 'kisi-1',
        payload: {
          'id': 'kisi-1',
          'name': 'Annem',
          'kind': 'human',
          'relation_type': 'parent',
          'is_favorite': false,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
          'version': 1,
        },
        ownerId: sahip,
      );

      final satir = await (db.select(
        db.people,
      )..where((t) => t.id.equals('kisi-1'))).getSingle();

      expect(satir.relationType, RelationType.parent);
      expect(satir.kind, PersonKind.human);
    });

    test('TANIMADIĞIMIZ enum değeri kaydı düşürmüyor', () async {
      // Sunucuda bu alanlar METİN (bilinçli); istemcide dar tip. Sunucudan
      // yeni bir değer geldiğinde kaydı hiç yazmamak, kullanıcının kişisini
      // ikinci cihazda hiç göstermemek olurdu.
      await dao.applyUpsert(
        entityType: 'person',
        entityId: 'kisi-2',
        payload: {
          'id': 'kisi-2',
          'name': 'Komşu',
          'kind': 'android',
          'relation_type': 'gelecekteki_iliski',
          'is_favorite': false,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
          'version': 1,
        },
        ownerId: sahip,
      );

      final satir = await (db.select(
        db.people,
      )..where((t) => t.id.equals('kisi-2'))).getSingle();

      // Kayıt YAZILDI; yalnız tanınmayan alanlar varsayılana düştü.
      expect(satir.name, 'Komşu');
      expect(satir.kind, PersonKind.human);
      expect(satir.relationType, RelationType.other);
    });

    test('günlük gizlilik modu çözülüyor', () async {
      await dao.applyUpsert(
        entityType: 'journal_entry',
        entityId: 'gunluk-1',
        payload: {
          'id': 'gunluk-1',
          'entry_date': '2026-03-12T00:00:00.000Z',
          'content': 'Bugün',
          'privacy_mode': 'locked',
          'is_favorite': false,
          'created_at': '2026-03-12T00:00:00.000Z',
          'updated_at': '2026-03-12T00:00:00.000Z',
          'version': 1,
        },
        ownerId: sahip,
      );

      final satir = await (db.select(
        db.journalEntries,
      )..where((t) => t.id.equals('gunluk-1'))).getSingle();

      expect(satir.privacyMode, JournalPrivacyMode.locked);
      expect(satir.content, 'Bugün');
    });
  });

  group('silme', () {
    test('TOMBSTONE yazılıyor, satır silinmiyor', () async {
      // Gerçekten silseydik outbox'ta bekleyen bir satırın gövdesi okunamaz
      // hâle gelirdi; ayrıca FR-015'in çöp kutusu da tombstone'a dayanıyor.
      await dao.applyUpsert(
        entityType: 'memory',
        entityId: 'ani-1',
        payload: aniGovdesi(),
        ownerId: sahip,
      );

      await dao.applyDelete(
        entityType: 'memory',
        entityId: 'ani-1',
        version: 2,
        now: simdi,
      );

      final satir = await (db.select(
        db.memories,
      )..where((t) => t.id.equals('ani-1'))).getSingle();

      expect(satir.deletedAt, isNotNull);
      expect(satir.version, 2);
    });

    test('YEREL DE OLMAYAN kayıt için hayalet satır açılmıyor', () async {
      await dao.applyDelete(
        entityType: 'memory',
        entityId: 'hic-olmayan',
        version: 1,
        now: simdi,
      );

      expect(await db.select(db.memories).get(), isEmpty);
    });

    test('bağ silmesi bileşik kimlikle uygulanıyor', () async {
      await ebeveynleriAc();
      await dao.applyUpsert(
        entityType: 'memory_people',
        entityId: 'ani-1:kisi-9',
        payload: {
          'memory_id': 'ani-1',
          'person_id': 'kisi-9',
          'updated_at': '2026-03-12T10:00:00.000Z',
          'version': 1,
        },
        ownerId: sahip,
      );

      await dao.applyDelete(
        entityType: 'memory_people',
        entityId: 'ani-1:kisi-9',
        version: 2,
        now: simdi,
      );

      final bag = await (db.select(
        db.memoryPeople,
      )..where((t) => t.memoryId.equals('ani-1'))).getSingle();

      expect(bag.deletedAt, isNotNull);
      expect(bag.version, 2);
    });
  });

  group('sunucu sürümünü yazma', () {
    test('yalnız version değişiyor, updatedAt DOKUNULMUYOR', () async {
      // Kaydın içeriği değişmedi; yalnız sunucudaki karşılığının numarası
      // öğrenildi. Tazeleseydik "son düzenleme" tarihi kullanıcının hiçbir
      // şey yapmadığı bir ana kayardı.
      await dao.applyUpsert(
        entityType: 'memory',
        entityId: 'ani-1',
        payload: aniGovdesi(),
        ownerId: sahip,
      );

      final once = await (db.select(
        db.memories,
      )..where((t) => t.id.equals('ani-1'))).getSingle();

      await dao.setServerVersion(
        entityType: 'memory',
        entityId: 'ani-1',
        version: 7,
      );

      final sonra = await (db.select(
        db.memories,
      )..where((t) => t.id.equals('ani-1'))).getSingle();

      expect(sonra.version, 7);
      expect(sonra.updatedAt, once.updatedAt);
      expect(sonra.title, once.title);
    });

    test('bağın sürümü de yazılabiliyor', () async {
      await ebeveynleriAc();
      await dao.applyUpsert(
        entityType: 'memory_media',
        entityId: 'ani-1:medya-3',
        payload: {
          'memory_id': 'ani-1',
          'media_id': 'medya-3',
          'sort_order': 2,
          'updated_at': '2026-03-12T10:00:00.000Z',
          'version': 1,
        },
        ownerId: sahip,
      );

      await dao.setServerVersion(
        entityType: 'memory_media',
        entityId: 'ani-1:medya-3',
        version: 4,
      );

      final bag = await (db.select(
        db.memoryMedia,
      )..where((t) => t.memoryId.equals('ani-1'))).getSingle();

      expect(bag.version, 4);
      expect(bag.sortOrder, 2);
    });
  });

  group('outbox', () {
    test('UZAKTAN GELEN YAZMA KUYRUĞA GİRMİYOR', () async {
      // BU TESTİN KORUDUĞU ŞEY BİR DÖNGÜ: sunucudan geleni kuyruğa
      // düşürseydik onu aynı sunucuya geri gönderirdik ve her turda sürüm
      // artardı — iki cihaz birbirini sonsuza kadar tetiklerdi.
      await dao.applyUpsert(
        entityType: 'memory',
        entityId: 'ani-1',
        payload: aniGovdesi(),
        ownerId: sahip,
      );
      await dao.applyDelete(
        entityType: 'memory',
        entityId: 'ani-1',
        version: 2,
        now: simdi,
      );
      await dao.setServerVersion(
        entityType: 'memory',
        entityId: 'ani-1',
        version: 3,
      );

      expect(await db.select(db.outboxEntries).get(), isEmpty);
    });
  });
}
