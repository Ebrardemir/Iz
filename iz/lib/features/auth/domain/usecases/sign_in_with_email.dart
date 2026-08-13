/// Giriş senaryosu.
///
/// BU NEDEN BİR UseCase? (core/usecase/usecase.dart'taki 4 kurala göre)
///   ✔ İş kuralı var → e-posta biçimi, şifre asgari uzunluğu
///   ✔ Aynı mantık iki ekranda tekrar edecek → giriş ve kayıt ekranları
///
/// Doğrulamayı ViewModel'e koysaydık kayıt ekranı yazılırken kopyalanırdı ve
/// ikisi zamanla birbirinden ayrışırdı.
///
/// DİKKAT: buradan kullanıcı METNİ dönmüyoruz, yalnızca [ValidationCode].
/// Domain dili bilmez; çeviriyi `core/l10n/failure_l10n.dart` seçer.
///
/// PROVIDER BURADA DEĞİL: bu dosya `domain/` altında ve ARCHITECTURE.md
/// domain'in Flutter'ı (dolayısıyla Riverpod'u) ve `data/` katmanını
/// bilmesini yasaklıyor. Kurulum
/// `presentation/providers/auth_providers.dart` içinde.
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz, bu yüzden private
// alanlara `this._repository` biçiminde initializing formal kullanamıyoruz
// (aynı gerekçe memory_repository_impl.dart'ta da geçerli).
// ignore_for_file: prefer_initializing_formals

import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/usecase/usecase.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/domain/repositories/auth_repository.dart';

final class SignInWithEmail extends UseCase<AuthSession, AuthCredentials> {
  const SignInWithEmail({required AuthRepository repository})
    : _repository = repository;

  final AuthRepository _repository;

  /// Şifre asgari uzunluğu. Sabit gömmek yerine sabit isim veriyoruz ki
  /// hata mesajındaki sayı ile kuraldaki sayı ASLA ayrışmasın.
  static const int minPasswordLength = 6;

  /// Kasıtlı olarak GEVŞEK bir e-posta kontrolü.
  ///
  /// "Doğru" e-posta regex'i (RFC 5322) yüzlerce karakterdir ve pratikte
  /// geçerli adresleri reddederek zarar verir. Burada sadece bariz hataları
  /// eliyoruz: boşluk yok, tek `@`, `@` sonrasında noktalı bir alan adı.
  /// Adresin gerçekten var olup olmadığını yalnızca doğrulama e-postası
  /// söyleyebilir — o da backend'in işi.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Kayıt ekranı da AYNI kuralı kullanır (bkz. SignUpWithEmail).
  /// İki yere kopyalasaydık biri değişip diğeri kalırdı ve kullanıcı kayıt
  /// olurken kabul edilen bir adresle giriş yapamaz hâle gelirdi.
  static bool isValidEmail(String email) => _emailPattern.hasMatch(email);

  @override
  Future<Result<AuthSession>> call(AuthCredentials credentials) async {
    final email = credentials.normalizedEmail;

    if (email.isEmpty) {
      return const Err(ValidationFailure(code: ValidationCode.emailRequired));
    }
    if (!isValidEmail(email)) {
      return const Err(ValidationFailure(code: ValidationCode.emailInvalid));
    }
    if (credentials.password.isEmpty) {
      return const Err(
        ValidationFailure(code: ValidationCode.passwordRequired),
      );
    }
    if (credentials.password.length < minPasswordLength) {
      return const Err(
        ValidationFailure(
          code: ValidationCode.passwordTooShort,
          // Çeviride "{min} karakter" yerine geçer.
          limit: minPasswordLength,
        ),
      );
    }

    return _repository.signInWithEmail(credentials.copyWith(email: email));
  }
}
