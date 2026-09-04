/// Kayıt ekranı ViewModel'i.
///
/// `SignInViewModel` ile aynı deseni izler:
///   ✔ View'ın ihtiyacı olan state'i üretir
///   ✘ Widget bilmez, BuildContext tutmaz, Navigator çağırmaz
///   ✘ Hazır METİN tutmaz — hata NESNESİ tutar, çeviriyi View yapar
///
/// İki ekran ayrı ViewModel kullanıyor çünkü state'leri farklı (kayıtta ad ve
/// şifre tekrarı var). Ortak olan doğrulama kuralları ise UseCase katmanında
/// paylaşılıyor — asıl tekrarı önlemek gereken yer orası.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/presentation/providers/auth_providers.dart';

final class SignUpState {
  const SignUpState({
    this.draft = const SignUpDraft(),
    this.isSubmitting = false,
    this.obscurePassword = true,
    this.obscureConfirmPassword = true,
    this.validationError,
    this.generalError,
    this.session,
  });

  final SignUpDraft draft;
  final bool isSubmitting;

  /// İki şifre alanının göz ikonları BAĞIMSIZ çalışır: kullanıcı genelde
  /// yalnızca yanlış yazdığından şüphelendiği alanı açmak ister.
  final bool obscurePassword;
  final bool obscureConfirmPassword;

  final ValidationFailure? validationError;
  final Failure? generalError;
  final AuthSession? session;

  /// Buton alanlar boşken de aktif kalır: kullanıcı basınca hatayı GÖRMELİ.
  bool get canSubmit => !isSubmitting;

  ValidationFailure? errorFor(String field) =>
      validationError?.code.field == field ? validationError : null;

  SignUpState copyWith({
    SignUpDraft? draft,
    bool? isSubmitting,
    bool? obscurePassword,
    bool? obscureConfirmPassword,
    ValidationFailure? validationError,
    Failure? generalError,
    AuthSession? session,
    bool clearErrors = false,
  }) => SignUpState(
    draft: draft ?? this.draft,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    obscurePassword: obscurePassword ?? this.obscurePassword,
    obscureConfirmPassword:
        obscureConfirmPassword ?? this.obscureConfirmPassword,
    validationError: clearErrors
        ? null
        : (validationError ?? this.validationError),
    generalError: clearErrors ? null : (generalError ?? this.generalError),
    session: session ?? this.session,
  );
}

class SignUpViewModel extends Notifier<SignUpState> {
  @override
  SignUpState build() => const SignUpState();

  // --- Form komutları -------------------------------------------------------

  void setFullName(String value) => _update((d) => d.copyWith(fullName: value));

  void setEmail(String value) => _update((d) => d.copyWith(email: value));

  void setPassword(String value) => _update((d) => d.copyWith(password: value));

  void setConfirmPassword(String value) =>
      _update((d) => d.copyWith(confirmPassword: value));

  void togglePasswordVisibility() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);

  void toggleConfirmPasswordVisibility() => state = state.copyWith(
    obscureConfirmPassword: !state.obscureConfirmPassword,
  );

  // --- Eylemler -------------------------------------------------------------

  Future<void> signUp() async {
    if (state.isSubmitting) return; // çift dokunmaya karşı koruma

    state = state.copyWith(isSubmitting: true, clearErrors: true);

    final result = await ref.read(signUpWithEmailProvider)(state.draft);

    state = result.fold(
      onOk: (session) => state.copyWith(isSubmitting: false, session: session),
      // İş kuralı hatası → forma yansır. Diğer her şey → SnackBar.
      onErr: (failure) => state.copyWith(
        isSubmitting: false,
        validationError: failure is ValidationFailure ? failure : null,
        generalError: failure is ValidationFailure ? null : failure,
      ),
    );
  }

  Future<void> signUpWith(AuthProvider provider) async {
    if (state.isSubmitting) return;

    state = state.copyWith(isSubmitting: true, clearErrors: true);

    final result = await ref
        .read(authRepositoryProvider)
        .signInWithProvider(provider);

    state = result.fold(
      onOk: (session) => state.copyWith(isSubmitting: false, session: session),
      onErr: (failure) =>
          state.copyWith(isSubmitting: false, generalError: failure),
    );
  }

  /// View, hatayı gösterdikten sonra çağırır — aynı hata iki kez
  /// SnackBar açmasın.
  void consumeError() => state = state.copyWith(clearErrors: true);

  /// Kullanıcı yazmaya başlayınca hatayı temizler: ekranda düzeltmeye
  /// çalıştığı alanın altında eski hata durmasın.
  void _update(SignUpDraft Function(SignUpDraft draft) transform) {
    state = state.copyWith(draft: transform(state.draft), clearErrors: true);
  }
}

final signUpProvider = NotifierProvider<SignUpViewModel, SignUpState>(
  SignUpViewModel.new,
);
