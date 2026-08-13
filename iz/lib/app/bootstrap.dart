/// Uygulama başlatma zinciri.
///
/// NEDEN `main.dart` İÇİNDE DEĞİL?
/// Başlatma mantığını ayırınca:
///   • entegrasyon testleri aynı zinciri çalıştırıp gerçek uygulamayı
///     test edebilir
///   • farklı giriş noktaları (main_dev.dart, main_prod.dart) aynı
///     bootstrap'ı paylaşır
///   • `main` fonksiyonu okunabilir kalır
///
/// SIRA ÖNEMLİ: async başlatmalar (SharedPreferences) `runApp`tan ÖNCE
/// tamamlanmalı, yoksa provider'lar hazır olmayan bağımlılığı okur.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/app/app.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/storage/app_preferences.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> bootstrap() async {
  // Platform kanallarını kullanmadan önce şart.
  WidgetsFlutterBinding.ensureInitialized();

  initLogging();
  installGlobalErrorHandlers();

  final log = appLogger('bootstrap');
  log.info('İZ başlatılıyor…');

  // Async bağımlılıkları burada çözüyoruz; provider'lara hazır veriyoruz.
  final preferences = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      // Provider tanımında `throw UnimplementedError` vardı —
      // gerçek örneği burada enjekte ediyoruz.
      appPreferencesProvider.overrideWithValue(AppPreferences(preferences)),
    ],
  );

  // Bakım işleri — kullanıcıyı bekletmeden arka planda.
  unawaited(_runMaintenance(container, log));

  runApp(UncontrolledProviderScope(container: container, child: const IzApp()));
}

/// Açılışta yapılan temizlik işleri.
Future<void> _runMaintenance(ProviderContainer container, Logger log) async {
  try {
    // FR-015 — çöp kutusunda 30 günü dolmuş anıları kalıcı sil.
    final db = container.read(appDatabaseProvider);
    final purged = await db.memoryDao.purgeExpiredTrash();
    if (purged > 0) {
      log.info('Çöp kutusundan $purged anı kalıcı silindi.');
    }

    // TODO(media): FR-044 — galeri asset'lerinin hâlâ var olup olmadığını
    // tembel biçimde doğrula ve originalStatus alanını güncelle.
  } on Object catch (e, s) {
    // Bakım işi başarısız olursa uygulama yine de açılmalı.
    log.warning('Açılış bakımı başarısız', e, s);
  }
}
