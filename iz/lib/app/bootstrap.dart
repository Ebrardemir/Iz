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

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/app/app.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/config/app_config.dart';
import 'package:iz/core/config/feature_flags.dart';
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/network/auth_token_provider.dart';
import 'package:iz/core/storage/app_preferences.dart';
import 'package:iz/core/storage/secure_store.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/auth/data/repositories/firebase_auth_token_provider.dart';
import 'package:iz/features/sync/presentation/providers/sync_providers.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> bootstrap() async {
  // Platform kanallarını kullanmadan önce şart.
  WidgetsFlutterBinding.ensureInitialized();

  initLogging();
  installGlobalErrorHandlers();

  final log = appLogger('bootstrap');
  log.info('İZ başlatılıyor…');

  await _initFirebase(log);

  // Async bağımlılıkları burada çözüyoruz; provider'lara hazır veriyoruz.
  final preferences = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      // Provider tanımında `throw UnimplementedError` vardı —
      // gerçek örneği burada enjekte ediyoruz.
      appPreferencesProvider.overrideWithValue(AppPreferences(preferences)),

      // Ağ katmanının kimlik kaynağı. `core/` Firebase'i tanımıyor
      // (ARCHITECTURE.md §2); somut örneği bilen tek yer burası —
      // her şeyi bilmeye yetkili composition root.
      authTokenProviderProvider.overrideWithValue(FirebaseAuthTokenProvider()),

      // YEREL GELİŞTİRMEDE senkronizasyon AÇIK.
      //
      // Staging ve üretimde kapalı kalıyor: bayrağı kullanıcıya açmak
      // ADR-B09 gereği Faz 4'ün (abonelik) tamamlanmasına bağlı. Burada
      // açmamızın sebebi, motoru gerçek cihazda/emülatörde deneyebilmek —
      // yalnız testlerle doğrulanan bir senkronizasyon, ilk gerçek
      // kullanıcıda sürpriz üretirdi.
      if (AppConfig.current.isDev)
        featureFlagsProvider.overrideWithValue(const FeatureFlags.dev()),
    ],
  );

  // KAPSAMI AÇ — VERİ OKUNMADAN ÖNCE.
  //
  // Sahipli tablolardaki her sorgu aktif hesaba göre süzülüyor. Kapsam
  // kurulmadan bir liste açılırsa hesaplı kullanıcı kendi verisini BOŞ
  // görür; üstelik bunu bir hata olarak değil "hiç anım yok" diye okur.
  //
  // `runApp`tan ve zamanlayıcıdan ÖNCE ve `await` ile: ikisi de hemen veri
  // okumaya başlıyor.
  await _kapsamiAc(container, log);

  // ZAMANLAYICIYI UYANDIR.
  //
  // Riverpod tembel: bu satır olmazsa `syncSchedulerProvider` hiç
  // oluşturulmaz ve uygulama SESSİZCE hiç eşitlenmez — ne hata verir ne de
  // bir iz bırakır. Bayrak kapalıysa provider zaten `null` döndürüyor.
  container.read(syncSchedulerProvider);

  // Bakım işleri — kullanıcıyı bekletmeden arka planda.
  unawaited(_runMaintenance(container, log));

  runApp(UncontrolledProviderScope(container: container, child: const IzApp()));
}

/// Cihazda saklı hesap kimliğini yerel veritabanının kapsamına yazar.
///
/// KİMLİK `SecureStore`DAN OKUNUYOR, sunucudan değil: açılış ağa
/// bağlanamamalı. Uçak modunda açan kullanıcı da kendi verisini görmeli.
///
/// Okunamazsa hesapsız kapsamda kalıyoruz — güvenli yön. Ters varsayım
/// (bilinmiyorsa her şeyi göster) tam da düzeltmeye çalıştığımız sızıntı
/// olurdu.
Future<void> _kapsamiAc(ProviderContainer container, Logger log) async {
  try {
    final kimlik = await container
        .read(secureStoreProvider)
        .read(SecureKey.izUserId);
    container.read(appDatabaseProvider).ownerScope.enter(kimlik);
  } on Object catch (e, s) {
    log.warning(
      'Hesap kapsamı okunamadı; hesapsız kipte devam ediliyor.',
      e,
      s,
    );
  }
}

/// Firebase'i başlatır — ama başlatamazsa uygulamayı DURDURMAZ.
///
/// NEDEN HATA FIRLATMIYORUZ?
/// Ürünün duruşu "uygulama hesap dayatmaz, hesapsız tam çalışır"
/// (ADR-B12). Anılar cihazda; Firebase yalnız bulut isteyen kullanıcı için
/// gerekli. Başlatma hatasında uygulamayı açılmaz hâle getirmek, hesabı
/// hiç kullanmayan birinin anılarına erişimini bir bulut servisinin
/// durumuna bağlamak olurdu.
///
/// Bu durumda kimlik uçları çalışmaz; [FirebaseAuthRepository] gelen
/// `no-app` hatasını yakalayıp geliştiriciye ne yapması gerektiğini söyler.
///
/// Platform yapılandırması (Android'de `google-services.json`) eksikse
/// yerelde tam olarak buraya düşülür — beklenen ve zararsız bir durum.
Future<void> _initFirebase(Logger log) async {
  try {
    await Firebase.initializeApp();
    log.info('Firebase hazır.');
  } on Object catch (e, s) {
    log.warning(
      'Firebase başlatılamadı; uygulama yalnız-cihaz kipinde devam ediyor.',
      e,
      s,
    );
  }
}

/// Açılışta yapılan temizlik işleri.
Future<void> _runMaintenance(ProviderContainer container, Logger log) async {
  try {
    // FR-015 — çöp kutusunda 30 günü dolmuş anıları kalıcı sil.
    final db = container.read(appDatabaseProvider);
    final purged = await db.memoryDao.purgeExpiredTrash(
      now: container.read(clockProvider).now(),
    );
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
