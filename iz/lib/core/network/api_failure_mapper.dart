/// Sunucu hatalarını ve ağ arızalarını uygulamanın hata sözlüğüne çevirir.
///
/// BU DOSYA SÖZLEŞMENİN İSTEMCİ UCU. Karşı ucu
/// `api/src/Iz.Api/ErrorHandling/AppExceptionHandler.cs` ve
/// `Program.cs`'teki ProblemDetails ayarı. İkisi ayrışırsa kullanıcı yanlış
/// mesaj görür; bu yüzden eşleme tablosu tek yerde ve testli.
///
/// KURAL: sunucunun yazdığı METİN kullanıcıya gösterilmez (TR-C-10).
/// Yalnız [ProblemDetails.errorCode] okunur; gösterilecek cümleyi
/// `failure_l10n.dart` seçer.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/network/problem_details.dart';

/// Sunucunun ürettiği doğrulama kodları → istemcinin [ValidationCode]'ları.
///
/// Burada YOKSA kod bilinçli olarak `ValidationFailure`a çevrilmez: uydurma
/// bir kod seçmek, kullanıcıya alakasız bir form hatası göstermek olurdu.
const Map<String, ValidationCode> _validationCodes = {
  // UpdateProfileHandler
  'display_name_too_long': ValidationCode.displayNameTooLong,
  'locale_invalid': ValidationCode.localeInvalid,
};

/// Kullanıcının DÜZELTEMEYECEĞİ, istemci hatasından doğan kodlar.
///
/// Bunlar kullanıcıya form hatası olarak gösterilmez; uygulamanın yanlış
/// veri gönderdiği anlamına gelir ve bir yazılım hatasıdır.
const Set<String> _clientBugCodes = {
  // RegisterDeviceHandler — bu değerleri kullanıcı girmiyor, uygulama üretiyor.
  'app_version_invalid',
  'schema_version_invalid',
};

/// Ağ katmanının tek hata çevirisi.
Failure mapDioException(DioException error) {
  final response = error.response;

  // 1) Yanıt hiç gelmediyse: bağlantı sorunu.
  if (response == null) {
    return _connectionFailure(error);
  }

  final status = response.statusCode ?? 0;
  final problem = ProblemDetails.tryParse(response.data, status: status);

  return mapProblemDetails(
    problem,
    status: status,
    cause: error,
    stackTrace: error.stackTrace,
  );
}

/// Gövdesi ayrıştırılmış bir hatayı çevirir.
///
/// [problem] `null` olabilir: araya giren bir vekil sunucu kendi HTML hata
/// sayfasını döndürebilir ve o sayfa bizim sözleşmemizi bilmez. O durumda
/// yalnız HTTP durum koduna bakarız.
Failure mapProblemDetails(
  ProblemDetails? problem, {
  required int status,
  Object? cause,
  StackTrace? stackTrace,
}) {
  final code = problem?.errorCode;

  // Sunucunun gönderdiği doğrulama kodu tanıdıksa, hatayı ilgili form
  // alanının altında gösterebiliriz.
  if (code != null) {
    final validation = _validationCodes[code];
    if (validation != null) {
      return ValidationFailure(code: validation);
    }

    if (_clientBugCodes.contains(code)) {
      return UnexpectedFailure(
        message: 'İstemci geçersiz veri gönderdi: $code',
        cause: cause,
        stackTrace: stackTrace,
      );
    }
  }

  return switch (status) {
    // Token yok, süresi dolmuş veya imzası geçersiz. Kullanıcının şifresi
    // yanlış DEĞİL — oturumu düşmüş. Ekran onu giriş sayfasına götürür.
    401 => AuthFailure(
      reason: AuthFailureReason.sessionExpired,
      cause: cause,
      stackTrace: stackTrace,
    ),

    // 403 için bugün MEŞRU BİR YOL YOK: sunucuda yetki reddi üreten bir
    // kural henüz yazılmadı. Buraya düşmek bir yazılım hatasıdır.
    // Faz 4'te `entitlement_required` gelecek ve EntitlementFailure'a
    // (yani paywall'a) çevrilecek — o gün bu kol değişir.
    403 => UnexpectedFailure(
      message: 'Sunucu erişimi reddetti (403, errorCode: $code)',
      cause: cause,
      stackTrace: stackTrace,
    ),

    404 => NotFoundFailure(
      entity: 'server',
      id: code ?? 'not_found',
      cause: cause,
      stackTrace: stackTrace,
    ),

    // Eşzamanlı iki isteğin çakışması. Tekrar denemek genellikle çözer,
    // bu yüzden "yeniden dene" gösterilebilen bir tipe çeviriyoruz.
    409 => UnexpectedFailure(
      message: 'Çakışma (409, errorCode: $code)',
      cause: cause,
      stackTrace: stackTrace,
    ),

    // Hız sınırı. Ağ hatası gibi ele alınır: geçici ve tekrar denenebilir.
    429 => NetworkFailure(
      statusCode: 429,
      cause: cause,
      stackTrace: stackTrace,
    ),

    _ =>
      status >= 500
          ? NetworkFailure(
              statusCode: status,
              cause: cause,
              stackTrace: stackTrace,
            )
          : UnexpectedFailure(
              message: 'Beklenmeyen sunucu yanıtı ($status, errorCode: $code)',
              cause: cause,
              stackTrace: stackTrace,
            ),
  };
}

/// Yanıt hiç gelmeyen durumlar.
Failure _connectionFailure(DioException error) => switch (error.type) {
  // Ağ mı yok, sunucu mu yok? İKİSİ AYNI ŞEY DEĞİL ve karıştırmanın bedeli
  // somut: uygulama uzun süre bağlantı hatalarının hepsine "internetin yok"
  // dedi. Bir kez, geliştirme API'sinin portu değiştiği için ekranda
  // "internet bağlantın yok" yazdı — oysa aynı anda Firebase girişi
  // internetten geçip başarıyla tamamlanmıştı. Sorun aranan yerde değildi.
  //
  // Artık kararı [_agSebebi] işletim sisteminin verdiği hataya bakarak
  // veriyor; tahmin etmiyoruz.
  DioExceptionType.connectionError ||
  DioExceptionType.connectionTimeout ||
  DioExceptionType.sendTimeout ||
  DioExceptionType.receiveTimeout => _agSebebi(error),

  // TLS doğrulaması başarısız. Ağ hatası gibi göstermek yanlış olurdu:
  // araya giren biri olabilir. Kullanıcıya genel hata, log'a gerçek sebep.
  DioExceptionType.badCertificate => UnexpectedFailure(
    message: 'Sunucu sertifikası doğrulanamadı',
    cause: error,
    stackTrace: error.stackTrace,
  ),

  // İsteği biz iptal ettik (ekran kapandı vb.). Kullanıcıya bir şey
  // gösterilmeyecek ama çağıran tarafın bir sonuç alması gerekiyor.
  DioExceptionType.cancel => NetworkFailure(
    message: 'İstek iptal edildi',
    cause: error,
    stackTrace: error.stackTrace,
  ),

  // `transformTimeout` ağ değil İSTEMCİ tarafı: yanıtın dönüştürülmesi çok
  // uzun sürdü. "Bağlantın yok" demek yanıltıcı olurdu — kullanıcı ağını
  // kontrol eder, oysa sorun bizde.
  DioExceptionType.transformTimeout ||
  DioExceptionType.badResponse ||
  DioExceptionType.unknown => UnexpectedFailure(
    cause: error,
    stackTrace: error.stackTrace,
  ),
};

/// Bağlantı kurulamadığında SEBEBİ işletim sisteminin hatasından okur.
///
/// VARSAYILAN "sunucuya ulaşılamıyor", "cihaz çevrimdışı" DEĞİL. Sebep:
/// yanlış tarafa yönlendirmenin maliyeti simetrik değil. Sunucu gerçekten
/// çökmüşken "internetini kontrol et" demek kullanıcıyı hiç bitmeyen bir
/// arayışa sokuyor; ağı gerçekten yokken "sunucuya ulaşılamıyor" demek ise
/// yalnızca eksik bilgi — kullanıcı zaten birazdan tekrar deniyor.
///
/// Çevrimdışı olduğunu ancak İŞLETİM SİSTEMİ söylerse iddia ediyoruz.
Failure _agSebebi(DioException error) {
  final socket = error.error;
  final cevrimdisi = socket is SocketException && _cevrimdisiHatasi(socket);

  return NetworkFailure(
    isOffline: cevrimdisi,
    isServerUnreachable: !cevrimdisi,
    cause: error,
    stackTrace: error.stackTrace,
  );
}

/// İşletim sistemi "ağa hiç çıkamadım" mı diyor?
///
/// İki imza var:
///   • DNS çözülemedi — cihazın ağı yoksa ilk takılan yer burasıdır.
///   • Ağ / ana makine erişilemez (ENETUNREACH, EHOSTUNREACH).
///
/// Bağlantının REDDEDİLMESİ (ECONNREFUSED) bilerek dışarıda: paket karşı
/// tarafa ULAŞTI ve reddedildi, yani ağ çalışıyor — dinleyen bir sunucu yok.
bool _cevrimdisiHatasi(SocketException hata) {
  // Mesaj metnine bakan tek yer. `osError` bu durumda genelde null olduğu
  // için başka imza kalmıyor; metin Dart'ın kendi sabiti, işletim sisteminin
  // yerelleştirilmiş metni değil.
  if (hata.message.contains('Failed host lookup')) return true;

  final kod = hata.osError?.errorCode;
  return kod != null && _erisilemezKodlari.contains(kod);
}

/// ENETUNREACH ve EHOSTUNREACH — platformlara göre.
///
/// Numaraları platform başlıklarından geliyor ve değişmiyorlar; `errno`
/// değerleri ABI'nin parçası. Windows'unkiler WSA* karşılıkları.
const Set<int> _erisilemezKodlari = {
  101, 113, // Linux / Android: ENETUNREACH, EHOSTUNREACH
  51, 65, // macOS / iOS: ENETUNREACH, EHOSTUNREACH
  10051, 10065, // Windows: WSAENETUNREACH, WSAEHOSTUNREACH
};
