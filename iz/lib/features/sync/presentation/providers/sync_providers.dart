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
import 'package:iz/features/auth/data/sources/account_api.dart';
import 'package:iz/features/sync/data/repositories/sync_engine.dart';
import 'package:iz/features/sync/data/sources/sync_api.dart';
import 'package:iz/features/sync/domain/repositories/sync_repository.dart';

final syncApiProvider = Provider<SyncApi>(
  (ref) => SyncApi(client: ref.watch(apiClientProvider)),
);

/// Hesap ucu — motorun kullanıcı kimliğini öğrendiği yer.
///
/// `auth` feature'ında değil burada tanımlı çünkü tek kullanıcısı motor.
/// Oraya taşımak, iki feature'ı birbirine bağlamak için bir sebep yaratırdı.
final accountApiProvider = Provider<AccountApi>(
  (ref) => AccountApi(client: ref.watch(apiClientProvider)),
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
    accounts: ref.watch(accountApiProvider),
    secureStore: ref.watch(secureStoreProvider),
    clock: ref.watch(clockProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    platform: currentPlatformName(),
  );
});
