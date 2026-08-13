/// FR-001: "Uygulama ilk açılışta ürünün 'tüm galeriyi yedeklemeyen
/// seçilmiş anı' yaklaşımını kısa onboarding ile açıklamalıdır."
/// FR-004: kullanıcıyı boş ekranda bırakmak yerine ilk anıya yönlendir.
/// Rapor 20.2: local-only yaklaşımı ve veri kaybı riski **dürüstçe** anlatılmalı.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/storage/app_preferences.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final _controller = PageController();
  int _page = 0;

  /// NEDEN `static const` DEĞİL?
  /// Sayfa metinleri artık çeviriden geliyor ve çeviri `BuildContext`e
  /// bağlıdır. Sabit bir listede tutulsalardı dil değişince güncellenmezlerdi.
  /// Bu yüzden liste her `build`de l10n'dan üretiliyor — maliyeti ihmal
  /// edilebilir (üç kayıt), kazancı doğruluk.
  static List<({IconData icon, String title, String body})> _pagesOf(
    AppL10n l10n,
  ) => [
    (
      icon: AppIcons.memory,
      title: l10n.onboardingCurateTitle,
      body: l10n.onboardingCurateBody,
    ),
    (
      icon: AppIcons.onboardingContext,
      title: l10n.onboardingContextTitle,
      body: l10n.onboardingContextBody,
    ),
    (
      icon: AppIcons.device,
      title: l10n.onboardingLocalTitle,
      body: l10n.onboardingLocalBody,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(appPreferencesProvider).setOnboardingCompleted(value: true);

    if (!mounted) return;
    // Onboarding → giriş. Akış: tanıtım → hesap → uygulama.
    //
    // NOT: FR-004 "kullanıcıyı boş ekranda bırakma, ilk anıya yönlendir"
    // diyor. O yönlendirme artık giriş yapıldıktan SONRA yapılmalı;
    // hesap akışı tamamlanınca buraya geri dönülecek.
    context.goNamed(AppRoute.signIn.name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = _pagesOf(l10n);
    final isLast = _page == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(l10n.commonSkip),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _page = index),
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  final page = pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          page.icon,
                          size: AppIconSize.xxl,
                          color: context.colors.primary,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          page.title,
                          style: context.text.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          page.body,
                          style: context.text.bodyLarge?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages.length; i++)
                  AnimatedContainer(
                    duration: AppDuration.fast,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? context.colors.primary
                          : context.colors.outlineVariant,
                      borderRadius: const BorderRadius.all(AppRadius.xs),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLast
                      ? _finish
                      : () => _controller.nextPage(
                          duration: AppDuration.normal,
                          curve: Curves.easeOut,
                        ),
                  child: Text(isLast ? l10n.onboardingStart : l10n.commonNext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
