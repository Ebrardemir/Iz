/// Giriş + kayıt ekranlarının ORTAK düzen kuralları.
///
/// Bu dosya tek bir ekranı değil, `AuthScaffold`ün iki ekranda birden
/// tutması gereken sözleşmesini doğruluyor:
///   1. Kart her zaman ekranın DİBİNE oturur — ne boşluk kalır ne taşma.
///   2. İki ekranın görseli aynı yükseklikte olur — ekran değiştirirken
///      kart zıplamaz.
///
/// (1) neden burada? Hata simülatörde GÖRÜNMÜYORDU: jest çubuğu olmayan
/// bir ekranda hesap doğru çıkıyor, gerçek telefonda çubuk kadar kayıyordu.
/// Bu yüzden testler jest çubuğunu açıkça taklit ediyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/auth/presentation/views/sign_in_view.dart';
import 'package:iz/features/auth/presentation/views/sign_up_view.dart';

import '../helpers/real_fonts.dart';

/// Ekranı kurar ve kartın dikey sınırlarını döndürür.
Future<({double heroBottom, double cardTop, double cardBottom})> pumpAuth(
  WidgetTester tester,
  Widget view, {
  Size size = const Size(390, 844),
  double gestureBar = 0,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0
    ..padding = FakeViewPadding(bottom: gestureBar)
    ..viewPadding = FakeViewPadding(bottom: gestureBar);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: view,
      ),
    ),
  );
  await tester.pump();

  final card = tester.getRect(find.byType(DecoratedBox).first);
  return (
    heroBottom: tester.getRect(find.byType(Image).first).bottom,
    cardTop: card.top,
    cardBottom: card.bottom,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });

  group('kart ekranın dibine oturur', () {
    // 0 = jest çubuğu yok (eski iPhone / simülatör)
    // 34 = iPhone jest çubuğu, 48 = Android gezinme çubuğu
    for (final gestureBar in [0.0, 34.0, 48.0]) {
      testWidgets('giriş — jest çubuğu $gestureBar', (tester) async {
        final r = await pumpAuth(
          tester,
          const SignInView(),
          gestureBar: gestureBar,
        );

        // REGRESYON: `formHeight` alt güvenli alanı saymadığı için gerçek
        // telefonda kart çubuk kadar aşağı taşıyor, sayfa kayıyor ve kart
        // ekranın dibine oturmuyordu.
        expect(r.cardBottom, closeTo(844, 0.5));
      });

      testWidgets('kayıt — jest çubuğu $gestureBar', (tester) async {
        final r = await pumpAuth(
          tester,
          const SignUpView(),
          gestureBar: gestureBar,
        );
        expect(r.cardBottom, closeTo(844, 0.5));
      });
    }
  });

  testWidgets('iki ekranın görseli aynı yükseklikte', (tester) async {
    final signIn = await pumpAuth(tester, const SignInView());
    final signUp = await pumpAuth(tester, const SignUpView());

    // Kayıt formu daha uzun; boşlukları kısarak görsele giriş ekranıyla
    // AYNI yeri bıraktık. Biri değişip diğeri değişmezse kart iki ekran
    // arasında zıplar — bu test onu yakalar.
    expect(signUp.heroBottom, signIn.heroBottom);
    expect(signUp.cardTop, signIn.cardTop);
  });
}
