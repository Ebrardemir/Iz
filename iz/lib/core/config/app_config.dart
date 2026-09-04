/// Derleme zamanı yapılandırması (flavor / ortam).
///
/// KULLANIM:
///   flutter run --dart-define=IZ_ENV=dev
///   flutter build apk --dart-define=IZ_ENV=prod --dart-define=IZ_API=https://...
///
/// NEDEN `String.fromEnvironment`?
/// Değerler derleme anında gömülür; .env dosyası okumak gibi runtime maliyeti
/// ve "dosyayı unutma" riski yoktur. Ayrıca const olduğu için tree-shaking
/// çalışır: prod build'de dev'e özel kod tamamen atılır.
library;

// NOT: Burada bir `AppEnvironment.fromName(String)` fabrikası vardı. Hiçbir
// yerden çağrılmıyordu, çünkü çözümlemeyi aşağıdaki `_resolvedEnv` sabiti
// yapıyor — ve YAPMAK ZORUNDA: `AppConfig.current` bir `const` ve const bir
// ifadenin içinde metot çağrılamaz. İki ayrı çözümleme mantığı tutmak,
// birinin gün gelip ötekinden ayrışması demekti.
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

enum AppEnvironment { dev, staging, prod }

final class AppConfig {
  const AppConfig({
    required this.environment,
    required String apiBaseUrl,
    required this.enableVerboseLogging,
  }) : _declaredApiBaseUrl = apiBaseUrl;

  /// Uygulamanın her yerinden erişilen aktif yapılandırma.
  ///
  /// PROVIDER YOK — bilinçli. Değerler `--dart-define` ile DERLEME ANINDA
  /// gömülüyor; çalışma zamanında değişmedikleri için Riverpod'a sarmanın
  /// getirisi olmazdı. Farklı bir config'le test yazman gerekiyorsa
  /// [AppConfig]'i parametre olarak geçir — `initLogging` böyle yapıyor
  /// (bkz. core/logging/app_logger.dart).
  static const AppConfig current = AppConfig(
    environment: _resolvedEnv,
    // BOŞ = "söylenmedi". Buraya bir varsayılan YAZMIYORUZ; çözümü
    // aşağıdaki [apiBaseUrl] getter'ı yapıyor. Sebep: doğru yerel adres
    // platforma göre değişiyor (emülatörde 10.0.2.2, simülatör/masaüstünde
    // localhost) ve bu, derleme anında bilinemez.
    apiBaseUrl: String.fromEnvironment('IZ_API'),
    // Prod'da log kapalı: NFR-014 (crash loglarında kişisel içerik olmamalı).
    enableVerboseLogging: !_isProd,
  );

  static const String _rawEnv = String.fromEnvironment(
    'IZ_ENV',
    defaultValue: 'dev',
  );

  static const AppEnvironment _resolvedEnv = _rawEnv == 'prod'
      ? AppEnvironment.prod
      : (_rawEnv == 'staging' ? AppEnvironment.staging : AppEnvironment.dev);

  static const bool _isProd = _rawEnv == 'prod';

  final AppEnvironment environment;
  final bool enableVerboseLogging;

  /// `--dart-define=IZ_API` ile NE YAZILDIĞI. Boş olabilir.
  final String _declaredApiBaseUrl;

  /// Ağ isteklerinin gideceği kök adres.
  ///
  /// NEDEN GETTER?
  /// `--dart-define=IZ_API` verilmediğinde eskiden `https://api.iz.app`'e
  /// düşülüyordu — HENÜZ VAR OLMAYAN bir alan adı. Düz `flutter run`
  /// diyen geliştirici oraya gidiyor, DNS çözemiyor ve ekranda "cihaz
  /// çevrimdışı" yazıyordu. Firebase girişi başarılı olduğu için hata
  /// yanıltıcıydı: kimlik doğrulama bozukmuş gibi görünüyordu, oysa kopan
  /// yer sonraki `GET /v1/me` idi.
  ///
  /// Artık bayrak unutulursa geliştirme ortamı YEREL API'ye düşüyor.
  /// Üretimde davranış değişmedi.
  String get apiBaseUrl {
    if (_declaredApiBaseUrl.isNotEmpty) return _declaredApiBaseUrl;
    return isProd ? _prodApiBaseUrl : _localApiBaseUrl;
  }

  static const String _prodApiBaseUrl = 'https://api.iz.app';

  /// Geliştirme makinesindeki API'nin, cihazın gözünden adresi.
  ///
  /// 10.0.2.2 Android emülatöründe ana makinenin loopback'ine karşılık
  /// gelir; "localhost" yazmak emülatörün KENDİSİNİ kastetmek olurdu.
  /// iOS simülatörü ve masaüstü ana makineyle aynı ağ isim alanındadır.
  ///
  /// GERÇEK TELEFONDA çalışıyorsan bu adres anlamsızdır — o durumda
  /// makinenin LAN adresini açıkça geç:
  ///   flutter run --dart-define=IZ_API=http://192.168.1.x:5163
  static String get _localApiBaseUrl =>
      defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:5163'
      : 'http://localhost:5163';

  bool get isProd => environment == AppEnvironment.prod;
  bool get isDev => environment == AppEnvironment.dev;

  /// V1.5'e kadar backend zorunlu değil (rapor 13.1 — local-first MVP).
  bool get requiresBackend => false;
}
