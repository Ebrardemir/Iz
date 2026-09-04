/// Ağ istemcisinin davranışı: kimlik ekleme, yeniden deneme ve loglama.
///
/// Gerçek ağa ÇIKMIYORUZ — Dio'nun HTTP katmanını sahtesiyle değiştiriyoruz.
/// Böylece "sunucu 500 döndü", "bağlantı koptu", "token bayat" gibi
/// durumları isteyerek üretebiliyoruz; gerçek bir sunucuyla bunları
/// tetiklemek mümkün değil.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/config/app_config.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/network/api_client.dart';
import 'package:iz/core/network/auth_token_provider.dart';
import 'package:iz/core/result/result.dart';
import 'package:logging/logging.dart';

/// Sıraya konmuş yanıtları döndüren sahte HTTP katmanı.
final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  /// Her çağrıda sıradaki üretici çalışır; son eleman tükenirse tekrarlanır.
  final List<ResponseBody Function(RequestOptions)> responses;

  /// Gelen isteklerin kaydı — kaç kez ve hangi başlıkla gidildiğini sınamak için.
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

ResponseBody _json(Map<String, Object?> body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

final class _StubTokens implements AuthTokenProvider {
  _StubTokens({this.token, this.refreshedToken});

  String? token;
  final String? refreshedToken;
  int refreshCount = 0;

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      refreshCount++;
      // Gerçek SDK gibi davran: tazelenen token önbelleğe yazılır, sonraki
      // normal okumalar da onu döndürür.
      token = refreshedToken;
      return refreshedToken;
    }
    return token;
  }
}

/// Testlerde bekleme yapmamak için gecikmeyi sıfırlayan istemci kurar.
({IzApiClient client, _FakeAdapter adapter}) buildClient({
  required List<ResponseBody Function(RequestOptions)> responses,
  AuthTokenProvider? tokens,
}) {
  final dio = buildIzDio(
    tokens: tokens ?? const UnauthenticatedTokenProvider(),
    config: const AppConfig(
      environment: AppEnvironment.dev,
      apiBaseUrl: 'https://sunucu.test',
      // Log interceptor'ı ayrı testte kuruyoruz; burada gürültü olmasın.
      enableVerboseLogging: false,
    ),
    random: Random(1),
  );

  // Geri çekilme süresini sıfırla: test 3 saniye beklemesin.
  dio.interceptors.removeWhere((i) => i is IzRetryInterceptor);
  dio.interceptors.add(
    IzRetryInterceptor(dio: dio, baseDelay: Duration.zero, random: Random(1)),
  );

  final adapter = _FakeAdapter(responses);
  dio.httpClientAdapter = adapter;

  return (client: IzApiClient(dio: dio), adapter: adapter);
}

void main() {
  group('kimlik başlığı', () {
    test('oturum varsa Bearer başlığı eklenir', () async {
      final fake = buildClient(
        responses: [
          (_) => _json({'ok': true}),
        ],
        tokens: _StubTokens(token: 'token-abc'),
      );

      await fake.client.get<Object?>('/v1/me', parse: (json) => json);

      expect(
        fake.adapter.requests.single.headers['Authorization'],
        'Bearer token-abc',
      );
    });

    test('oturum yoksa başlık HİÇ eklenmez', () async {
      // Boş bir "Bearer " göndermek sunucuda "bozuk token" olarak görünür
      // ve gerçek sebebi (oturum yok) gizler.
      final fake = buildClient(
        responses: [
          (_) => _json({'ok': true}),
        ],
      );

      await fake.client.get<Object?>('/v1/me', parse: (json) => json);

      expect(
        fake.adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('401 alınca token BİR KEZ tazelenir ve istek tekrarlanır', () async {
      // Uygulama uzun süre arka planda kaldıysa elimizdeki token bayat
      // olabilir. Kullanıcıyı giriş ekranına atmadan önce tazelemeyi deneriz.
      final tokens = _StubTokens(token: 'bayat', refreshedToken: 'taze');
      var call = 0;
      final fake = buildClient(
        tokens: tokens,
        responses: [
          (_) {
            call++;
            return call == 1
                ? _json({'errorCode': 'unauthorized'}, status: 401)
                : _json({'id': 'kullanici-1'});
          },
        ],
      );

      final result = await fake.client.get<Object?>(
        '/v1/me',
        parse: (json) => json,
      );

      expect(result, isA<Ok<Object?>>());
      expect(tokens.refreshCount, 1);
      expect(fake.adapter.requests.length, 2);
      expect(
        fake.adapter.requests.last.headers['Authorization'],
        'Bearer taze',
      );
    });

    test('tazelenen token da 401 alırsa DÖNGÜYE girmez', () async {
      final tokens = _StubTokens(token: 'bayat', refreshedToken: 'taze');
      final fake = buildClient(
        tokens: tokens,
        responses: [
          (_) => _json({'errorCode': 'unauthorized'}, status: 401),
        ],
      );

      final result = await fake.client.get<Object?>(
        '/v1/me',
        parse: (json) => json,
      );

      expect(result, isA<Err<Object?>>());
      expect((result as Err<Object?>).failure, isA<AuthFailure>());
      // İlk istek + tazelenmiş tek tekrar. Üçüncüsü olsaydı sonsuz döngünün
      // başlangıcı olurdu.
      expect(fake.adapter.requests.length, 2);
      expect(tokens.refreshCount, 1);
    });

    test('oturum gerçekten yoksa tazeleme denenmez', () async {
      final tokens = _StubTokens();
      final fake = buildClient(
        tokens: tokens,
        responses: [
          (_) => _json({'errorCode': 'unauthorized'}, status: 401),
        ],
      );

      await fake.client.get<Object?>('/v1/me', parse: (json) => json);

      expect(fake.adapter.requests.length, 1);
    });
  });

  group('yeniden deneme', () {
    test('GET 500 alınca tekrar denenir', () async {
      var call = 0;
      final fake = buildClient(
        responses: [
          (_) {
            call++;
            return call < 3
                ? _json({'errorCode': 'unexpected'}, status: 500)
                : _json({'ok': true});
          },
        ],
      );

      final result = await fake.client.get<Object?>(
        '/v1/me',
        parse: (json) => json,
      );

      expect(result, isA<Ok<Object?>>());
      expect(fake.adapter.requests.length, 3);
    });

    test('POST varsayılan olarak TEKRARLANMAZ', () async {
      // "Ağ koptu" sandığımız istek sunucuya ulaşmış olabilir. Tekrarlamak
      // ikinci bir kayıt oluşturur — cihaz kaydı iki kez açılır.
      final fake = buildClient(
        responses: [
          (_) => _json({'errorCode': 'unexpected'}, status: 500),
        ],
      );

      await fake.client.post<Object?>(
        '/v1/devices',
        body: {'platform': 'android'},
        parse: (json) => json,
      );

      expect(fake.adapter.requests.length, 1);
    });

    test('açıkça işaretlenen POST tekrarlanır', () async {
      // Faz 3'te /v1/sync/push Idempotency-Key taşıyacak; sunucu aynı
      // anahtarlı ikinci isteği işlemediği için tekrar güvenli olacak.
      var call = 0;
      final fake = buildClient(
        responses: [
          (_) {
            call++;
            return call == 1
                ? _json({'errorCode': 'unexpected'}, status: 500)
                : _json({'ok': true});
          },
        ],
      );

      final result = await fake.client.post<Object?>(
        '/v1/sync/push',
        body: const {},
        retryable: true,
        parse: (json) => json,
      );

      expect(result, isA<Ok<Object?>>());
      expect(fake.adapter.requests.length, 2);
    });

    test('400 tekrarlanmaz — aynı istek aynı yanıtı alır', () async {
      final fake = buildClient(
        responses: [
          (_) => _json({'errorCode': 'bad_request'}, status: 400),
        ],
      );

      await fake.client.get<Object?>('/v1/me', parse: (json) => json);

      expect(fake.adapter.requests.length, 1);
    });

    test('deneme sayısı sınırlıdır', () async {
      final fake = buildClient(
        responses: [
          (_) => _json({'errorCode': 'unexpected'}, status: 500),
        ],
      );

      final result = await fake.client.get<Object?>(
        '/v1/me',
        parse: (json) => json,
      );

      expect(result, isA<Err<Object?>>());
      expect(fake.adapter.requests.length, 3, reason: 'maxAttempts = 3');
    });
  });

  group('yanıt çözümleme', () {
    test('bozuk gövde AĞ hatası değil, sözleşme ihlalidir', () async {
      // "Tekrar dene" demek sorunu çözmez; sunucu 200 döndürüp beklenmedik
      // bir gövde gönderiyor.
      final fake = buildClient(
        responses: [
          (_) => _json({'beklenmedik': 1}),
        ],
      );

      final result = await fake.client.get<String>(
        '/v1/me',
        parse: (json) => (json! as Map)['id']! as String,
      );

      expect((result as Err<String>).failure, isA<UnexpectedFailure>());
      expect(result.failure.message, contains('çözümlenemedi'));
    });
  });

  group('loglama', () {
    test('log satırı GÖVDE taşımaz', () async {
      // NFR-013/014: anı notu, günlük metni, kişi adı loga girmez.
      final kayitlar = <String>[];
      final abonelik = Logger.root.onRecord.listen(
        (record) => kayitlar.add(record.message),
      );
      final oncekiSeviye = Logger.root.level;
      Logger.root.level = Level.ALL;

      final dio = buildIzDio(
        tokens: const UnauthenticatedTokenProvider(),
        config: const AppConfig(
          environment: AppEnvironment.dev,
          apiBaseUrl: 'https://sunucu.test',
          enableVerboseLogging: true,
        ),
      );
      dio.httpClientAdapter = _FakeAdapter([
        (_) => _json({'note': 'Ayşe ile Kapadokya'}),
      ]);

      await IzApiClient(dio: dio).post<Object?>(
        '/v1/memories',
        body: {'note': 'Ayşe ile Kapadokya'},
        parse: (json) => json,
      );

      await abonelik.cancel();
      Logger.root.level = oncekiSeviye;

      expect(kayitlar, isNotEmpty);
      final hepsi = kayitlar.join('\n');
      expect(hepsi, contains('POST /v1/memories'));
      expect(hepsi, contains('200'));
      expect(
        hepsi,
        isNot(contains('Kapadokya')),
        reason: 'İstek/yanıt gövdesi loga girmemeli.',
      );
    });
  });
}
