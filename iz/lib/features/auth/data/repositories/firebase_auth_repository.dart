/// [AuthRepository]'nin Firebase Authentication ile gerçek implementasyonu
/// (ADR-B15).
///
/// NE YAPIYOR: kullanıcıyı Firebase'e doğrulatıyor ve Firebase'in hata
/// kodlarını uygulamanın kendi hata sözlüğüne (`core/error/failure.dart`)
/// çeviriyor.
///
/// NE YAPMIYOR:
///   • **Form doğrulaması yapmıyor.** E-posta biçimi ve şifre uzunluğu
///     kuralları `domain/usecases/` içinde yaşıyor ve oraya uğramadan bu
///     sınıf hiç çağrılmıyor. Burada tekrar denetlemek, iki kuralın zamanla
///     ayrışması demekti.
///   • **Token saklamıyor, yenilemiyor.** Firebase SDK'sı ID token'ı kendi
///     güvenli deposunda tutuyor ve süresi dolmadan yeniliyor (TR-M1-02).
///     Elle refresh yazmak, doğru yapılmadığında sessiz oturum kayıplarına
///     yol açan bir iştir; SDK'nın çözdüğü bir sorunu yeniden çözmüyoruz.
///   • **Şifre görmüyor.** Şifre cihazdan doğrudan Google'a gidiyor; bizim
///     sunucumuza hiç uğramıyor.
library;

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/domain/repositories/auth_repository.dart';

final class FirebaseAuthRepository implements AuthRepository {
  /// [auth] yalnız testlerde verilir; üretimde varsayılan örnek kullanılır.
  ///
  /// Örnek TEMBEL okunuyor: `FirebaseAuth.instance`, `Firebase.initializeApp`
  /// çağrılmadan erişilirse hata fırlatır. Bunu kurucuda okusaydık, hesap
  /// hiç kullanmayan bir kullanıcıda bile uygulama açılışta çökebilirdi —
  /// oysa ürünün duruşu "uygulama hesapsız tam çalışır" (ADR-B12).
  const FirebaseAuthRepository({fb.FirebaseAuth? auth}) : _injected = auth;

  final fb.FirebaseAuth? _injected;

  fb.FirebaseAuth get _auth => _injected ?? fb.FirebaseAuth.instance;

  @override
  Future<Result<AuthSession>> signInWithEmail(
    AuthCredentials credentials,
  ) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: credentials.normalizedEmail,
        password: credentials.password,
      );
      return _sessionFrom(result.user);
    } on Object catch (error, stackTrace) {
      return Err(_mapError(error, stackTrace));
    }
  }

  @override
  Future<Result<AuthSession>> signUpWithEmail(SignUpDraft draft) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: draft.normalizedEmail,
        password: draft.password,
      );

      final user = result.user;
      final name = draft.normalizedName;

      // Firebase hesabı adsız açıyor; adı ayrı bir çağrıyla yazıyoruz.
      // Bu çağrı başarısız olursa hesap YİNE DE açılmıştır — kullanıcıyı
      // "kayıt olamadın" diye geri çevirmek yanlış olur, çünkü ikinci
      // denemesinde "bu e-posta kullanımda" hatası alırdı. Ad eksik kalır,
      // profil ekranından düzeltilebilir.
      if (user != null && name.isNotEmpty) {
        try {
          await user.updateDisplayName(name);
        } on Object {
          // Bilinçli olarak yutuluyor; gerekçesi yukarıda.
        }
      }

      return _sessionFrom(user, displayNameOverride: name);
    } on Object catch (error, stackTrace) {
      return Err(_mapError(error, stackTrace));
    }
  }

  @override
  Future<Result<AuthSession>> signInWithProvider(AuthProvider provider) async {
    // Apple ve Google girişi henüz bağlanmadı: ikisi de bu sınıfın dışında
    // iş istiyor (Android için SHA-1 parmak izi, iOS için Apple geliştirici
    // hesabı ve ek paketler).
    //
    // Sessizce "giriş başarısız" demiyoruz: kullanıcı şifresiyle uğraşmaya
    // başlardı. Ayrı bir sebep taşıyarak dürüst bir mesaj gösteriyoruz.
    return const Err(
      AuthFailure(
        reason: AuthFailureReason.providerUnavailable,
        message: 'social sign-in not configured',
      ),
    );
  }

  @override
  Future<Result<Unit>> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return okUnit;
    } on Object catch (error, stackTrace) {
      return Err(_mapError(error, stackTrace));
    }
  }

  @override
  Future<Result<Unit>> signOut() async {
    try {
      await _auth.signOut();
      return okUnit;
    } on Object catch (error, stackTrace) {
      return Err(_mapError(error, stackTrace));
    }
  }

  @override
  Future<Result<AuthSession?>> currentSession() async {
    try {
      final user = _auth.currentUser;
      // Oturum YOKLUĞU bir hata değildir: hesapsız kullanım normal durum.
      if (user == null) {
        return const Ok(null);
      }

      return switch (_sessionFrom(user)) {
        Ok(:final value) => Ok(value),
        Err(:final failure) => Err(failure),
      };
    } on Object catch (error, stackTrace) {
      return Err(_mapError(error, stackTrace));
    }
  }

  /// Firebase kullanıcısını uygulamanın oturum nesnesine çevirir.
  ///
  /// ⚠️ [AuthSession.userId] şu an **Firebase uid'sini** taşıyor. Sunucudaki
  /// `users.id` ise bizim kendi UUID v7'miz ve ikisi AYNI DEĞİL (bkz.
  /// `api/src/Iz.Domain/Users/User.cs`). Ağ katmanı yazılıp `/v1/me`
  /// çağrılmaya başlandığında oturum bizim kimliğimizi taşıyacak.
  ///
  /// O güne kadar bu değer `OwnedTable.ownerId`'ye **YAZILMAMALIDIR**:
  /// yazılırsa yerel kayıtlar Firebase uid'siyle damgalanır ve ilerideki göç
  /// (BACKEND_YOL_HARITASI Faz 1, "anonim → hesap yükseltme") yanlış
  /// kimlikten başlar.
  Result<AuthSession> _sessionFrom(
    fb.User? user, {
    String? displayNameOverride,
  }) {
    if (user == null) {
      // Firebase başarı döndürüp kullanıcı vermiyorsa elimizde oturum yok.
      return const Err(
        AuthFailure(message: 'firebase returned no user on success'),
      );
    }

    final override = displayNameOverride;
    return Ok(
      AuthSession(
        userId: user.uid,
        email: user.email,
        displayName: (override != null && override.isNotEmpty)
            ? override
            : user.displayName,
      ),
    );
  }

  /// Firebase hata kodlarını uygulamanın hata sözlüğüne çevirir.
  ///
  /// Tanımadığımız bir kod [UnexpectedFailure] olur — sessizce "şifre
  /// hatalı"ya çevirmek, gerçek arızayı kullanıcının hatası gibi göstermek
  /// olurdu.
  Failure _mapError(Object error, StackTrace stackTrace) {
    if (error is! fb.FirebaseException) {
      return UnexpectedFailure(cause: error, stackTrace: stackTrace);
    }

    // Firebase hiç başlatılmamışsa gelen kod budur. Kullanıcı hatası değil,
    // yapılandırma eksiğidir.
    //
    // MESAJ NEDEN İNGİLİZCE? Bu metin loga gidiyor, kullanıcıya asla
    // gösterilmiyor (TR-C-10). `l10n_test` ise Türkçe harf içeren HER
    // literali yakalıyor; tek bir geliştirici mesajı için bu dosyayı
    // istisna listesine eklemek, ileride buradaki gerçek ihlalleri de
    // susturur. Türkçeye çevirme.
    if (error.code == 'no-app') {
      return UnexpectedFailure(
        message:
            'Firebase is not initialized. Call Firebase.initializeApp in '
            'main.dart and make sure the platform config is in place.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return switch (error.code) {
      // Ağ: tekrar denenebilir, çevrimdışı rozeti gösterilir.
      'network-request-failed' => NetworkFailure(
        isOffline: true,
        cause: error,
        stackTrace: stackTrace,
      ),

      // Kayıt hataları: kullanıcının düzeltebileceği bir ALAN var, dolayısıyla
      // form hatası olarak dönüyorlar ve ilgili alanın altında gösteriliyorlar.
      'email-already-in-use' => const ValidationFailure(
        code: ValidationCode.emailAlreadyInUse,
      ),
      'weak-password' => const ValidationFailure(
        code: ValidationCode.passwordTooShort,
        limit: _minPasswordLength,
      ),
      'invalid-email' => const ValidationFailure(
        code: ValidationCode.emailInvalid,
      ),

      // Giriş reddi. 'invalid-credential' yeni Firebase'in BİRLEŞİK kodudur:
      // "kullanıcı yok" ile "şifre yanlış"ı bilerek ayırmaz, çünkü ayırmak
      // saldırgana hangi e-postaların kayıtlı olduğunu söylerdi.
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => AuthFailure(cause: error, stackTrace: stackTrace),

      'too-many-requests' => AuthFailure(
        reason: AuthFailureReason.tooManyAttempts,
        cause: error,
        stackTrace: stackTrace,
      ),
      'user-disabled' => AuthFailure(
        reason: AuthFailureReason.accountDisabled,
        cause: error,
        stackTrace: stackTrace,
      ),
      'user-token-expired' || 'requires-recent-login' => AuthFailure(
        reason: AuthFailureReason.sessionExpired,
        cause: error,
        stackTrace: stackTrace,
      ),

      // Firebase konsolunda e-posta/şifre yöntemi kapalıysa gelir.
      // Kullanıcının yapabileceği bir şey yok; "şifren yanlış" yanıltıcı olur.
      'operation-not-allowed' => AuthFailure(
        reason: AuthFailureReason.providerUnavailable,
        cause: error,
        stackTrace: stackTrace,
      ),

      _ => UnexpectedFailure(cause: error, stackTrace: stackTrace),
    };
  }

  /// Domain'deki `SignInWithEmail.minPasswordLength` ile aynı sayı olmalı.
  ///
  /// Buradan import edemiyoruz: `const` bir switch kolunda kullanmak için
  /// derleme zamanı sabiti gerekiyor ve domain sabitini `const` bağlamında
  /// kullanmak katman sırasını tersine çevirmezdi ama okunurluğu bozardı.
  /// İki sayının ayrışmasını `firebase_auth_repository_test.dart` denetliyor.
  static const int _minPasswordLength = 6;
}

/// Uygulamanın kullandığı kimlik implementasyonu.
///
/// ADR-B15'in ve mimarinin sınavı buydu: `StubAuthRepository`den gerçeğine
/// geçerken değişen tek satır bu oldu. Hiçbir View, ViewModel veya UseCase'e
/// dokunulmadı.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return const FirebaseAuthRepository();
});
