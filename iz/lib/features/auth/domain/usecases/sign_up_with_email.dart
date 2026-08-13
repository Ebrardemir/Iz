/// Kayıt senaryosu.
///
/// BU NEDEN BİR UseCase?
///   ✔ İş kuralı var → ad zorunlu, e-posta biçimi, şifre uzunluğu, eşleşme
///   ✔ Kuralların bir kısmı girişle ORTAK → tek kaynaktan gelmeli
///
/// E-posta ve şifre kurallarını [SignInWithEmail] ile paylaşıyoruz. İki yere
/// kopyalasaydık, biri değişip diğeri kalırdı: kullanıcı kayıt olurken kabul
/// edilen bir şifreyle giriş yapamaz hâle gelirdi.
///
/// DİKKAT: buradan kullanıcı METNİ dönmüyoruz, yalnızca [ValidationCode].
///
/// PROVIDER BURADA DEĞİL: bkz. `presentation/providers/auth_providers.dart`
/// ve [SignInWithEmail] dosyasındaki aynı not.
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz; initializing formal
// kullanamıyoruz (aynı gerekçe diğer UseCase'lerde de geçerli).
// ignore_for_file: prefer_initializing_formals

import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/usecase/usecase.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/domain/repositories/auth_repository.dart';
import 'package:iz/features/auth/domain/usecases/sign_in_with_email.dart';

final class SignUpWithEmail extends UseCase<AuthSession, SignUpDraft> {
  const SignUpWithEmail({required AuthRepository repository})
    : _repository = repository;

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession>> call(SignUpDraft draft) async {
    // SIRA ÖNEMLİ: hata formun EN ÜSTTEKİ sorunlu alanında gösterilir.
    // Aşağıdan yukarı doğrulasaydık kullanıcı önce alttaki hatayı düzeltir,
    // sonra üstte yenisiyle karşılaşırdı.
    if (draft.normalizedName.isEmpty) {
      return const Err(ValidationFailure(code: ValidationCode.nameRequired));
    }

    final email = draft.normalizedEmail;
    if (email.isEmpty) {
      return const Err(ValidationFailure(code: ValidationCode.emailRequired));
    }
    if (!SignInWithEmail.isValidEmail(email)) {
      return const Err(ValidationFailure(code: ValidationCode.emailInvalid));
    }

    if (draft.password.isEmpty) {
      return const Err(
        ValidationFailure(code: ValidationCode.passwordRequired),
      );
    }
    if (draft.password.length < SignInWithEmail.minPasswordLength) {
      return const Err(
        ValidationFailure(
          code: ValidationCode.passwordTooShort,
          limit: SignInWithEmail.minPasswordLength,
        ),
      );
    }
    if (!draft.passwordsMatch) {
      return const Err(
        ValidationFailure(code: ValidationCode.passwordsDoNotMatch),
      );
    }

    return _repository.signUpWithEmail(
      draft.copyWith(fullName: draft.normalizedName, email: email),
    );
  }
}
