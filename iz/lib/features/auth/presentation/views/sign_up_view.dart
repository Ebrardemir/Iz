/// Kayıt ekranı — MVVM'in **View** katmanı.
///
/// VIEW'IN KURALLARI:
///   ✔ `ref.watch` ile state okur
///   ✔ `ref.read(...).komut()` ile kullanıcı eylemini iletir
///   ✔ Navigasyonu YAPAR (ViewModel değil)
///   ✘ İş kuralı içermez — doğrulama `SignUpWithEmail` içinde
///
/// Düzen iskeleti giriş ekranıyla ORTAK: [AuthScaffold] görseli, kavisli kartı
/// ve responsive hesabı üstleniyor. Burada yalnızca formun kendisi var.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/presentation/view_models/sign_up_view_model.dart';
import 'package:iz/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:iz/features/auth/presentation/widgets/social_sign_in_button.dart';
import 'package:iz/shared/widgets/iz_wordmark.dart';

/// Formun kapladığı yükseklik — görselin ne kadar yer alacağını belirler.
///
/// ⚠️ ÖLÇÜLMÜŞ DEĞER, tahmin değil. Giriş ekranından büyük çünkü burada dört
/// alan ve alt alta iki sosyal buton var. Karta yeni bir alan eklersen bu sayı
/// büyür; `sign_up_view_test.dart` içindeki "kaydırmadan sığar" testi eskiyen
/// sayıyı yakalar.
///
/// 640 → 584: alanlar arası ve ayraç çevresindeki yedi boşluk `md`(16) yerine
/// `sm`(8) oldu. Kazanılan 56 px doğrudan görsele gitti; böylece kayıt
/// ekranının görseli giriş ekranıyla AYNI yükseklikte (300) duruyor —
/// iki ekran arasında geçerken kart zıplamıyor.
const double _kFormHeight = 584;

class SignUpView extends ConsumerStatefulWidget {
  const SignUpView({super.key});

  @override
  ConsumerState<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends ConsumerState<SignUpView> {
  // Controller ve focus'lar widget'a ait TEKNİK state — ViewModel'de değil.
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signUpProvider);
    final viewModel = ref.read(signUpProvider.notifier);

    _handleSideEffects();

    return AuthScaffold(
      formHeight: _kFormHeight,
      child: _SignUpForm(
        state: state,
        viewModel: viewModel,
        nameController: _nameController,
        emailController: _emailController,
        passwordController: _passwordController,
        confirmController: _confirmController,
        emailFocus: _emailFocus,
        passwordFocus: _passwordFocus,
        confirmFocus: _confirmFocus,
      ),
    );
  }

  /// Başarı ve hata bildirimlerini dinler.
  void _handleSideEffects() {
    ref.listen(signUpProvider, (previous, next) {
      // Kayıt başarılı → uygulamaya gir.
      if (next.session != null && previous?.session == null) {
        context.goNamed(AppRoute.home.name);
        return;
      }

      final failure = next.generalError;
      if (failure != null && previous?.generalError != failure) {
        context.showSnack(failure.localizedMessage(context.l10n));
        ref.read(signUpProvider.notifier).consumeError();
      }
    });
  }
}

class _SignUpForm extends StatelessWidget {
  const _SignUpForm({
    required this.state,
    required this.viewModel,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.confirmFocus,
  });

  final SignUpState state;
  final SignUpViewModel viewModel;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final FocusNode confirmFocus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = !state.isSubmitting;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: IzWordmark()),
        const SizedBox(height: AppSpacing.sm),

        // Alanlar arasında `md` boşluk: dördü sıkışık bir yığın değil,
        // ayrı ayrı okunan alanlar gibi dursun.
        _AuthTextField(
          controller: nameController,
          onChanged: viewModel.setFullName,
          hint: l10n.authFullName,
          icon: AppIcons.person,
          enabled: enabled,
          error: state.errorFor(AuthFormField.fullName),
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          onSubmitted: emailFocus.requestFocus,
        ),
        const SizedBox(height: AppSpacing.sm),

        _AuthTextField(
          controller: emailController,
          focusNode: emailFocus,
          onChanged: viewModel.setEmail,
          hint: l10n.authEmail,
          icon: AppIcons.email,
          enabled: enabled,
          error: state.errorFor(AuthFormField.email),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          onSubmitted: passwordFocus.requestFocus,
        ),
        const SizedBox(height: AppSpacing.sm),

        _AuthTextField(
          controller: passwordController,
          focusNode: passwordFocus,
          onChanged: viewModel.setPassword,
          hint: l10n.authPassword,
          icon: AppIcons.password,
          enabled: enabled,
          error: state.errorFor(AuthFormField.password),
          obscure: state.obscurePassword,
          onToggleObscure: viewModel.togglePasswordVisibility,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: confirmFocus.requestFocus,
        ),
        const SizedBox(height: AppSpacing.sm),

        _AuthTextField(
          controller: confirmController,
          focusNode: confirmFocus,
          onChanged: viewModel.setConfirmPassword,
          hint: l10n.authPasswordAgain,
          icon: AppIcons.password,
          enabled: enabled,
          error: state.errorFor(AuthFormField.confirmPassword),
          obscure: state.obscureConfirmPassword,
          onToggleObscure: viewModel.toggleConfirmPasswordVisibility,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onSubmitted: viewModel.signUp,
        ),

        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: state.canSubmit ? viewModel.signUp : null,
          child: state.isSubmitting
              ? const _ButtonSpinner()
              : Text(l10n.authSignUp),
        ),

        const SizedBox(height: AppSpacing.sm),
        _OrDivider(label: l10n.authOr),
        const SizedBox(height: AppSpacing.sm),

        // GİRİŞ EKRANINDAN FARKLI: burada butonlar ALT ALTA.
        // Referans tasarımda böyle ve etiketler ("Apple ile Devam Et") yan
        // yana sığmayacak kadar uzun; tam genişlik hem sığdırıyor hem de
        // dört alanlık formun ritmini bozmuyor.
        SocialSignInButton(
          brand: SocialProviderBrand.apple,
          label: l10n.authContinueWithApple,
          onPressed: enabled
              ? () => viewModel.signUpWith(AuthProvider.apple)
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        SocialSignInButton(
          brand: SocialProviderBrand.google,
          label: l10n.authContinueWithGoogle,
          onPressed: enabled
              ? () => viewModel.signUpWith(AuthProvider.google)
              : null,
        ),

        const SizedBox(height: AppSpacing.sm),
        _SignInPrompt(enabled: enabled),
      ],
    );
  }
}

/// Kayıt formundaki dört alan aynı iskeleti paylaşır: ikon, ipucu metni,
/// isteğe bağlı göz düğmesi ve hata satırı.
///
/// Ayrı bir widget olmasının sebebi dördünü tek tek yazmamak değil —
/// **tutarlılık**. Kopyalasaydık birinde `autocorrect` kapalı, ötekinde açık
/// kalırdı ve bu tür farklar gözle fark edilmez.
class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.onChanged,
    required this.hint,
    required this.icon,
    required this.enabled,
    this.focusNode,
    this.error,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final String hint;
  final IconData icon;
  final bool enabled;
  final ValidationFailure? error;

  /// Şifre alanı mı? Doluysa sonda göz düğmesi çıkar.
  final bool obscure;
  final VoidCallback? onToggleObscure;

  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final VoidCallback? onSubmitted;

  bool get _isPasswordField => onToggleObscure != null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted?.call(),
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      // E-posta ve şifrede otomatik düzeltme kullanıcıyı yorar.
      autocorrect: textCapitalization == TextCapitalization.words,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: AppIconSize.md),
        suffixIcon: _isPasswordField
            ? IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure ? AppIcons.passwordShow : AppIcons.passwordHide,
                  size: AppIconSize.md,
                ),
                // NFR-032 — ekran okuyucu bu düğmenin ne yaptığını bilmeli.
                tooltip: obscure
                    ? l10n.authShowPassword
                    : l10n.authHidePassword,
              )
            : null,
        // Hata METNİ değil hata NESNESİ taşınıyor; çeviri burada yapılıyor.
        errorText: error?.localizedMessage(l10n),
      ),
    );
  }
}

/// "————— veya —————" ayracı.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Divider(color: context.colors.outlineVariant));

    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// "Zaten hesabın var mı? **Giriş Yap**"
class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            l10n.authAlreadyHaveAccount,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          // `go` değil `pop`: kullanıcı giriş ekranından buraya geldiyse
          // yığında bir sayfa var; `go` kullansaydık yığın büyümeye devam
          // ederdi ve geri tuşu beklenmedik davranırdı.
          onPressed: enabled
              ? () => context.canPop()
                    ? context.pop()
                    : context.goNamed(AppRoute.signIn.name)
              : null,
          style: TextButton.styleFrom(
            textStyle: context.text.labelMedium,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            minimumSize: const Size(0, AppSpacing.minTapTarget),
          ),
          child: Text(l10n.authSignIn),
        ),
      ],
    );
  }
}

/// Butonun içine sığan yükleme göstergesi.
class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: AppIconSize.md,
    height: AppIconSize.md,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: context.colors.onPrimary,
    ),
  );
}
