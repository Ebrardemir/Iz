/// Senkronizasyon motorunun davranışı.
///
/// SAHTE SUNUCU + GERÇEK VERİTABANI. Sunucuyu sahteliyoruz çünkü test etmek
/// istediğimiz şeylerin çoğu — "sunucu çakışma döndü", "ağ koptu", "sunucu
/// tanımadığımız bir durum bildirdi" — gerçek bir sunucuyla isteyerek
/// üretilemez. Veritabanı ise gerçek (bellek içi): kuyruğun gerçekten
/// boşaldığını, satırın gerçekten yazıldığını SQL üzerinden görüyoruz.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/storage/secure_store.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/sync/data/daos/outbox_dao.dart';
import 'package:iz/features/sync/data/repositories/sync_engine.dart';
import 'package:iz/features/sync/data/sources/sync_api.dart';
import 'package:iz/features/sync/domain/entities/outbox_operation.dart';
import 'package:iz/features/sync/domain/repositories/sync_identity.dart';

import '../helpers/test_database.dart';

// --- Sahteler -------------------------------------------------------------

final class _FakeSecureStore implements SecureStore {
  final Map<SecureKey, String> _degerler = {};

  @override
  Future<String?> read(SecureKey key) async => _degerler[key];

  @override
  Future<void> write(SecureKey key, String value) async =>
      _degerler[key] = value;

  @override
  Future<void> delete(SecureKey key) async => _degerler.remove(key);

  @override
  Future<void> clear() async => _degerler.clear();
}

final class _FakeIdentity implements SyncIdentity {
  _FakeIdentity({this.userId = 'kullanici-1'});

  final String? userId;

  @override
  Future<String?> ownerId() async => userId;
}

final class _FakeSyncApi implements SyncApi {
  _FakeSyncApi({
    this.deviceId = 'cihaz-A',
    this.pushYaniti,
    this.pullSayfalari = const [],
    this.pushHatasi,
  });

  final String deviceId;
  SyncPushResponse Function(List<SyncPushChange> changes)? pushYaniti;
  final List<SyncPullPage> pullSayfalari;
  Failure? pushHatasi;

  final List<String> kullanilanAnahtarlar = [];
  final List<List<SyncPushChange>> gonderilenGruplar = [];
  final List<int> istenenCursorlar = [];

  /// Push ve pull'un HANGİ SIRAYLA çağrıldığını kaydediyor.
  final List<String> cagriSirasi = [];

  int _sayfaIndeksi = 0;

  @override
  Future<Result<RemoteDevice>> registerDevice({
    String? id,
    required String platform,
    String? appVersion,
    int? schemaVersion,
  }) async => Ok(RemoteDevice(id: id ?? deviceId, platform: platform));

  @override
  Future<Result<SyncPushResponse>> push({
    required String deviceId,
    required String idempotencyKey,
    required List<SyncPushChange> changes,
  }) async {
    cagriSirasi.add('push');
    kullanilanAnahtarlar.add(idempotencyKey);
    gonderilenGruplar.add(changes);

    if (pushHatasi case final hata?) return Err(hata);

    return Ok(
      pushYaniti?.call(changes) ??
          SyncPushResponse(
            results: [
              for (final c in changes)
                SyncPushChangeResult(
                  entityId: c.entityId,
                  status: SyncPushStatus.applied,
                  version: 1,
                  seq: 1,
                ),
            ],
            cursor: 1,
          ),
    );
  }

  @override
  Future<Result<SyncPullPage>> pull({required int cursor, int? limit}) async {
    cagriSirasi.add('pull');
    istenenCursorlar.add(cursor);

    if (_sayfaIndeksi >= pullSayfalari.length) {
      return Ok(
        SyncPullPage(changes: const [], nextCursor: cursor, hasMore: false),
      );
    }
    return Ok(pullSayfalari[_sayfaIndeksi++]);
  }

  @override
  Future<Result<SyncServerState>> state({required int cursor}) async =>
      const Ok(SyncServerState(serverCursor: 0, pendingCount: 0));
}

// --- Yardımcılar ----------------------------------------------------------

Map<String, Object?> _aniEntity({
  String id = 'ani-1',
  String? baslik = 'Kahve molası',
  int version = 1,
}) => {
  'id': id,
  'title': baslik,
  'occurred_at': '2026-03-12T10:00:00.000Z',
  'occurred_year': 2026,
  'occurred_month': 3,
  'occurred_day': 12,
  'created_at': '2026-03-01T08:00:00.000Z',
  'updated_at': '2026-03-12T10:00:00.000Z',
  'version': version,
};

String _payload(Map<String, Object?> entity) =>
    '{"v":1,"entity":${_json(entity)}}';

String _json(Object? value) => switch (value) {
  null => 'null',
  final String it => '"${it.replaceAll('"', r'\"')}"',
  final bool it => '$it',
  final num it => '$it',
  final Map<String, Object?> it =>
    '{${it.entries.map((e) => '"${e.key}":${_json(e.value)}').join(',')}}',
  _ => 'null',
};

void main() {
  late AppDatabase db;
  late OutboxDao outbox;
  late _FakeSecureStore store;

  final simdi = DateTime.utc(2026, 9, 9, 12);

  setUp(() {
    db = createTestDatabase();
    outbox = OutboxDao(db);
    store = _FakeSecureStore();
  });

  tearDown(() => db.close());

  SyncEngine motor(_FakeSyncApi api, {SyncIdentity? identity}) => SyncEngine(
    database: db,
    api: api,
    identity: identity ?? _FakeIdentity(),
    secureStore: store,
    clock: FixedClock(simdi),
    idGenerator: SequentialIdGenerator(prefix: 'cakisma-'),
    platform: 'android',
  );

  Future<void> kuyrugaEkle({
    String id = 'kuyruk-1',
    String entityType = 'memory',
    String entityId = 'ani-1',
    OutboxOperation op = OutboxOperation.create,
    int baseVersion = 0,
    Map<String, Object?>? entity,
  }) => outbox.enqueue(
    id: id,
    entityType: entityType,
    entityId: entityId,
    op: op,
    payloadJson: _payload(entity ?? _aniEntity(id: entityId)),
    baseVersion: baseVersion,
    now: simdi,
  );

  // --- Push ---------------------------------------------------------------

  group('push', () {
    test('kuyruk gerçekten boşalıyor', () async {
      await kuyrugaEkle();
      final api = _FakeSyncApi();

      final sonuc = await motor(api).syncNow();

      expect(sonuc.isOk, isTrue);
      expect(sonuc.valueOrNull!.pushed, 1);
      expect(await outbox.pending(), isEmpty);
    });

    test('SUNUCU SÜRÜMÜ yerel satıra yazılıyor', () async {
      // Yazmazsak bir sonraki push eski bir baseVersion gönderir ve kullanıcı
      // KENDİ değişikliğini "başka bir sürüm" olarak görür.
      await db.syncDao.applyUpsert(
        entityType: 'memory',
        entityId: 'ani-1',
        payload: _aniEntity(),
        ownerId: 'kullanici-1',
      );
      await kuyrugaEkle();

      final api = _FakeSyncApi(
        pushYaniti: (changes) => SyncPushResponse(
          results: [
            SyncPushChangeResult(
              entityId: changes.first.entityId,
              status: SyncPushStatus.applied,
              version: 9,
              seq: 4,
            ),
          ],
          cursor: 4,
        ),
      );

      await motor(api).syncNow();

      final satir = await (db.select(
        db.memories,
      )..where((t) => t.id.equals('ani-1'))).getSingle();

      expect(satir.version, 9);
    });

    test('AYNI grup için anahtar DEĞİŞMİYOR', () async {
      // Yeniden denemede anahtar değişseydi sunucu bunu yeni bir istek sayar
      // ve ilk denemede artmış sürüm yüzünden yanlış çakışma dönerdi.
      await kuyrugaEkle(id: 'kuyruk-1', entityId: 'ani-1');
      await kuyrugaEkle(id: 'kuyruk-2', entityId: 'ani-2');

      // Ağ hatası: kuyruk olduğu gibi kalıyor.
      final basarisiz = _FakeSyncApi(
        pushHatasi: const NetworkFailure(message: 'koptu'),
      );
      await motor(basarisiz).syncNow();

      final ikinci = _FakeSyncApi();
      await motor(ikinci).syncNow();

      expect(
        basarisiz.kullanilanAnahtarlar.single,
        ikinci.kullanilanAnahtarlar.single,
      );
    });

    test('grup DEĞİŞİRSE anahtar da değişiyor', () async {
      await kuyrugaEkle(id: 'kuyruk-1', entityId: 'ani-1');
      final tek = _FakeSyncApi(pushHatasi: const NetworkFailure(message: 'x'));
      await motor(tek).syncNow();

      await kuyrugaEkle(id: 'kuyruk-2', entityId: 'ani-2');
      final cift = _FakeSyncApi(pushHatasi: const NetworkFailure(message: 'x'));
      await motor(cift).syncNow();

      expect(
        tek.kullanilanAnahtarlar.single,
        isNot(cift.kullanilanAnahtarlar.single),
      );
    });

    test('ağ hatasında kuyruk KORUNUYOR', () async {
      await kuyrugaEkle();
      final api = _FakeSyncApi(
        pushHatasi: const NetworkFailure(message: 'koptu'),
      );

      final sonuc = await motor(api).syncNow();

      expect(sonuc.isErr, isTrue);
      expect(await outbox.pending(), hasLength(1));

      // Hata deftere yazılıyor — Yedekleme Sağlığı ekranı bunu gösteriyor.
      final defter = await db.syncStateDao.current();
      expect(defter.lastError, isNotNull);
    });
  });

  group('çakışma', () {
    test('kaybolacak metin SyncConflicts\'e kurtarılıyor', () async {
      await kuyrugaEkle(entity: _aniEntity(baslik: 'Benim yazdığım'));

      final api = _FakeSyncApi(
        pushYaniti: (changes) => SyncPushResponse(
          results: [
            SyncPushChangeResult(
              entityId: 'ani-1',
              status: SyncPushStatus.conflict,
              server: SyncServerVersion(
                version: 3,
                payload: _aniEntity(baslik: 'Sunucudaki hâli'),
              ),
            ),
          ],
          cursor: 0,
        ),
      );

      final sonuc = await motor(api).syncNow();

      expect(sonuc.valueOrNull!.conflicted, 1);

      final cakisma = await db.select(db.syncConflicts).getSingle();
      expect(cakisma.entityId, 'ani-1');
      expect(cakisma.field, 'title');
      expect(cakisma.localValue, 'Benim yazdığım');
      expect(cakisma.serverValue, 'Sunucudaki hâli');
      expect(cakisma.resolvedAt, isNull);

      // Aynı gövdeyi yeniden göndermek yine çakışırdı; satır kuyruktan
      // düşüyor ve sunucudaki sürüm hemen ardından gelen pull ile iniyor.
      expect(await outbox.pending(), isEmpty);
    });

    test('değişmeyen alan çakışma sayılmıyor', () async {
      // Kullanıcıya gösterecek bir fark yoksa çakışma kaydı gürültüdür.
      await kuyrugaEkle(entity: _aniEntity(baslik: 'Aynı başlık'));

      final api = _FakeSyncApi(
        pushYaniti: (changes) => SyncPushResponse(
          results: [
            SyncPushChangeResult(
              entityId: 'ani-1',
              status: SyncPushStatus.conflict,
              server: SyncServerVersion(
                version: 3,
                payload: _aniEntity(baslik: 'Aynı başlık'),
              ),
            ),
          ],
          cursor: 0,
        ),
      );

      await motor(api).syncNow();

      expect(await db.select(db.syncConflicts).get(), isEmpty);
    });
  });

  group('reddetme', () {
    test('KALICI red satırı kuyruktan düşürüyor', () async {
      // Tekrar denemek düzeltmez; satır kalırsa kuyruk sonsuza kadar tıkanır.
      await kuyrugaEkle();

      final api = _FakeSyncApi(
        pushYaniti: (_) => const SyncPushResponse(
          results: [
            SyncPushChangeResult(
              entityId: 'ani-1',
              status: SyncPushStatus.rejected,
              reason: 'payload_encoding_invalid',
            ),
          ],
          cursor: 0,
        ),
      );

      final sonuc = await motor(api).syncNow();

      expect(sonuc.valueOrNull!.rejected, 1);
      expect(await outbox.pending(), isEmpty);
    });

    test('GEÇİCİ red satırı kuyrukta TUTUYOR', () async {
      // `entitlement_required` abonelik alınınca düzelir; düşürseydik
      // kullanıcının o değişikliği hiçbir zaman buluta çıkmazdı.
      await kuyrugaEkle();

      final api = _FakeSyncApi(
        pushYaniti: (_) => const SyncPushResponse(
          results: [
            SyncPushChangeResult(
              entityId: 'ani-1',
              status: SyncPushStatus.rejected,
              reason: 'entitlement_required',
            ),
          ],
          cursor: 0,
        ),
      );

      await motor(api).syncNow();

      final kalan = await outbox.pending();
      expect(kalan, hasLength(1));
      expect(kalan.single.attemptCount, 1);
      expect(kalan.single.lastError, 'entitlement_required');
    });

    test('TANIMADIĞIMIZ durum satırı düşürmüyor', () async {
      // Anlamadığımız bir cevabı "başarılı" saymak veriyi kaybetmek olurdu.
      await kuyrugaEkle();

      final api = _FakeSyncApi(
        pushYaniti: (_) => const SyncPushResponse(
          results: [
            SyncPushChangeResult(
              entityId: 'ani-1',
              status: SyncPushStatus.unknown,
            ),
          ],
          cursor: 0,
        ),
      );

      await motor(api).syncNow();

      expect(await outbox.pending(), hasLength(1));
    });

    test('ilerleme yoksa SONSUZ DÖNGÜYE girmiyor', () async {
      // Hiçbir satır kuyruktan düşmezse bir sonraki tur aynı satırları çeker.
      await kuyrugaEkle();

      final api = _FakeSyncApi(
        pushYaniti: (_) => const SyncPushResponse(
          results: [
            SyncPushChangeResult(
              entityId: 'ani-1',
              status: SyncPushStatus.unknown,
            ),
          ],
          cursor: 0,
        ),
      );

      await motor(api).syncNow().timeout(const Duration(seconds: 5));

      // Tek denemede durdu.
      expect(api.gonderilenGruplar, hasLength(1));
    });
  });

  // --- Pull ---------------------------------------------------------------

  group('pull', () {
    test('inen kayıt yerele yazılıyor ve cursor kaydediliyor', () async {
      final api = _FakeSyncApi(
        pullSayfalari: [
          SyncPullPage(
            changes: [
              SyncRemoteChange(
                seq: 5,
                entityType: 'memory',
                entityId: 'ani-uzak',
                isDelete: false,
                version: 2,
                deviceId: 'baska-cihaz',
                payload: _aniEntity(id: 'ani-uzak', baslik: 'B cihazından'),
              ),
            ],
            nextCursor: 5,
            hasMore: false,
          ),
        ],
      );

      final sonuc = await motor(api).syncNow();

      expect(sonuc.valueOrNull!.pulled, 1);

      final satir = await (db.select(
        db.memories,
      )..where((t) => t.id.equals('ani-uzak'))).getSingle();
      expect(satir.title, 'B cihazından');

      final defter = await db.syncStateDao.current();
      expect(defter.cursor, '5');
    });

    test('KENDİ cihazımızın satırları ATLANIYOR — echo önleme', () async {
      // Az önce kendi gönderdiğimizi geri alıp yeniden uygulamak hem
      // gereksiz iş hem de o sırada yapılan yeni düzenlemeyi ezme riski.
      final api = _FakeSyncApi(
        pullSayfalari: [
          SyncPullPage(
            changes: [
              SyncRemoteChange(
                seq: 5,
                entityType: 'memory',
                entityId: 'kendi-yazdigim',
                isDelete: false,
                version: 2,
                deviceId: 'cihaz-A', // bizim cihazımız
                payload: _aniEntity(id: 'kendi-yazdigim'),
              ),
            ],
            nextCursor: 5,
            hasMore: false,
          ),
        ],
      );

      final sonuc = await motor(api).syncNow();

      expect(sonuc.valueOrNull!.pulled, 0);
      expect(await db.select(db.memories).get(), isEmpty);

      // Cursor YİNE İLERLİYOR: satır bize gerekmiyor ama tüketildi.
      expect((await db.syncStateDao.current()).cursor, '5');
    });

    test('BAĞ ebeveyninden önce gelse de sayfa uygulanıyor', () async {
      // İstemcide bağ tablolarının yabancı anahtarı var (sunucuda bilinçli
      // olarak yok). Sunucu sayfayı seq sırasında veriyor ve sayfa içi
      // birleştirme yüzünden bağ, ebeveyninden ÖNCE gelebiliyor. Sıralamayı
      // motor düzeltmeseydi SQLite kısıtı patlar ve SAYFANIN TAMAMI
      // uygulanamazdı.
      final api = _FakeSyncApi(
        pullSayfalari: [
          SyncPullPage(
            changes: [
              // Önce BAĞ (küçük seq)
              const SyncRemoteChange(
                seq: 2,
                entityType: 'memory_people',
                entityId: 'ani-x:kisi-y',
                isDelete: false,
                version: 1,
                deviceId: 'baska',
                payload: {
                  'memory_id': 'ani-x',
                  'person_id': 'kisi-y',
                  'updated_at': '2026-03-12T10:00:00.000Z',
                  'version': 1,
                },
              ),
              // Sonra EBEVEYNLER (büyük seq)
              SyncRemoteChange(
                seq: 3,
                entityType: 'memory',
                entityId: 'ani-x',
                isDelete: false,
                version: 2,
                deviceId: 'baska',
                payload: _aniEntity(id: 'ani-x'),
              ),
              const SyncRemoteChange(
                seq: 4,
                entityType: 'person',
                entityId: 'kisi-y',
                isDelete: false,
                version: 1,
                deviceId: 'baska',
                payload: {
                  'id': 'kisi-y',
                  'name': 'Kardeşim',
                  'created_at': '2026-01-01T00:00:00.000Z',
                  'updated_at': '2026-01-01T00:00:00.000Z',
                  'version': 1,
                },
              ),
            ],
            nextCursor: 4,
            hasMore: false,
          ),
        ],
      );

      final sonuc = await motor(api).syncNow();

      expect(sonuc.valueOrNull!.pulled, 3);
      expect(sonuc.valueOrNull!.skipped, 0);
      expect(await db.select(db.memoryPeople).get(), hasLength(1));
    });

    test('hasMore ise sonraki sayfa da çekiliyor', () async {
      final api = _FakeSyncApi(
        pullSayfalari: [
          SyncPullPage(
            changes: [
              SyncRemoteChange(
                seq: 1,
                entityType: 'memory',
                entityId: 'ani-1',
                isDelete: false,
                version: 1,
                deviceId: 'baska',
                payload: _aniEntity(id: 'ani-1'),
              ),
            ],
            nextCursor: 1,
            hasMore: true,
          ),
          SyncPullPage(
            changes: [
              SyncRemoteChange(
                seq: 2,
                entityType: 'memory',
                entityId: 'ani-2',
                isDelete: false,
                version: 1,
                deviceId: 'baska',
                payload: _aniEntity(id: 'ani-2'),
              ),
            ],
            nextCursor: 2,
            hasMore: false,
          ),
        ],
      );

      final sonuc = await motor(api).syncNow();

      expect(sonuc.valueOrNull!.pulled, 2);
      expect(api.istenenCursorlar, [0, 1]);
      expect((await db.syncStateDao.current()).cursor, '2');
    });

    test('silme yerelde TOMBSTONE olarak uygulanıyor', () async {
      await db.syncDao.applyUpsert(
        entityType: 'memory',
        entityId: 'ani-1',
        payload: _aniEntity(),
        ownerId: 'kullanici-1',
      );

      final api = _FakeSyncApi(
        pullSayfalari: [
          const SyncPullPage(
            changes: [
              SyncRemoteChange(
                seq: 9,
                entityType: 'memory',
                entityId: 'ani-1',
                isDelete: true,
                version: 3,
                deviceId: 'baska',
              ),
            ],
            nextCursor: 9,
            hasMore: false,
          ),
        ],
      );

      await motor(api).syncNow();

      final satir = await (db.select(
        db.memories,
      )..where((t) => t.id.equals('ani-1'))).getSingle();

      expect(satir.deletedAt, isNotNull);
      expect(satir.version, 3);
    });
  });

  // --- Sıra ve kimlik ------------------------------------------------------

  group('tur düzeni', () {
    test('ÖNCE PUSH SONRA PULL', () async {
      // Tersi olsaydı, bekleyen bir değişiklik varken inen sunucu sürümü onu
      // ezerdi ve kullanıcı henüz göndermediği yazısını kaybederdi.
      await kuyrugaEkle();
      final api = _FakeSyncApi();

      await motor(api).syncNow();

      expect(api.cagriSirasi.first, 'push');
      expect(api.cagriSirasi.contains('pull'), isTrue);
      expect(
        api.cagriSirasi.indexOf('push'),
        lessThan(api.cagriSirasi.indexOf('pull')),
      );
    });

    test('oturum yoksa eşitleme YAPILMIYOR', () async {
      await kuyrugaEkle();
      final api = _FakeSyncApi();

      final sonuc = await motor(
        api,
        identity: _FakeIdentity(userId: null),
      ).syncNow();

      expect(sonuc.isErr, isTrue);
      expect(sonuc.failureOrNull, isA<AuthFailure>());
      expect(api.gonderilenGruplar, isEmpty);
      expect(await outbox.pending(), hasLength(1));
    });

    test('cihaz kimliği saklanıyor ve yeniden kullanılıyor', () async {
      final api = _FakeSyncApi(deviceId: 'sunucunun-verdigi');

      await motor(api).syncNow();
      expect(await store.read(SecureKey.izDeviceId), 'sunucunun-verdigi');

      await motor(api).syncNow();
      // İkinci turda aynı kimlik gönderiliyor; sunucu yeni kayıt açmıyor.
      expect(await store.read(SecureKey.izDeviceId), 'sunucunun-verdigi');
    });

    test('başarılı tur ESKİ HATAYI temizliyor', () async {
      // Ekranda eski bir hata durursa kullanıcı hâlâ bozuk sanır.
      await kuyrugaEkle();
      await motor(
        _FakeSyncApi(pushHatasi: const NetworkFailure(message: 'koptu')),
      ).syncNow();
      expect((await db.syncStateDao.current()).lastError, isNotNull);

      await motor(_FakeSyncApi()).syncNow();
      expect((await db.syncStateDao.current()).lastError, isNull);
    });

    test('tur sonunda bekleyen sayısı deftere yazılıyor', () async {
      await kuyrugaEkle(id: 'kuyruk-1', entityId: 'ani-1');

      final api = _FakeSyncApi(
        pushYaniti: (_) => const SyncPushResponse(
          results: [
            SyncPushChangeResult(
              entityId: 'ani-1',
              status: SyncPushStatus.rejected,
              reason: 'entitlement_required',
            ),
          ],
          cursor: 0,
        ),
      );

      final sonuc = await motor(api).syncNow();

      expect(sonuc.valueOrNull!.pendingAfter, 1);
      expect((await db.syncStateDao.current()).pendingCount, 1);
    });
  });
}
