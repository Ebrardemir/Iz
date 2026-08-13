/// Merkezî loglama.
///
/// NFR-013: "Analitik olaylarda fotoğraf, günlük metni, kişi adı veya özel not
/// içeriği gönderilmemelidir."
/// NFR-014: "Crash loglarında kişisel içerik ve access token redakte edilmelidir."
///
/// Bu yüzden `print` KULLANMIYORUZ. Her log buradan geçer ve [redact] filtresine
/// uğrar. Prod'da seviye otomatik yükselir.
library;

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:iz/core/config/app_config.dart';
import 'package:logging/logging.dart';

/// Bir kez çağrılır (bootstrap içinde).
void initLogging({AppConfig config = AppConfig.current}) {
  Logger.root.level = config.enableVerboseLogging ? Level.ALL : Level.WARNING;

  Logger.root.onRecord.listen((record) {
    final message = redact(record.message);

    // dart:developer.log → DevTools'ta yapılandırılmış görünür.
    developer.log(
      message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );

    // Prod'da buraya Crashlytics/Sentry bağlanacak (V1.5).
    // Gönderilen payload'ın da redact()'ten geçtiğinden emin ol.
  });
}

/// Hassas içeriği maskeler. Yeni bir gizli alan eklediğinde deseni buraya ekle.
///
/// Kasıtlı olarak agresif: yanlış maskeleme zararsız, sızıntı değil.
String redact(String input) {
  var out = input;
  for (final pattern in _redactionPatterns) {
    out = out.replaceAllMapped(pattern, (m) => '${m.group(1)}***');
  }
  return out;
}

final List<RegExp> _redactionPatterns = [
  // token=..., "accessToken": "..."
  RegExp(
    r'((?:access_?token|refresh_?token|bearer|authorization)["\s:=]+)\S+',
    caseSensitive: false,
  ),
  // e-posta
  RegExp(r'(\w{1,3})[\w.+-]*@[\w.-]+', caseSensitive: false),
  // note/title/text alanlarının içeriği — özel anı metni loga düşmesin
  RegExp(
    r'((?:note|title|text|caption|transcript)["\s:=]+)\S+',
    caseSensitive: false,
  ),
];

/// Feature bazlı logger üretir: `final _log = appLogger('memories');`
Logger appLogger(String name) => Logger('iz.$name');

/// Yakalanmamış hataları tek noktaya toplar. `bootstrap` içinde kurulur.
void installGlobalErrorHandlers() {
  final log = appLogger('uncaught');

  FlutterError.onError = (details) {
    log.severe(
      redact(details.summary.toString()),
      details.exception,
      details.stack,
    );
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  // Flutter framework dışındaki (isolate/platform) hatalar.
  PlatformDispatcher.instance.onError = (error, stack) {
    log.severe('Platform error', error, stack);
    return true; // hata ele alındı; uygulama çökmesin
  };
}
