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
enum AppEnvironment { dev, staging, prod }

final class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableVerboseLogging,
  });

  /// Uygulamanın her yerinden erişilen aktif yapılandırma.
  ///
  /// PROVIDER YOK — bilinçli. Değerler `--dart-define` ile DERLEME ANINDA
  /// gömülüyor; çalışma zamanında değişmedikleri için Riverpod'a sarmanın
  /// getirisi olmazdı. Farklı bir config'le test yazman gerekiyorsa
  /// [AppConfig]'i parametre olarak geçir — `initLogging` böyle yapıyor
  /// (bkz. core/logging/app_logger.dart).
  static const AppConfig current = AppConfig(
    environment: _resolvedEnv,
    apiBaseUrl: String.fromEnvironment(
      'IZ_API',
      defaultValue: 'https://api.iz.app',
    ),
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
  final String apiBaseUrl;
  final bool enableVerboseLogging;

  bool get isProd => environment == AppEnvironment.prod;
  bool get isDev => environment == AppEnvironment.dev;

  /// V1.5'e kadar backend zorunlu değil (rapor 13.1 — local-first MVP).
  bool get requiresBackend => false;
}
