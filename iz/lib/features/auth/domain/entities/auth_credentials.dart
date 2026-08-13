/// Giriş formunun taşıdığı veri.
///
/// NEDEN AYRI BİR SINIF?
/// ViewModel'den UseCase'e iki ayrı `String` geçirmek yerine tek nesne
/// taşıyoruz. Yarın "beni hatırla" veya "tek kullanımlık kod" eklendiğinde
/// imzalar değişmez, sadece bu sınıf büyür.
///
/// SAF DART: burada Flutter yok, doğrulama yok. Doğrulama iş kuralıdır ve
/// `usecases/sign_in_with_email.dart` içinde yaşar.
library;

import 'package:equatable/equatable.dart';

final class AuthCredentials extends Equatable {
  const AuthCredentials({this.email = '', this.password = ''});

  final String email;
  final String password;

  /// Kullanıcı boşlukla başlayan e-posta yazabilir; karşılaştırma ve
  /// gönderim için baştaki/sondaki boşlukları temizliyoruz.
  String get normalizedEmail => email.trim();

  AuthCredentials copyWith({String? email, String? password}) =>
      AuthCredentials(
        email: email ?? this.email,
        password: password ?? this.password,
      );

  @override
  List<Object?> get props => [email, password];
}

/// Kayıt formunun taşıdığı veri.
///
/// [AuthCredentials]'tan AYRI bir tip: kayıt formunda ad ve şifre tekrarı da
/// var. Tek bir sınıfa doldurup girişte boş bırakmak, "bu alan burada geçerli
/// mi?" sorusunu her çağrı yerine taşırdı.
final class SignUpDraft extends Equatable {
  const SignUpDraft({
    this.fullName = '',
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
  });

  final String fullName;
  final String email;
  final String password;
  final String confirmPassword;

  String get normalizedName => fullName.trim();
  String get normalizedEmail => email.trim();

  /// Şifre alanları boşluk İÇEREBİLİR ve bu anlamlıdır — bu yüzden trim yok,
  /// karşılaştırma birebir.
  bool get passwordsMatch => password == confirmPassword;

  SignUpDraft copyWith({
    String? fullName,
    String? email,
    String? password,
    String? confirmPassword,
  }) => SignUpDraft(
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    password: password ?? this.password,
    confirmPassword: confirmPassword ?? this.confirmPassword,
  );

  @override
  List<Object?> get props => [fullName, email, password, confirmPassword];
}

/// Giriş başarılı olduğunda dönen oturum bilgisi.
///
/// ŞİMDİLİK SADE: backend seçilmediği için (Firebase mi, kendi API mi)
/// yalnızca her iki dünyada da var olan alanları taşıyor. Backend belli
/// olunca burası büyür; ekranların hiçbiri değişmez.
final class AuthSession extends Equatable {
  const AuthSession({required this.userId, this.email, this.displayName});

  final String userId;
  final String? email;
  final String? displayName;

  @override
  List<Object?> get props => [userId, email, displayName];
}

/// Sosyal giriş sağlayıcıları (FR — "Apple ile", "Google ile").
enum AuthProvider { apple, google }
