/// [AuthRepository]'nin gerçek implementasyonu: kimlik Firebase'de
/// doğrulanır, KİMLİK KARARI bizim sunucumuzda verilir (ADR-B15).
///
/// AKIŞ
/// ```
/// 1. Firebase'e e-posta + şifre                → doğrulandı, uid alındı
/// 2. Firebase ID token'ıyla GET /v1/me         → BİZİM users.id'miz alındı
/// 3. Kimlik güvenli depoya yazıldı             → çevrimdışı açılış için
/// ```
///
/// NEDEN 2. ADIM ZORUNLU?
/// [AuthSession.userId] `OwnedTable.ownerId`'ye yazılacak değerdir ve
/// Firebase uid'si DEĞİL bizim UUID v7'miz olmalıdır. Yanlış kimlikle
/// damgalanan kayıtlar, ileride "anonim → hesap yükseltme" göçünü bozar
/// (BACKEND_YOL_HARITASI Faz 1, haritanın en riskli maddesi).
///
/// Bunun bedeli: **giriş ve kayıt ağ ister.** Bu bilinçli. Bulut hesabı
/// zaten çevrimdışı açılamaz, ve kimliği bilinmeyen bir oturum
/// senkronizasyonda kullanılamaz. Uygulamanın geri kalanı hesapsız tam
/// çalışmaya devam ediyor (ADR-B12).
///
/// NE YAPMIYOR:
///   • Form doğrulaması — kurallar `domain/usecases/` içinde.
///   • Token saklama/yenileme — Firebase SDK'sının işi (TR-M1-02).
///   • Şifre görme — şifre cihazdan doğrudan Google'a gidiyor.
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz, bu yüzden private
// alanlara `this._x` biçiminde initializing formal kullanamıyoruz (aynı
// gerekçe sign_in_with_email.dart ve api_client.dart'ta da geçerli).
// ignore_for_file: prefer_initializing_formals

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/network/network_providers.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/storage/secure_store.dart';
import 'package:iz/features/auth/data/sources/account_api.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/domain/repositories/auth_repository.dart';

final class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository({
    required AccountApi account,
    required SecureStore secureStore,
    fb.FirebaseAuth? auth,
  }) : _account = account,
       _secureStore = secureStore,
       _injected = auth;

  final AccountApi _account;
  final SecureStore _secureStore;

  /// [auth] yalnız testlerde verilir; üretimde varsayılan örnek kullanılır.
  ///
  /// Örnek TEMBEL okunuyor: `FirebaseAuth.instance`, `Firebase.initializeApp`
  /// çağrılmadan erişilirse hata fırlatır. Kurucuda okusaydık, hesap hiç
  /// kullanmayan bir kullanıcıda bile uygulama açılışta çökebilirdi.
  final fb.FirebaseAuth? _injected;

  fb.FirebaseAuth get _auth => _injected ?? fb.FirebaseAuth.instance;

  @override
  Future<Result<AuthSession>> signInWithEmail(
    AuthCredentials credentials,
  ) async {
    final fb.User? user;
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: credentials.normalizedEmail,
        password: credentials.password,
      );
      user = result.user;
    } on Object catch (error, stackTrace) {
      return Err(_mapError(error, stackTrace));
    }

    // _establishSession BİLEREK try'ın dışında: içeride ağ katmanı çalışıyor
    // ve o zaten hatalarını Result olarak döndürüyor. try içine alsaydık
    // Firebase hata sözlüğü (_mapError) sunucu hatalarını da çevirmeye
    // çalışırdı ve hepsini "beklenmeyen hata"ya düşürürdü.
    return _establishSession(user);
  }

  @override
  Future<Result<AuthSession>> signUpWithEmail(SignUpDraft draft) async {
    final fb.User? user;
    final name = draft.normalizedName;

    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: draft.normalizedEmail,
        password: draft.password,
      );
      user = result.user;

      // Firebase hesabı adsız açıyor; adı ayrı bir çağrıyla yazıyoruz.
      // Bu çağrı başarısız olursa hesap YİNE DE açılmıştır — kullanıcıyı
      // "kayıt olamadın" diye geri çevirmek yanlış olur, çünkü ikinci
      // denemesinde "bu e-posta kullanımda" hatası alırdı.
      if (user != null && name.isNotEmpty) {
        try {
          await user.updateDisplayName(name);
          // Elimizdeki token hesap AÇILIRKEN üretildi ve adı taşımıyor.
          // Sunucu adı token'dan okuduğu için tazelemezsek kaydı adsız açar.
          await user.getIdToken(true);
        } on Object {
          // Bilinçli olarak yutuluyor; gerekçesi yukarıda. Ad eksik kalırsa
          // aşağıdaki _establishSession onu PATCH ile tamamlıyor.
        }
      }
    } on Object catch (error, stackTrace) {
      return Err(_mapError(error, stackTrace));
    }

    return _establishSession(user, expectedDisplayName: name);
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
      // Kimliği ÖNCE siliyoruz. Ters sırada olsaydı ve silme başarısız
      // olsaydı, Firebase oturumu kapanmış ama bizim kimliğimiz cihazda
      // kalmış olurdu — sonraki kullanıcıya ait olmayan bir kimlik.
      await _secureStore.delete(SecureKey.izUserId);
      await _auth.signOut();
      return okUnit;
    } on Object catch (error, stackTrace) {
      return Err(_mapError(error, stackTrace));
    }
  }

  @override
  Future<Result<AuthSession?>> currentSession() async {
    final fb.User? user;
    try {
      user = _auth.currentUser;
    } on Object catch (error, stackTrace) {
      return Err(_mapError(error, stackTrace));
    }

    // Oturum YOKLUĞU bir hata değildir: hesapsız kullanım normal durum.
    if (user == null) {
      return const Ok(null);
    }

    // Önbellekten okuyabiliyorsak AĞA ÇIKMIYORUZ. Uygulama her açılışta
    // sunucuya sorsaydı, uçak modunda açan kullanıcı oturumunu kaybederdi.
    final cachedId = await _readCachedId();
    if (cachedId != null) {
      return Ok(
        AuthSession(
          userId: cachedId,
          email: user.email,
          displayName: user.displayName,
        ),
      );
    }

    // Önbellek yoksa (uygulama silinip kurulmuş, depo temizlenmiş) sunucuya
    // soruyoruz. Ağ yoksa HATA dönüyoruz — `Ok(null)` demek "oturum yok"
    // anlamına gelirdi ve bu bir YALAN olurdu: oturum var, biz çözemiyoruz.
    // Yalan söylersek uygulama kullanıcıyı anonim sanar ve kayıtları yanlış
    // sahiple damgalar.
    return switch (await _establishSession(user)) {
      Ok(:final value) => Ok(value),
      Err(:final failure) => Err(failure),
    };
  }

  /// Firebase kullanıcısını, SUNUCUDAKİ kimliğiyle birlikte bir oturuma çevirir.
  Future<Result<AuthSession>> _establishSession(
    fb.User? user, {
    String? expectedDisplayName,
  }) async {
    if (user == null) {
      // Firebase başarı döndürüp kullanıcı vermiyorsa elimizde oturum yok.
      return const Err(
        AuthFailure(message: 'firebase returned no user on success'),
      );
    }

    final fetched = await _account.fetchMe();
    if (fetched case Err(:final failure)) {
      return Err(failure);
    }

    var account = (fetched as Ok<RemoteAccount>).value;

    // Ad token'a henüz yansımamışsa sunucudaki kayıt adsız açılmış olabilir.
    // Kullanıcının forma yazdığı adı kaybetmemek için tamamlıyoruz.
    final wanted = expectedDisplayName;
    if (wanted != null && wanted.isNotEmpty && account.displayName == null) {
      final patched = await _account.updateProfile(displayName: wanted);
      if (patched case Ok(:final value)) {
        account = value;
      }
      // Başarısız olursa sessiz geçiyoruz: hesap açıldı, oturum geçerli.
      // Adı profil ekranından düzeltmek mümkün; kayıt akışını burada
      // kırmak kullanıcıyı çıkışsız bırakırdı.
    }

    await _cacheId(account.id);

    return Ok(
      AuthSession(
        userId: account.id,
        email: account.email ?? user.email,
        displayName: account.displayName ?? user.displayName,
      ),
    );
  }

  Future<String?> _readCachedId() async {
    try {
      return await _secureStore.read(SecureKey.izUserId);
    } on Object {
      // Güvenli depo okunamıyorsa önbellek yok sayılır ve sunucuya sorulur.
      // Bu bir hata değil, yavaş yol.
      return null;
    }
  }

  Future<void> _cacheId(String id) async {
    try {
      await _secureStore.write(SecureKey.izUserId, id);
    } on Object {
      // Yazamadıysak oturum yine geçerli; yalnız bir sonraki açılış ağ
      // isteyecek. Kullanıcıyı bu yüzden geri çevirmek orantısız olurdu.
    }
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
    // gösterilmiyor (TR-C-10). `l10n_test` ise features/ altındaki Türkçe
    // harf içeren HER literali yakalıyor; tek bir geliştirici mesajı için
    // dosyayı istisna listesine eklemek, ileride buradaki gerçek ihlalleri
    // de susturur. Türkçeye çevirme.
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
  /// İkisinin ayrışmasını `firebase_auth_repository_test.dart` denetliyor.
  static const int _minPasswordLength = 6;
}

/// Uygulamanın kullandığı kimlik implementasyonu.
///
/// ADR-B15'in ve mimarinin sınavı buydu: `StubAuthRepository`den gerçeğine
/// geçerken değişen tek satır bu oldu. Hiçbir View, ViewModel veya UseCase'e
/// dokunulmadı.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(
    account: AccountApi(client: ref.watch(apiClientProvider)),
    secureStore: ref.watch(secureStoreProvider),
  );
});
