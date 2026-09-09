/// Senkronizasyonun DI bağlantıları.
///
/// ⚠️ MOTOR `cloudSync` BAYRAĞININ ARKASINDA. Bayrak kapalıyken
/// [syncRepositoryProvider] `null` döndürüyor ve motorun tek satırı bile
/// çalışmıyor — sunucuya hiçbir istek gitmiyor.
///
/// Bayrağı burada okumak bilinçli: her çağrı yerine `if (flags.cloudSync)`
/// yazsaydık biri bir gün unuturdu ve yarım kalmış bir özellik sessizce
/// yayına çıkardı.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/config/feature_flags.dart';
import 'package:iz/core/network/network_providers.dart';
import 'package:iz/core/storage/secure_store.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/sync/data/repositories/sync_engine.dart';
import 'package:iz/features/sync/data/sources/remote_sync_identity.dart';
import 'package:iz/features/sync/data/sources/sync_api.dart';
import 'package:iz/features/sync/domain/repositories/sync_identity.dart';
import 'package:iz/features/sync/domain/repositories/sync_repository.dart';

final syncApiProvider = Provider<SyncApi>(
  (ref) => SyncApi(client: ref.watch(apiClientProvider)),
);

/// Motorun kimlik kaynağı.
///
/// ⚠️ BURADA `AccountApi` GÖRÜNMÜYOR ve bu bir mimari zorunluluk:
/// `presentation` katmanı BAŞKA bir feature'ın `data/`sine bakamaz
/// (ARCHITECTURE.md §2, CI'daki TR-C-03 denetimi). Hesap ucuna erişim
/// `sync/data/sources/remote_sync_identity.dart` içinde — orada `data` →
/// `data` geçişi serbest.
final syncIdentityProvider = Provider<SyncIdentity>(
  (ref) => RemoteSyncIdentity(
    client: ref.watch(apiClientProvider),
    secureStore: ref.watch(secureStoreProvider),
  ),
);

/// Cihazın platform adı — sunucudaki `devices.platform`.
///
/// `dart:io` yerine `defaultTargetPlatform`: testte ve web'de de çalışıyor,
/// eklenti gerektirmiyor. Sunucu tanımadığı bir platformu reddetmiyor,
/// `unknown` diye kaydediyor.
String currentPlatformName() => switch (defaultTargetPlatform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  _ => defaultTargetPlatform.name,
};

/// Senkronizasyon motoru — bayrak kapalıysa `null`.
///
/// `null` döndürmek, çağıranı "eşitleme var mı?" diye düşünmeye zorluyor.
/// Sahte bir "hiçbir şey yapmayan" motor döndürseydik, bayrak kapalıyken
/// ekranda "eşitleniyor…" yazması gibi yanıltıcı durumlar mümkün olurdu.
final syncRepositoryProvider = Provider<SyncRepository?>((ref) {
  if (!ref.watch(featureFlagsProvider).cloudSync) return null;

  return SyncEngine(
    database: ref.watch(appDatabaseProvider),
    api: ref.watch(syncApiProvider),
    identity: ref.watch(syncIdentityProvider),
    secureStore: ref.watch(secureStoreProvider),
    clock: ref.watch(clockProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    platform: currentPlatformName(),
  );
});
