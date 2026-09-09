/// [SyncIdentity]'nin gerçek uygulaması: önce güvenli depo, sonra sunucu.
///
/// ÖNBELLEK NEDEN VAR? Kimlik her eşitleme turunda gerekiyor; her turda ağa
/// çıkmak, uçak modunda bekleyen kuyruğun hiç denenememesi demekti. Bir kez
/// öğrenilen kimlik cihazda kalıyor.
///
/// `/v1/me` ÇAĞRISININ SUNUCUDA YAN ETKİSİ VAR: kullanıcı bizde ilk kez
/// görülüyorsa kaydı orada açılıyor (`EnsureUserHandler`). Yani ilk eşitleme
/// aynı zamanda hesabı da açıyor; ayrı bir "kayıt ol" ucu yok.
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz.
// ignore_for_file: prefer_initializing_formals

import 'package:iz/core/network/api_client.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/storage/secure_store.dart';
import 'package:iz/features/auth/data/sources/account_api.dart';
import 'package:iz/features/sync/domain/repositories/sync_identity.dart';

final class RemoteSyncIdentity implements SyncIdentity {
  /// [AccountApi] DIŞARIDAN DEĞİL BURADA kuruluyor.
  ///
  /// Provider'a parametre olarak verseydik `sync/presentation` katmanı
  /// `auth/data`yı import etmek zorunda kalırdı — TR-C-03 tam olarak bunu
  /// yasaklıyor. Bağımlılığı `data` katmanının içinde tutmak, sınırı
  /// hatırlanması gereken bir kural olmaktan çıkarıp yapısal hâle getiriyor.
  RemoteSyncIdentity({
    required IzApiClient client,
    required SecureStore secureStore,
  }) : _accounts = AccountApi(client: client),
       _store = secureStore;

  /// Testler için: hazır bir hesap ucuyla kurar.
  RemoteSyncIdentity.withAccounts({
    required AccountApi accounts,
    required SecureStore secureStore,
  }) : _accounts = accounts,
       _store = secureStore;

  final AccountApi _accounts;
  final SecureStore _store;

  @override
  Future<String?> ownerId() async {
    final onbellek = await _store.read(SecureKey.izUserId);
    if (onbellek != null && onbellek.isNotEmpty) return onbellek;

    final uzak = await _accounts.fetchMe();
    if (uzak case Ok(:final value)) {
      await _store.write(SecureKey.izUserId, value.id);
      return value.id;
    }

    // Ağ yoksa ve önbellek de boşsa kimlik BİLİNMİYOR. Uydurmak yerine
    // `null` dönüyoruz: yanlış sahiple yazılan bir satır, kullanıcının
    // verisini başka bir hesaba bağlamak olurdu.
    return null;
  }
}
