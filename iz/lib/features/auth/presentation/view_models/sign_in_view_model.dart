/// Giriş ekranı ViewModel'i.
///
/// MVVM KURALLARI (bkz. ARCHITECTURE.md bölüm 4):
///   ✔ View'ın ihtiyacı olan state'i üretir
///   ✔ Komutları alır (giriş yap, sosyal giriş, şifre göster/gizle)
///   ✘ Widget bilmez, BuildContext tutmaz, Navigator çağırmaz
///   ✘ Hazır METİN tutmaz — hata NESNESİ tutar, çeviriyi View yapar
///
/// Navigasyonu View üstlenir: [SignInState.session] dolunca ekranı değiştirir
/// (bkz. sign_in_view.dart → `ref.listen`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/features/auth/data/repositories/stub_auth_repository.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/presentation/providers/auth_providers.dart';

final class SignInState {
  const SignInState({
    this.credentials = const AuthCredentials(),
    this.isSubmitting = false,
    this.obscurePassword = true,
    this.validationError,
    this.generalError,
    this.session,
  });

  final AuthCredentials credentials;

  /// Giriş isteği sürüyor mu? Butonu kilitler ve gösterge çıkarır.
  final bool isSubmitting;

  /// Şifre alanının göz ikonu durumu. Bu bir GÖRÜNÜM tercihi ama widget
  /// yeniden kurulduğunda (rotasyon) kaybolmaması için ViewModel'de.
  final bool obscurePassword;

  /// Alan bazlı iş kuralı hatası. Hangi alanın altında görüneceğini
  /// `code.field` söyler.
  final ValidationFailure? validationError;

  /// Alanla eşleşmeyen hata (SnackBar'da gösterilir).
  final Failure? generalError;

  /// Giriş başarılı olduğunda dolar → View bunu görüp yönlendirir.
  final AuthSession? session;

  /// Buton, alanlar boşken de aktif kalır: kullanıcı basınca hatayı
  /// GÖRMELİ. Sessizce devre dışı bir buton "neden çalışmıyor?" sorusu yaratır.
  bool get canSubmit => !isSubmitting;

  /// Verilen form alanı için hata varsa döner.
  ValidationFailure? errorFor(String field) =>
      validationError?.code.field == field ? validationError : null;

  SignInState copyWith({
    AuthCredentials? credentials,
    bool? isSubmitting,
    bool? obscurePassword,
    ValidationFailure? validationError,
    Failure? generalError,
    AuthSession? session,
    bool clearErrors = false,
  }) => SignInState(
    credentials: credentials ?? this.credentials,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    obscurePassword: obscurePassword ?? this.obscurePassword,
    validationError: clearErrors
        ? null
        : (validationError ?? this.validationError),
    generalError: clearErrors ? null : (generalError ?? this.generalError),
    session: session ?? this.session,
  );
}

class SignInViewModel extends Notifier<SignInState> {
  @override
  SignInState build() => const SignInState();

  // --- Form komutları -------------------------------------------------------

  void setEmail(String value) => state = state.copyWith(
    credentials: state.credentials.copyWith(email: value),
    clearErrors: true,
  );

  void setPassword(String value) => state = state.copyWith(
    credentials: state.credentials.copyWith(password: value),
    clearErrors: true,
  );

  void togglePasswordVisibility() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);

  // --- Eylemler -------------------------------------------------------------

  Future<void> signIn() async {
    if (state.isSubmitting) return; // çift dokunmaya karşı koruma

    state = state.copyWith(isSubmitting: true, clearErrors: true);

    final result = await ref.read(signInWithEmailProvider)(state.credentials);

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

  Future<void> signInWith(AuthProvider provider) async {
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

  /// Şifre sıfırlama bağlantısı ister.
  ///
  /// E-posta boşsa isteği hiç göndermiyoruz — kullanıcıya hangi adrese
  /// gönderileceğini sormadan "gönderildi" demek yanıltıcı olur.
  /// Sonucu View'a `bool` olarak döndürüyoruz: bildirimi (SnackBar) göstermek
  /// View'ın işi, ViewModel `BuildContext` tutmaz.
  Future<bool> requestPasswordReset() async {
    final email = state.credentials.normalizedEmail;
    if (email.isEmpty) {
      state = state.copyWith(
        validationError: const ValidationFailure(
          code: ValidationCode.emailRequired,
        ),
      );
      return false;
    }

    final result = await ref
        .read(authRepositoryProvider)
        .sendPasswordReset(email);

    return result.fold(
      onOk: (_) => true,
      onErr: (failure) {
        state = state.copyWith(generalError: failure);
        return false;
      },
    );
  }

  /// View, hatayı gösterdikten sonra çağırır — aynı hata iki kez
  /// SnackBar açmasın.
  void consumeError() => state = state.copyWith(clearErrors: true);
}

final signInProvider = NotifierProvider<SignInViewModel, SignInState>(
  SignInViewModel.new,
);
