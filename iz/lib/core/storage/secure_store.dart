/// NFR-010: "Yerel hassas veriler platformun güvenli depolama/anahtar zinciri
/// mekanizmalarıyla desteklenmelidir."
/// NFR-011: "Auth token, encryption key ve ödeme sırrı düz metin dosyada
/// saklanmamalıdır."
///
/// iOS Keychain / Android EncryptedSharedPreferences üzerine ince bir sarmalayıcı.
/// Doğrudan `FlutterSecureStorage` kullanmak yerine bunu kullan: anahtar
/// isimleri tek yerde toplanır ve testte sahtelemek kolaylaşır.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sahtelenebilmesi (mock) için arayüz.
abstract interface class SecureStore {
  Future<String?> read(SecureKey key);
  Future<void> write(SecureKey key, String value);
  Future<void> delete(SecureKey key);
  Future<void> clear();
}

enum SecureKey {
  /// FR-005 — uygulama kilidi PIN'inin hash'i (PIN'in kendisi DEĞİL).
  appLockPinHash('app_lock_pin_hash'),

  /// V1.5 — bulut oturumu.
  authAccessToken('auth_access_token'),
  authRefreshToken('auth_refresh_token'),

  /// NFR-016 — istemci tarafı şifreleme anahtarı (V1.5 teknik keşif).
  contentEncryptionKey('content_encryption_key');

  // NOT: alan adı `storageKey`, `name` DEĞİL — `name` her enum'da yerleşik
  // olarak vardır ve override edilemez.
  const SecureKey(this.storageKey);
  final String storageKey;
}

final class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(SecureKey key) => _storage.read(key: key.storageKey);

  @override
  Future<void> write(SecureKey key, String value) =>
      _storage.write(key: key.storageKey, value: value);

  @override
  Future<void> delete(SecureKey key) => _storage.delete(key: key.storageKey);

  @override
  Future<void> clear() => _storage.deleteAll();
}

final secureStoreProvider = Provider<SecureStore>((ref) {
  return const FlutterSecureStore(
    FlutterSecureStorage(
      // `first_unlock_this_device`: veri yalnızca bu cihazda çözülebilir ve
      // iCloud yedeğine taşınmaz — İZ'in privacy-first ilkesiyle uyumlu.
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  );
});
