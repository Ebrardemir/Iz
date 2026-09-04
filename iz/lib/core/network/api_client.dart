/// Sunucuyla konuşan tek yer.
///
/// TASARIM KURALLARI
///
/// 1. **Exception fırlatmaz, [Result] döner** (TR-C-02). Ağ hatası beklenen
///    bir durumdur; `try/catch` zorunluluğunu çağıran tarafa yıkmıyoruz.
///
/// 2. **Gövde LOG'A YAZILMAZ.** İstek ve yanıt gövdeleri anı notu, günlük
///    metni, kişi adı taşıyabilir (NFR-013/014). Yalnız metot, yol, durum
///    kodu ve süre loglanır — hata ayıklamaya yeten en az bilgi.
///
/// 3. **Yeniden deneme yalnız GÜVENLİ isteklerde.** Ayrıntı
///    [_RetryInterceptor] içinde.
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz, bu yüzden private
// alanlara `this._dio` biçiminde initializing formal kullanamıyoruz
// (aynı gerekçe sign_in_with_email.dart ve memory_repository_impl.dart'ta da
// geçerli).
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:iz/core/config/app_config.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/network/api_failure_mapper.dart';
import 'package:iz/core/network/auth_token_provider.dart';
import 'package:iz/core/result/result.dart';

/// İsteğin yeniden denenebilir olduğunu işaretleyen anahtar.
///
/// Faz 3'te `/v1/sync/push` bunu `Idempotency-Key` ile birlikte kullanacak:
/// sunucu aynı anahtarlı ikinci isteği işlemediği için POST bile güvenle
/// tekrarlanabilir hale geliyor.
const String kRetryableExtraKey = 'izRetryable';

final class IzApiClient {
  IzApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Test ve teşhis için; üretim kodunda kullanılmaz.
  Dio get raw => _dio;

  Future<Result<T>> get<T>(
    String path, {
    Map<String, Object?>? query,
    required T Function(Object? json) parse,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.get<Object?>(
      path,
      queryParameters: query,
      cancelToken: cancelToken,
    ),
    parse,
  );

  Future<Result<T>> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) parse,
    bool retryable = false,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.post<Object?>(
      path,
      data: body,
      cancelToken: cancelToken,
      options: Options(extra: {kRetryableExtraKey: retryable}),
    ),
    parse,
  );

  Future<Result<T>> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? json) parse,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.patch<Object?>(path, data: body, cancelToken: cancelToken),
    parse,
  );

  Future<Result<T>> _send<T>(
    Future<Response<Object?>> Function() call,
    T Function(Object? json) parse,
  ) async {
    try {
      final response = await call();
      return Ok(parse(response.data));
    } on DioException catch (error) {
      return Err(mapDioException(error));
    } on Object catch (error, stackTrace) {
      // Ayrıştırma hatası buraya düşer: sunucu 200 döndü ama gövde
      // beklediğimiz biçimde değil. Bu bir SÖZLEŞME İHLALİDİR ve ağ hatası
      // gibi gösterilmemeli — "tekrar dene" demek sorunu çözmez.
      return Err(
        UnexpectedFailure(
          message: 'Sunucu yanıtı çözümlenemedi',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}

/// Her isteğe kimlik ekler ve süresi dolmuş token'ı bir kez tazeler.
final class IzAuthInterceptor extends Interceptor {
  IzAuthInterceptor({required Dio dio, required AuthTokenProvider tokens})
    : _dio = dio,
      _tokens = tokens;

  /// Yeniden denemede AYNI Dio kullanılır.
  ///
  /// Burada `Dio()` ile yenisini yaratmak cazip görünüyor ama iki şeyi
  /// bozardı: (a) interceptor zinciri atlanır, yani log ve yeniden deneme
  /// devre dışı kalır; (b) test sahte HTTP katmanını değiştirdiğinde bu
  /// çağrı onu görmez ve GERÇEK ağa çıkar.
  final Dio _dio;
  final AuthTokenProvider _tokens;

  /// Aynı isteğin sonsuz döngüye girmesini engelleyen işaret.
  static const String _retriedKey = 'izAuthRetried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.currentIdToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    // Token yoksa başlık EKLENMEZ. Boş bir "Bearer " göndermek, sunucuda
    // "bozuk token" olarak görünür ve gerçek sorunu gizlerdi.
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final alreadyRetried = request.extra[_retriedKey] == true;

    // 401 + daha önce denenmedi + elimizde bir oturum var → token'ın süresi
    // dolmuş olabilir. Firebase SDK'sı normalde kendi yeniliyor ama uygulama
    // uzun süre arka planda kaldıysa elimizdeki kopya bayat olabilir.
    if (err.response?.statusCode != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }

    // Tazelemenin yan etkisi önemli: SDK yeni token'ı kendi önbelleğine
    // yazıyor. Dolayısıyla aşağıdaki yeniden istekte `onRequest` normal
    // yoldan sorduğunda artık TAZE token'ı alacak; başlığı burada elle
    // yazmamıza gerek yok.
    final fresh = await _tokens.currentIdToken(forceRefresh: true);
    if (fresh == null) {
      // Gerçekten oturum yok. 401 doğru yanıt; kullanıcı giriş yapmalı.
      handler.next(err);
      return;
    }

    request.extra[_retriedKey] = true;

    try {
      handler.resolve(await _dio.fetch<Object?>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}

/// Geçici arızalarda üstel geri çekilme + jitter ile yeniden dener.
///
/// NEDEN JITTER? Sunucu bir dakika düşüp kalktığında, geri çekilme süresi
/// sabit olsaydı tüm istemciler AYNI anda geri dönerdi ve sunucuyu yeniden
/// düşürürlerdi. Rastgele sapma bu dalgayı dağıtır.
///
/// NEYİ DENEMEZ: GET dışındaki metotlar, açıkça `retryable` işaretlenmedikçe
/// tekrarlanmaz. Bir POST'u tekrarlamak ikinci bir kayıt oluşturabilir —
/// "ağ koptu sandık ama sunucu isteği almıştı" durumu. Bu tehlike Faz 3'te
/// `Idempotency-Key` ile ortadan kalkacak (BACKEND_YOL_HARITASI §4.1).
final class IzRetryInterceptor extends Interceptor {
  IzRetryInterceptor({
    required Dio dio,
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 300),
    Random? random,
  }) : _dio = dio,
       _random = random ?? Random();

  final Dio _dio;
  final int maxAttempts;
  final Duration baseDelay;
  final Random _random;

  static const String _attemptKey = 'izAttempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final attempt = (request.extra[_attemptKey] as int?) ?? 0;

    if (!_shouldRetry(err) || attempt + 1 >= maxAttempts) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(_delayFor(attempt));

    request.extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<Object?>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _shouldRetry(DioException err) {
    final request = err.requestOptions;
    final isSafeMethod = request.method.toUpperCase() == 'GET';
    final markedRetryable = request.extra[kRetryableExtraKey] == true;
    if (!isSafeMethod && !markedRetryable) {
      return false;
    }

    final status = err.response?.statusCode;
    if (status != null) {
      // 5xx sunucunun geçici sorunu, 429 hız sınırı. 4xx'in geri kalanını
      // tekrarlamak anlamsız: aynı istek aynı yanıtı alır.
      return status >= 500 || status == 429;
    }

    return switch (err.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => true,
      _ => false,
    };
  }

  /// Üstel geri çekilme: 300ms, 900ms, 2.7s… üzerine %0–50 rastgele sapma.
  Duration _delayFor(int attempt) {
    final backoff = baseDelay.inMilliseconds * pow(3, attempt).toInt();
    final jitter = _random.nextInt((backoff ~/ 2) + 1);
    return Duration(milliseconds: backoff + jitter);
  }
}

/// İsteğin ne kadar sürdüğünü ve nasıl sonuçlandığını yazar — GÖVDESİZ.
final class IzLogInterceptor extends Interceptor {
  IzLogInterceptor();

  static const String _startedAtKey = 'izStartedAt';
  final _log = appLogger('network');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    _log.info(_line(response.requestOptions, response.statusCode));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log.warning(_line(err.requestOptions, err.response?.statusCode));
    handler.next(err);
  }

  /// Sorgu dizesi de yazılmaz: arama sorgusu hassas veridir (TR-C-50) ve
  /// kimlik bilgisi taşıyan bir parametre bir gün oraya eklenebilir.
  String _line(RequestOptions options, int? status) {
    final startedAt = options.extra[_startedAtKey];
    final elapsed = startedAt is DateTime
        ? DateTime.now().difference(startedAt).inMilliseconds
        : null;

    return '${options.method} ${options.path} '
        '-> ${status ?? 'yanıt yok'}'
        '${elapsed == null ? '' : ' (${elapsed}ms)'}';
  }
}

/// Uygulamanın kullandığı Dio örneğini kurar.
Dio buildIzDio({
  required AuthTokenProvider tokens,
  AppConfig config = AppConfig.current,
  Random? random,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      // İki ayrı zaman aşımı, çünkü iki ayrı arıza:
      // bağlanamamak (sunucu/ağ yok) ile yanıtın gecikmesi (sunucu yavaş).
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      contentType: 'application/json',
      // Hata durumlarını İSTİSNA olarak almak istiyoruz; eşleme tek yerde
      // (mapDioException) yapılsın diye.
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );

  // SIRA ÖNEMLİ. Hata yolunda interceptor'lar TERS sırada çalışır, yani
  // önce yeniden deneme, sonra kimlik tazeleme denenir. Böylece geçici bir
  // 500 yüzünden gereksiz yere token tazelenmez.
  dio.interceptors.addAll([
    IzAuthInterceptor(dio: dio, tokens: tokens),
    IzRetryInterceptor(dio: dio, random: random),
    if (config.enableVerboseLogging) IzLogInterceptor(),
  ]);

  return dio;
}
