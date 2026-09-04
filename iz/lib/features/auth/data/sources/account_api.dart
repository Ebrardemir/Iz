/// Sunucudaki hesap uçları (`/v1/me`).
///
/// NEDEN `data/sources/` DİYE YENİ BİR KLASÖR?
/// `data/daos/` yerel veritabanına, `data/repositories/` domain sözleşmesine
/// bakıyor. Bu sınıf ikisi de değil: UZAK bir veri kaynağı. Repository'nin
/// içine gömmek, "Firebase'e sor" ile "kendi sunucumuza sor" mantığını tek
/// sınıfta karıştırmak olurdu; ayrı durunca ikisi ayrı ayrı test edilebiliyor.
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz, bu yüzden private
// alanlara `this._x` biçiminde initializing formal kullanamıyoruz (aynı
// gerekçe sign_in_with_email.dart ve api_client.dart'ta da geçerli).
// ignore_for_file: prefer_initializing_formals

import 'package:iz/core/network/api_client.dart';
import 'package:iz/core/result/result.dart';

/// `/v1/me` yanıtı.
///
/// Sunucudaki `MeResponse` ile alan alan aynı
/// (`api/src/Iz.Api/Endpoints/MeEndpoints.cs`).
final class RemoteAccount {
  const RemoteAccount({
    required this.id,
    required this.plan,
    this.email,
    this.displayName,
    this.locale,
  });

  /// BİZİM kimliğimiz — sunucudaki `users.id`, UUID v7.
  ///
  /// Firebase uid'si DEĞİL. `OwnedTable.ownerId`'ye yazılacak değer budur.
  final String id;

  /// `free` · `plus` · `family`. Planın tek kaynağı sunucudur (ADR-B08).
  final String plan;

  final String? email;
  final String? displayName;
  final String? locale;

  /// Gövdeyi okur; beklenen alanlar yoksa istisna fırlatır.
  ///
  /// Fırlatmak bilinçli: çağıran taraf bunu [IzApiClient] içinde yakalayıp
  /// "sunucu yanıtı çözümlenemedi" hatasına çeviriyor. Burada `null`
  /// döndürseydik, eksik alanı sessizce boş geçmiş olurduk.
  static RemoteAccount fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return RemoteAccount(
      id: map['id']! as String,
      plan: map['plan']! as String,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      locale: map['locale'] as String?,
    );
  }
}

/// `final` DEĞİL — testler sahteleyebilsin diye.
///
/// `core/storage/secure_store.dart` aynı ihtiyacı ayrı bir arayüzle çözüyor.
/// Burada iki metot için ayrı arayüz açmak tören olurdu; sınıfı uygulanabilir
/// bırakmak yeterli. Kural şu: bu sınıfa DAVRANIŞ eklenmez, yalnız uç nokta
/// çağrısı taşır — o yüzden sahtelemek gerçeği ıskalamaz.
class AccountApi {
  const AccountApi({required IzApiClient client}) : _client = client;

  final IzApiClient _client;

  /// Oturum açmış kullanıcının profilini getirir.
  ///
  /// Sunucu tarafında bu çağrının bir YAN ETKİSİ var: kullanıcı bizde ilk kez
  /// görülüyorsa kaydı burada açılıyor (`EnsureUserHandler`). Yani ayrı bir
  /// "kayıt ol" ucu yok; ilk `/v1/me` hesabı da açıyor.
  Future<Result<RemoteAccount>> fetchMe() =>
      _client.get('/v1/me', parse: RemoteAccount.fromJson);

  /// Profil alanlarını günceller (FR-003).
  ///
  /// `null` bırakılan alan DEĞİŞMEZ — sunucudaki PATCH semantiğiyle aynı.
  /// Alanı boşaltmak için boş dize gönderilir.
  Future<Result<RemoteAccount>> updateProfile({
    String? displayName,
    String? locale,
  }) => _client.patch(
    '/v1/me',
    body: {'displayName': ?displayName, 'locale': ?locale},
    parse: RemoteAccount.fromJson,
  );
}
