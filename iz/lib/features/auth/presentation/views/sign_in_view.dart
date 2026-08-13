/// Giriş ekranı — MVVM'in **View** katmanı.
///
/// VIEW'IN KURALLARI:
///   ✔ `ref.watch` ile state okur
///   ✔ `ref.read(...).komut()` ile kullanıcı eylemini iletir
///   ✔ Navigasyonu YAPAR (ViewModel değil)
///   ✘ İş kuralı içermez — doğrulama `SignInWithEmail` içinde
///
/// RESPONSIVE STRATEJİSİ (üç kural):
///   1. Görsel yükseklik ORANLA hesaplanır, sabit piksel yok; alt/üst sınırla
///      kısılır ki çok kısa ekranda kaybolmasın, tablette dev olmasın.
///   2. Form bir `maxWidth` ile sınırlanıp ORTALANIR. Tablette satırların
///      12 cm uzayıp okunmaz hâle gelmesini bu engeller.
///   3. Her şey kaydırılabilir ve `minHeight` ile ekranı doldurur — klavye
///      açılınca alanlar görünür kalır, kısa ekranda taşma olmaz.
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
import 'package:iz/features/auth/presentation/view_models/sign_in_view_model.dart';
import 'package:iz/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:iz/features/auth/presentation/widgets/social_sign_in_button.dart';
import 'package:iz/shared/widgets/iz_wordmark.dart';

/// Formun kapladığı yükseklik — görselin ne kadar yer alacağını belirler.
///
/// ⚠️ ÖLÇÜLMÜŞ DEĞER, tahmin değil. Karta yeni bir alan/buton eklersen bu
/// sayı büyür. Elle güncellemeyi unutma diye `sign_in_view_test.dart`
/// içinde "telefon boyutlarında kaydırma gerekmemeli" testi var — sayı
/// eskirse o test kırılır ve seni buraya yollar.
const double _kFormHeight = 580;

class SignInView extends ConsumerStatefulWidget {
  const SignInView({super.key});

  @override
  ConsumerState<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends ConsumerState<SignInView> {
  // Controller'lar widget'a ait TEKNİK state — ViewModel'de değil, burada.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signInProvider);
    final viewModel = ref.read(signInProvider.notifier);

    _handleSideEffects();

    return AuthScaffold(
      formHeight: _kFormHeight,
      child: _SignInForm(
        state: state,
        viewModel: viewModel,
        emailController: _emailController,
        passwordController: _passwordController,
        passwordFocus: _passwordFocus,
      ),
    );
  }

  /// Başarı ve hata bildirimlerini dinler.
  ///
  /// `ref.listen` build içinde ÇAĞRILIR ama build sırasında çalışmaz; state
  /// değiştiğinde tetiklenir. Navigasyon ve SnackBar için doğru yer burasıdır.
  void _handleSideEffects() {
    ref.listen(signInProvider, (previous, next) {
      // Giriş başarılı → uygulamaya gir.
      if (next.session != null && previous?.session == null) {
        context.goNamed(AppRoute.home.name);
        return;
      }

      final failure = next.generalError;
      if (failure != null && previous?.generalError != failure) {
        context.showSnack(failure.localizedMessage(context.l10n));
        ref.read(signInProvider.notifier).consumeError();
      }
    });
  }
}

/// Şifre sıfırlama isteği + kullanıcıya bildirim.
///
/// Bildirimi VIEW gösteriyor: `BuildContext` ViewModel'e girmez, bu yüzden
/// ViewModel sadece "oldu/olmadı" döner, metni ve SnackBar'ı biz seçeriz.
Future<void> _sendPasswordReset(
  BuildContext context,
  SignInViewModel viewModel,
) async {
  final l10n = context.l10n;
  final sent = await viewModel.requestPasswordReset();

  // `await` sonrası ekran kapanmış olabilir — bu satır şart.
  if (!context.mounted) return;

  context.showSnack(sent ? l10n.authResetLinkSent : l10n.authResetNeedsEmail);
}

/// Kartın içindeki form. Ayrı widget çünkü tek sorumluluğu var ve
/// `_SignInViewState`in build metodunu okunur tutuyor.
class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.state,
    required this.viewModel,
    required this.emailController,
    required this.passwordController,
    required this.passwordFocus,
  });

  final SignInState state;
  final SignInViewModel viewModel;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode passwordFocus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: IzWordmark()),
        const SizedBox(height: AppSpacing.sm),

        Text(
          l10n.authWelcomeBack,
          textAlign: TextAlign.center,
          // H2 (24). H1 (28) logoyla birlikte üst bloğu fazla
          // ağırlaştırıyordu.
          style: context.text.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.authWelcomeSubtitle,
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        _EmailField(
          controller: emailController,
          state: state,
          viewModel: viewModel,
          onSubmitted: passwordFocus.requestFocus,
        ),
        const SizedBox(height: AppSpacing.sm),
        _PasswordField(
          controller: passwordController,
          focusNode: passwordFocus,
          state: state,
          viewModel: viewModel,
        ),

        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: state.isSubmitting
                ? null
                : () => _sendPasswordReset(context, viewModel),
            // Butonun varsayılan etiketi 14 SemiBold; bu ikincil
            // bir bağlantı, birincil eylemle (Giriş Yap) aynı
            // ağırlıkta olmamalı.
            style: TextButton.styleFrom(textStyle: context.text.labelMedium),
            child: Text(l10n.authForgotPassword),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: state.canSubmit ? viewModel.signIn : null,
          child: state.isSubmitting
              ? const _ButtonSpinner()
              : Text(l10n.authSignIn),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: state.isSubmitting
              ? null
              : () => context.pushNamed(AppRoute.signUp.name),
          // Marka yeşili çerçeve — sosyal butonların nötr gri
          // çerçevesinden ayrılıp birincil eylemin eşi olması için.
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: context.colors.primary),
          ),
          child: Text(l10n.authCreateAccount),
        ),

        const SizedBox(height: AppSpacing.md),
        _OrDivider(label: l10n.authOr),
        const SizedBox(height: AppSpacing.md),

        _SocialRow(state: state, viewModel: viewModel),

        // Gizlilik notu, üstündeki butonlardan AYRI bir katman:
        // referans tasarımda arada belirgin bir nefes payı var,
        // not butonlara yapışmıyor.
        const SizedBox(height: AppSpacing.md),
        const _PrivacyNote(),
      ],
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({
    required this.controller,
    required this.state,
    required this.viewModel,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final SignInState state;
  final SignInViewModel viewModel;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TextField(
      controller: controller,
      onChanged: viewModel.setEmail,
      onSubmitted: (_) => onSubmitted(),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      // E-posta alanında otomatik büyük harf kullanıcıyı yorar.
      textCapitalization: TextCapitalization.none,
      autofillHints: const [AutofillHints.email],
      enabled: !state.isSubmitting,
      decoration: InputDecoration(
        hintText: l10n.authEmail,
        prefixIcon: const Icon(AppIcons.email, size: AppIconSize.md),
        // Hata METNİ değil hata NESNESİ taşınıyor; çeviri burada yapılıyor.
        errorText: state.errorFor(AuthFormField.email)?.localizedMessage(l10n),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.viewModel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final SignInState state;
  final SignInViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: viewModel.setPassword,
      onSubmitted: (_) => viewModel.signIn(),
      obscureText: state.obscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      enabled: !state.isSubmitting,
      decoration: InputDecoration(
        hintText: l10n.authPassword,
        prefixIcon: const Icon(AppIcons.password, size: AppIconSize.md),
        suffixIcon: IconButton(
          onPressed: viewModel.togglePasswordVisibility,
          icon: Icon(
            state.obscurePassword
                ? AppIcons.passwordShow
                : AppIcons.passwordHide,
            size: AppIconSize.md,
          ),
          // NFR-032 — ekran okuyucu bu butonun ne yaptığını bilmeli.
          tooltip: state.obscurePassword
              ? l10n.authShowPassword
              : l10n.authHidePassword,
        ),
        errorText: state
            .errorFor(AuthFormField.password)
            ?.localizedMessage(l10n),
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

/// Apple + Google butonları.
///
/// RESPONSIVE: dar ekranda yan yana sığmazlarsa alt alta geçerler.
/// Sabit `Row` kullansaydık küçük telefonlarda taşma hatası alırdık.
class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.state, required this.viewModel});

  final SignInState state;
  final SignInViewModel viewModel;

  /// Butonlar YAN YANA duruyor (referans tasarımdaki gibi).
  ///
  /// "Google ile Giriş Yap" 14 puntoda tek satıra sığmıyor; kırpmak yerine
  /// **iki satıra sarmasına** izin veriyoruz. Böylece üç şey birden korunuyor:
  /// yan yana düzen, 14 punto okunur yazı ve etiketin tamamı.
  ///
  /// Yalnızca gerçekten çok dar ekranlarda (katlanabilir telefonun kapalı
  /// hâli gibi) alt alta düşüyorlar — orada iki sütun fiziksel olarak imkânsız.
  static const double _stackBelow = 280;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = !state.isSubmitting;

    final apple = SocialSignInButton(
      brand: SocialProviderBrand.apple,
      // Yan yana duruyorlar → dar yerleşim.
      compact: true,
      label: l10n.authSignInWithApple,
      onPressed: enabled
          ? () => viewModel.signInWith(AuthProvider.apple)
          : null,
    );
    final google = SocialSignInButton(
      brand: SocialProviderBrand.google,
      compact: true,
      label: l10n.authSignInWithGoogle,
      onPressed: enabled
          ? () => viewModel.signInWith(AuthProvider.google)
          : null,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _stackBelow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              apple,
              const SizedBox(height: AppSpacing.sm),
              google,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: apple),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: google),
          ],
        );
      },
    );
  }
}

/// R-002 azaltımı: gizlilik endişesini ekranda açıkça karşılıyoruz.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final color = context.colors.onSurfaceVariant;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(AppIcons.secure, size: AppIconSize.sm, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            context.l10n.authPrivacyNote,
            // Caption 12 → Body Small-1 12 yerine bodySmall kullanıyoruz;
            // satır yüksekliği 18 olduğu için kilit ikonuyla hizası düzgün.
            style: context.text.bodySmall?.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
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
