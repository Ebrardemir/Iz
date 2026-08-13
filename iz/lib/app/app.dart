/// Kök widget.
///
/// `MaterialApp.router` kullanıyoruz çünkü navigasyonu GoRouter yönetiyor.
/// Tema ve dil `settingsProvider`dan geliyor — kullanıcı ayarı değiştirince
/// tüm uygulama anında yeniden temalanır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iz/app/iz_scroll_behavior.dart';
import 'package:iz/app/router/app_router.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/settings/presentation/view_models/settings_view_model.dart';

class IzApp extends ConsumerWidget {
  const IzApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      // Kaydırma hissi platforma göre değişmesin: kenar efekti yok, sade
      // yukarı-aşağı hareket (bkz. IzScrollBehavior).
      scrollBehavior: const IzScrollBehavior(),
      title: 'İZ',
      debugShowCheckedModeBanner: false,

      routerConfig: router,

      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,

      locale: settings.locale,
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      builder: (context, child) {
        // --- Tarihlerin dili ------------------------------------------------
        // `DateFormat` (intl paketi) Flutter'ın dil sisteminden BAĞIMSIZDIR;
        // kendi global `Intl.defaultLocale` değişkenine bakar. Bunu
        // ayarlamazsak kullanıcı arayüzü İngilizce yapsa bile tarihler
        // cihazın dilinde ("12 Mart 2026") kalır.
        //
        // Burada okuyoruz çünkü kullanıcının seçimi `null` (sistem dili)
        // olabilir; `Localizations.localeOf` MaterialApp'in ÇÖZDÜĞÜ dili
        // verir — yani gerçekte gösterilen dili.
        Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();

        // NFR-032: "Dinamik yazı boyutları ... desteklenmelidir."
        // Kullanıcının sistem yazı boyutuna saygı duyuyoruz ama aşırı
        // büyümede düzenin bozulmaması için üst sınır koyuyoruz.
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.8,
              maxScaleFactor: 1.6,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
