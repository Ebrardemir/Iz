/// API adresinin nasıl çözüldüğünü kilitler.
///
/// NEDEN BU TEST VAR?
/// `--dart-define=IZ_API` verilmediğinde uygulama eskiden `https://api.iz.app`
/// adresine gidiyordu. O alan adı henüz yok; düz `flutter run` diyen
/// geliştiricinin ekranında "cihaz çevrimdışı" yazıyordu ve hata yanıltıcıydı
/// (Firebase girişi başarılı oluyor, sonraki `GET /v1/me` kopuyordu).
/// Buradaki beklentiler o davranışın geri gelmesini engelliyor.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/config/app_config.dart';

void main() {
  group('AppConfig.apiBaseUrl', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('açıkça verilen adres her şeyin önündedir', () {
      const config = AppConfig(
        environment: AppEnvironment.dev,
        apiBaseUrl: 'https://sunucu.test',
        enableVerboseLogging: true,
      );

      expect(config.apiBaseUrl, 'https://sunucu.test');
    });

    test(
      'dev + adres verilmemiş + Android → emülatörün gördüğü ana makine',
      () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        const config = AppConfig(
          environment: AppEnvironment.dev,
          apiBaseUrl: '',
          enableVerboseLogging: true,
        );

        // 10.0.2.2, emülatörden ana makinenin loopback'idir. "localhost"
        // olsaydı emülatörün KENDİSİNE gidilirdi.
        expect(config.apiBaseUrl, 'http://10.0.2.2:5163');
      },
    );

    test('dev + adres verilmemiş + iOS → localhost', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      const config = AppConfig(
        environment: AppEnvironment.dev,
        apiBaseUrl: '',
        enableVerboseLogging: true,
      );

      expect(config.apiBaseUrl, 'http://localhost:5163');
    });

    test('prod + adres verilmemiş → yerel adrese ASLA düşmez', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      const config = AppConfig(
        environment: AppEnvironment.prod,
        apiBaseUrl: '',
        enableVerboseLogging: false,
      );

      // Üretimde geliştirme makinesine gitmek sessiz bir felaket olurdu:
      // istekler hiçbir yere ulaşmaz, kullanıcı sebebini anlayamaz.
      expect(config.apiBaseUrl, 'https://api.iz.app');
      expect(config.apiBaseUrl, isNot(contains('10.0.2.2')));
      expect(config.apiBaseUrl, isNot(contains('localhost')));
    });
  });
}
