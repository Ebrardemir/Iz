/// Kimlik doğrulama sözleşmesi.
///
/// SADECE ARAYÜZ — implementasyon yok. Backend'in ne olacağı henüz belli
/// değil (Firebase Auth mı, kendi API'niz mi). Bu dosya o kararı **bekletmeyi**
/// mümkün kılıyor: ekranlar bu arayüzü görür, arkasında ne olduğunu bilmez.
///
/// Backend geldiğinde yapılacak tek şey: bu arayüzü uygulayan yeni bir sınıf
/// yazıp `authRepositoryProvider`ı ona bağlamak. Hiçbir View, hiçbir ViewModel
/// değişmez.
library;

import 'package:iz/core/result/result.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';

abstract interface class AuthRepository {
  /// E-posta + şifre ile giriş.
  ///
  /// `Result` döner, exception fırlatmaz — hata da bir dönüş değeridir
  /// (bkz. core/result/result.dart).
  Future<Result<AuthSession>> signInWithEmail(AuthCredentials credentials);

  /// Yeni hesap oluşturur ve oturumu açar.
  Future<Result<AuthSession>> signUpWithEmail(SignUpDraft draft);

  /// Apple / Google ile giriş.
  Future<Result<AuthSession>> signInWithProvider(AuthProvider provider);

  /// Şifre sıfırlama bağlantısı gönderir.
  Future<Result<Unit>> sendPasswordReset(String email);

  Future<Result<Unit>> signOut();

  /// Açılışta "kullanıcı zaten giriş yapmış mı?" sorusunun cevabı.
  /// Oturum yoksa `Ok(null)` döner — bu bir hata değildir.
  Future<Result<AuthSession?>> currentSession();
}
