/// Senkronizasyon uçlarının istemci karşılığı — sözleşme testi.
///
/// BURADAKİ GÖVDELER SUNUCUNUN GERÇEKTEN ÜRETTİĞİ GÖVDELERDİR: çalışan bir
/// sunucudan (`api/scripts/sync-dene.sh`) alınıp buraya kopyalandı. Elle
/// uydurulmuş bir gövdeye karşı test etmek, kendi varsayımımızı doğrulamak
/// olurdu — sözleşme ayrıştığında test yine yeşil yanardı.
///
/// Gerçek ağa ÇIKMIYORUZ; Dio'nun HTTP katmanı sahtesiyle değiştiriliyor.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/config/app_config.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/network/api_client.dart';
import 'package:iz/core/network/auth_token_provider.dart';
import 'package:iz/features/sync/data/sources/sync_api.dart';

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final List<ResponseBody Function(RequestOptions)> responses;
  final List<RequestOptions> requests = [];
  int _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final builder = responses[min(_index, responses.length - 1)];
    _index++;
    return builder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

({SyncApi api, _FakeAdapter adapter}) _build(
  List<ResponseBody Function(RequestOptions)> responses,
) {
  final dio = buildIzDio(
    tokens: const UnauthenticatedTokenProvider(),
    config: const AppConfig(
      environment: AppEnvironment.dev,
      apiBaseUrl: 'https://sunucu.test',
      enableVerboseLogging: false,
    ),
    random: Random(1),
  );

  dio.interceptors.removeWhere((i) => i is IzRetryInterceptor);
  dio.interceptors.add(
    IzRetryInterceptor(dio: dio, baseDelay: Duration.zero, random: Random(1)),
  );

  final adapter = _FakeAdapter(responses);
  dio.httpClientAdapter = adapter;

  return (api: SyncApi(client: IzApiClient(dio: dio)), adapter: adapter);
}

void main() {
  group('push', () {
    // Sunucudan alınmış gerçek yanıt (sync-dene.sh, adım 4).
    const uygulandi = '''
    {"results":[{"entityId":"d4503d1d-ce99-47cc-bf53-9e8d9c37f441",
      "status":"applied","version":1,"seq":11,"server":null,"reason":null}],
     "cursor":11}''';

    test('applied sonucu sürüm ve sıra ile çözülür', () async {
      final fake = _build([(_) => _json(uygulandi)]);

      final sonuc = await fake.api.push(
        deviceId: 'cihaz-1',
        idempotencyKey: 'anahtar-1',
        changes: [
          const SyncPushChange(
            entityType: 'memory',
            entityId: 'd4503d1d-ce99-47cc-bf53-9e8d9c37f441',
            op: 'upsert',
            baseVersion: 0,
            payload: {'v': 1, 'entity': <String, Object?>{}},
          ),
        ],
      );

      final govde = sonuc.valueOrNull;
      expect(govde, isNotNull);
      expect(govde!.cursor, 11);

      final tek = govde.results.single;
      expect(tek.status, SyncPushStatus.applied);
      expect(tek.version, 1);
      expect(tek.seq, 11);
      expect(tek.server, isNull);
    });

    test('Idempotency-Key BAŞLIKTA gider', () async {
      // Anahtar gövdede olsaydı her yeniden denemede gövdeyi yeniden kurmak
      // gerekirdi; retry katmanı ise yalnız isteği tekrarlıyor.
      final fake = _build([(_) => _json(uygulandi)]);

      await fake.api.push(
        deviceId: 'cihaz-1',
        idempotencyKey: 'ayni-kalmali',
        changes: const [],
      );

      expect(
        fake.adapter.requests.single.headers['Idempotency-Key'],
        'ayni-kalmali',
      );
    });

    test('push YENİDEN DENENEBİLİR olarak işaretleniyor', () async {
      // POST normalde tekrarlanmıyor: "ağ koptu sandık ama sunucu almıştı"
      // ikinci bir kayıt üretebilir. Idempotency-Key o tehlikeyi kaldırdığı
      // için push bilinçli olarak istisna.
      final fake = _build([
        (_) => _json('{"status":500}', status: 500),
        (_) => _json(uygulandi),
      ]);

      final sonuc = await fake.api.push(
        deviceId: 'cihaz-1',
        idempotencyKey: 'anahtar-1',
        changes: const [],
      );

      expect(sonuc.isOk, isTrue);
      expect(fake.adapter.requests.length, 2, reason: 'yeniden denenmeliydi');

      // Ve TEKRARDA ANAHTAR DEĞİŞMEMELİ — değişseydi sunucu bunu yeni bir
      // istek sayar ve ilk denemede artmış sürüm yüzünden çakışma dönerdi.
      expect(
        fake.adapter.requests[1].headers['Idempotency-Key'],
        fake.adapter.requests[0].headers['Idempotency-Key'],
      );
    });

    test('conflict sonucu sunucunun gövdesini taşır', () async {
      // Gerçek yanıt (sync-dene.sh, adım 7).
      final fake = _build([
        (_) => _json('''
        {"results":[{"entityId":"d4503d1d","status":"conflict","version":null,
          "seq":null,
          "server":{"version":2,"payload":{"id":"d4503d1d",
            "title":"Kahve molası — düzenlendi","occurred_year":2026,
            "deleted_at":null,"version":2}},
          "reason":null}],"cursor":13}'''),
      ]);

      final tek = (await fake.api.push(
        deviceId: 'c',
        idempotencyKey: 'a',
        changes: const [],
      )).valueOrNull!.results.single;

      expect(tek.status, SyncPushStatus.conflict);
      expect(tek.version, isNull);
      expect(tek.server!.version, 2);

      // Gövde snake_case: sunucu istemcinin SÜTUN adlarını aynalıyor.
      expect(tek.server!.payload['title'], 'Kahve molası — düzenlendi');
      expect(tek.server!.payload['occurred_year'], 2026);
    });

    test('rejected sonucu sebebi taşır', () async {
      final fake = _build([
        (_) => _json('''
        {"results":[{"entityId":"x","status":"rejected","version":null,
          "seq":null,"server":null,"reason":"unknown_entity_type"}],
         "cursor":0}'''),
      ]);

      final tek = (await fake.api.push(
        deviceId: 'c',
        idempotencyKey: 'a',
        changes: const [],
      )).valueOrNull!.results.single;

      expect(tek.status, SyncPushStatus.rejected);
      expect(tek.reason, 'unknown_entity_type');
    });

    test('TANIMADIĞIMIZ durum ayrıştırmayı çökertmiyor', () async {
      // Sunucudan yeni bir istemci olduğumuz anlamına gelir. Hata sayarsak
      // tek bir bilinmeyen durum, o kullanıcının BÜTÜN kuyruğunu okunamaz
      // yapardı.
      final fake = _build([
        (_) => _json('''
        {"results":[{"entityId":"x","status":"gelecekteki_durum","version":null,
          "seq":null,"server":null,"reason":null}],"cursor":0}'''),
      ]);

      final sonuc = await fake.api.push(
        deviceId: 'c',
        idempotencyKey: 'a',
        changes: const [],
      );

      expect(sonuc.isOk, isTrue);
      expect(sonuc.valueOrNull!.results.single.status, SyncPushStatus.unknown);
    });

    test('seq null olabilir — değişmeyen kayıt günlüğe düşmüyor', () async {
      final fake = _build([
        (_) => _json('''
        {"results":[{"entityId":"x","status":"applied","version":1,
          "seq":null,"server":null,"reason":null}],"cursor":11}'''),
      ]);

      final tek = (await fake.api.push(
        deviceId: 'c',
        idempotencyKey: 'a',
        changes: const [],
      )).valueOrNull!.results.single;

      expect(tek.status, SyncPushStatus.applied);
      expect(tek.seq, isNull);
      expect(tek.version, 1);
    });
  });

  group('pull', () {
    test('upsert ve delete satırları çözülür', () async {
      // Gerçek yanıt (sync-dene.sh, adım 12).
      final fake = _build([
        (_) => _json('''
        {"changes":[
          {"seq":4,"entityType":"memory_people",
           "entityId":"d4503d1d:b0d53dbb","op":"delete","version":2,
           "deviceId":"01a08584-38ef-72b0-a34c-f60972bc8753","payload":null},
          {"seq":5,"entityType":"memory","entityId":"d4503d1d","op":"upsert",
           "version":3,"deviceId":"01a08584-38ef-72b0-a34c-f60972bc8753",
           "payload":{"id":"d4503d1d","title":"Kuyruk kilitlenmedi",
             "occurred_year":2026,"deleted_at":null,"version":3}}],
         "nextCursor":5,"hasMore":false}'''),
      ]);

      final sayfa = (await fake.api.pull(cursor: 0)).valueOrNull!;

      expect(sayfa.nextCursor, 5);
      expect(sayfa.hasMore, isFalse);
      expect(sayfa.changes.length, 2);

      final silme = sayfa.changes.first;
      expect(silme.isDelete, isTrue);
      expect(silme.payload, isNull, reason: 'silmede gövde gönderilmiyor');

      // Bağın kimliği BİLEŞİK — kendi UUID'si yok.
      expect(silme.entityId, 'd4503d1d:b0d53dbb');

      final upsert = sayfa.changes.last;
      expect(upsert.isDelete, isFalse);
      expect(upsert.payload!['title'], 'Kuyruk kilitlenmedi');
      expect(upsert.version, 3);
    });

    test('gönderen cihaz okunuyor — echo önlemenin dayanağı', () async {
      final fake = _build([
        (_) => _json('''
        {"changes":[{"seq":1,"entityType":"memory","entityId":"x",
          "op":"upsert","version":1,"deviceId":"cihaz-A","payload":{}}],
         "nextCursor":1,"hasMore":false}'''),
      ]);

      expect(
        (await fake.api.pull(cursor: 0)).valueOrNull!.changes.single.deviceId,
        'cihaz-A',
      );
    });

    test('arka plan değişikliğinde cihaz null olabilir', () async {
      final fake = _build([
        (_) => _json('''
        {"changes":[{"seq":1,"entityType":"memory","entityId":"x",
          "op":"upsert","version":1,"deviceId":null,"payload":{}}],
         "nextCursor":1,"hasMore":false}'''),
      ]);

      expect(
        (await fake.api.pull(cursor: 0)).valueOrNull!.changes.single.deviceId,
        isNull,
      );
    });

    test('cursor ve limit sorgu dizesine giriyor', () async {
      final fake = _build([
        (_) => _json('{"changes":[],"nextCursor":7,"hasMore":false}'),
      ]);

      await fake.api.pull(cursor: 7, limit: 50);

      final istek = fake.adapter.requests.single;
      expect(istek.queryParameters['cursor'], 7);
      expect(istek.queryParameters['limit'], 50);
    });

    test('boş sayfa hata değil', () async {
      final fake = _build([
        (_) => _json('{"changes":[],"nextCursor":25,"hasMore":false}'),
      ]);

      final sayfa = (await fake.api.pull(cursor: 25)).valueOrNull!;
      expect(sayfa.changes, isEmpty);
      expect(sayfa.nextCursor, 25);
    });
  });

  group('state', () {
    test('sayaçlar ve son değişiklik çözülür', () async {
      // Gerçek yanıt (sync-dene.sh, adım 17).
      final fake = _build([
        (_) => _json('''
        {"serverCursor":37,"pendingCount":37,
         "lastChangeAt":"2026-09-09T12:24:25.350764+00:00"}'''),
      ]);

      final durum = (await fake.api.state(cursor: 0)).valueOrNull!;

      expect(durum.serverCursor, 37);
      expect(durum.pendingCount, 37);
      expect(durum.lastChangeAt!.toUtc().year, 2026);
    });

    test('hiç değişiklik yoksa lastChangeAt null', () async {
      final fake = _build([
        (_) => _json('{"serverCursor":0,"pendingCount":0,"lastChangeAt":null}'),
      ]);

      final durum = (await fake.api.state(cursor: 0)).valueOrNull!;

      expect(durum.serverCursor, 0);
      expect(durum.lastChangeAt, isNull);
    });
  });

  group('cihaz kaydı', () {
    test('kimlik verilmezse gövdeye konmuyor — sunucu üretsin', () async {
      final fake = _build([
        (_) => _json(
          '{"id":"yeni-cihaz","platform":"android",'
          '"appVersion":null,"schemaVersion":8,'
          '"lastSeenAt":"2026-09-09T12:00:00+00:00"}',
        ),
      ]);

      final cihaz = (await fake.api.registerDevice(
        platform: 'android',
        schemaVersion: 8,
      )).valueOrNull!;

      expect(cihaz.id, 'yeni-cihaz');

      final govde = fake.adapter.requests.single.data as Map<String, Object?>;
      expect(govde.containsKey('id'), isFalse);
      expect(govde['platform'], 'android');
    });
  });

  group('hata yolu', () {
    test('sözleşme dışı gövde AĞ HATASI gibi görünmüyor', () async {
      // Sunucu 200 döndü ama gövde beklediğimiz biçimde değil. Bunu
      // "tekrar dene" diye göstermek sorunu çözmez; bir sözleşme ihlalidir.
      final fake = _build([(_) => _json('{"beklenmeyen":"bicim"}')]);

      final sonuc = await fake.api.state(cursor: 0);

      expect(sonuc.isErr, isTrue);
      expect(sonuc.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
