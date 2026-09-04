/// Sunucu hatalarının uygulama hata sözlüğüne çevrilmesi.
///
/// NEDEN BU KADAR ÇOK KOL TEK TEK SINANIYOR?
/// Bu eşleme, sunucu sözleşmesinin istemci ucudur ve iki ucun ayrışması
/// derleme hatası vermez — sessizce yanlış mesaj gösterir. Örneğin 401'i
/// "şifren yanlış" diye çevirirsek, oturumu düşmüş kullanıcı şifresini
/// değiştirmeye çalışır ve sorunu çözemez.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/core/network/api_failure_mapper.dart';
import 'package:iz/core/network/problem_details.dart';

/// Sunucunun gerçekte döndürdüğü biçimde bir hata yanıtı üretir.
DioException _serverError(
  int status, {
  String? errorCode,
  String? field,
  bool problemDetailsBody = true,
}) {
  final options = RequestOptions(path: '/v1/me');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: problemDetailsBody
          ? {
              'type': 'https://tools.ietf.org/html/rfc9110',
              'title': 'İstek işlenemedi.',
              'status': status,
              'errorCode': ?errorCode,
              'field': ?field,
              'traceId': '00-abc-def-00',
            }
          // Araya giren vekil sunucunun HTML hata sayfası.
          : '<html><body>502 Bad Gateway</body></html>',
    ),
  );
}

DioException _transport(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/v1/me'),
  type: type,
);

void main() {
  group('sunucu hataları', () {
    test('401 oturumun düştüğünü söyler, şifre hatası demez', () {
      final failure = mapDioException(
        _serverError(401, errorCode: 'unauthorized'),
      );

      expect(failure, isA<AuthFailure>());
      expect(
        (failure as AuthFailure).reason,
        AuthFailureReason.sessionExpired,
        reason:
            'invalidCredentials olsaydı kullanıcı şifresini değiştirmeye '
            'çalışırdı; oysa yapması gereken yeniden giriş.',
      );
    });

    test('403 bugün için YAZILIM HATASI sayılır', () {
      // Sunucuda yetki reddi üreten meşru bir kural henüz yok. Faz 4'te
      // entitlement_required gelince bu kol paywall'a çevrilecek.
      expect(mapDioException(_serverError(403)), isA<UnexpectedFailure>());
    });

    test('404 kayıt bulunamadıya çevrilir', () {
      final failure = mapDioException(
        _serverError(404, errorCode: 'user_not_found'),
      );

      expect(failure, isA<NotFoundFailure>());
      expect((failure as NotFoundFailure).id, 'user_not_found');
    });

    test('429 ağ hatası gibi ele alınır — geçici ve tekrar denenebilir', () {
      final failure = mapDioException(
        _serverError(429, errorCode: 'rate_limited'),
      );

      expect(failure, isA<NetworkFailure>());
      expect((failure as NetworkFailure).statusCode, 429);
      expect(failure.isRetryable, isTrue);
    });

    test('500 ağ hatasıdır, çevrimdışı DEĞİLDİR', () {
      final failure = mapDioException(_serverError(500));

      expect(failure, isA<NetworkFailure>());
      // isOffline true olsaydı kullanıcıya "bağlantın yok" derdik; oysa
      // bağlantı var, sunucu bozuk. Kullanıcı boşuna wifi'sini kurcalar.
      expect((failure as NetworkFailure).isOffline, isFalse);
    });

    test('409 tekrar denenebilir bir hataya çevrilir', () {
      final failure = mapDioException(_serverError(409, errorCode: 'conflict'));

      expect(failure.isRetryable, isTrue);
    });
  });

  group('doğrulama kodları', () {
    test('tanınan kod FORM hatasına ve doğru alana çevrilir', () {
      final failure = mapDioException(
        _serverError(
          400,
          errorCode: 'display_name_too_long',
          field: 'displayName',
        ),
      );

      expect(failure, isA<ValidationFailure>());
      final validation = failure as ValidationFailure;
      expect(validation.code, ValidationCode.displayNameTooLong);
      expect(validation.code.field, ProfileFormField.displayName);
    });

    test('locale_invalid da eşlenir', () {
      final failure = mapDioException(
        _serverError(400, errorCode: 'locale_invalid'),
      );

      expect((failure as ValidationFailure).code, ValidationCode.localeInvalid);
    });

    test('istemci hatası olan kodlar FORM hatası olarak gösterilmez', () {
      // schema_version'ı kullanıcı girmiyor, uygulama üretiyor. Kullanıcıya
      // "şu alanı düzelt" demek anlamsız olurdu.
      final failure = mapDioException(
        _serverError(400, errorCode: 'schema_version_invalid'),
      );

      expect(failure, isA<UnexpectedFailure>());
      expect(failure.message, contains('schema_version_invalid'));
    });

    test('tanınmayan doğrulama kodu uydurulmaz', () {
      // Rastgele bir ValidationCode seçmek, kullanıcıya alakasız bir form
      // hatası göstermek olurdu.
      final failure = mapDioException(
        _serverError(400, errorCode: 'sunucuda_yeni_eklenmis_kod'),
      );

      expect(failure, isNot(isA<ValidationFailure>()));
      expect(failure, isA<UnexpectedFailure>());
    });
  });

  group('taşıma katmanı arızaları', () {
    test('bağlantı hatası ÇEVRİMDIŞI olarak işaretlenir', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final failure = mapDioException(_transport(type));

        expect(failure, isA<NetworkFailure>(), reason: '$type');
        expect((failure as NetworkFailure).isOffline, isTrue, reason: '$type');
      }
    });

    test('sertifika hatası ağ hatası gibi gösterilmez', () {
      // Araya giren biri olabilir; "bağlantın koptu" demek yanıltıcı olur.
      final failure = mapDioException(
        _transport(DioExceptionType.badCertificate),
      );

      expect(failure, isA<UnexpectedFailure>());
      expect(failure.message, contains('sertifika'));
    });
  });

  group('sözleşme dışı yanıtlar', () {
    test('ProblemDetails olmayan gövdede durum koduna düşülür', () {
      // Vekil sunucu kendi HTML sayfasını döndürdü; bizim sözleşmemizi bilmiyor.
      final failure = mapDioException(
        _serverError(502, problemDetailsBody: false),
      );

      expect(failure, isA<NetworkFailure>());
      expect((failure as NetworkFailure).statusCode, 502);
    });

    test('gövdedeki status HTTP durumundan önce gelir', () {
      // Vekil sunucu HTTP kodunu değiştirebilir; gövdeyi uygulama yazdı.
      final parsed = ProblemDetails.tryParse({
        'status': 404,
        'errorCode': 'not_found',
      }, status: 200);

      expect(parsed?.status, 404);
    });

    test('gövde Map değilse ayrıştırma null döner', () {
      expect(ProblemDetails.tryParse('düz metin', status: 500), isNull);
    });
  });
}
