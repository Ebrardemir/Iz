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

/// ⚠️ BURAYA `authAccessToken` / `authRefreshToken` EKLEME.
/// İkisi de vardı ve kaldırıldı: kimlik doğrulamayı Firebase yapıyor
/// (ADR-B15) ve token'ı kendi güvenli deposunda tutup kendi yeniliyor
/// (TR-M1-02). Token'ı bir de biz saklasaydık iki kopya olurdu ve biri
/// bayatladığında hangisinin doğru olduğunu bilemezdik.
enum SecureKey {
  /// FR-005 — uygulama kilidi PIN'inin hash'i (PIN'in kendisi DEĞİL).
  appLockPinHash('app_lock_pin_hash'),

  /// Sunucudaki `users.id` — BİZİM UUID v7'miz, Firebase uid'si değil.
  ///
  /// NEDEN SAKLANIYOR? Uygulama çevrimdışı açıldığında oturumu geri
  /// yükleyebilmek için. Firebase kimin giriş yaptığını kendi deposundan
  /// biliyor ama BİZİM kimliğimizi bilmiyor; onu `/v1/me` söylüyor ve o
  /// çağrı ağ ister. Önbellek olmasaydı uçak modunda açılan uygulama,
  /// oturumu açık olan kullanıcıyı çözemezdi.
  ///
  /// Neden güvenli depoda: kimliğin kendisi sır değil ama kullanıcıyı
  /// tekilleştiren bir değer ve `shared_preferences` düz metin dosyadır.
  izUserId('iz_user_id'),

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
