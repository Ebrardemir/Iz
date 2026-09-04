/// Kayıt ekranı widget testi.
///
/// `sign_in_view_test.dart` ile aynı iki soruyu sorar:
///   1. MVVM bağlantısı — yazılan metin ViewModel'e gidiyor, hata forma
///      dönüyor, başarı yönlendiriyor.
///   2. RESPONSIVE — telefon boyutlarında taşma yok ve kaydırma gerekmiyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/domain/repositories/auth_repository.dart';
import 'package:iz/features/auth/presentation/views/sign_up_view.dart';

class _FakeAuthRepository implements AuthRepository {
  Result<AuthSession> response = const Ok(AuthSession(userId: 'u1'));
  int signUpCalls = 0;

  @override
  Future<Result<AuthSession>> signUpWithEmail(SignUpDraft d) async {
    signUpCalls++;
    return response;
  }

  @override
  Future<Result<AuthSession>> signInWithEmail(AuthCredentials c) async =>
      response;

  @override
  Future<Result<AuthSession>> signInWithProvider(AuthProvider p) async =>
      response;

  @override
  Future<Result<Unit>> sendPasswordReset(String email) async => okUnit;

  @override
  Future<Result<Unit>> signOut() async => okUnit;

  @override
  Future<Result<AuthSession?>> currentSession() async => const Ok(null);
}

/// Gerçek fontlar şart: test fontunun metrikleri farklı olduğu için
/// "ekrana sığıyor mu" sorusuna yanlış cevap verir.
Future<void> _loadRealFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }

  await load('CormorantGaramond', [
    'assets/fonts/CormorantGaramond-Variable.ttf',
  ]);
  await load('Poppins', [
    'assets/fonts/Poppins-Regular.ttf',
    'assets/fonts/Poppins-Medium.ttf',
    'assets/fonts/Poppins-SemiBold.ttf',
  ]);
  await load('packages/lucide_icons_flutter/Lucide', [
    'packages/lucide_icons_flutter/assets/lucide.ttf',
  ]);
  await load('packages/font_awesome_flutter/FontAwesomeBrands', [
    'packages/font_awesome_flutter/lib/fonts/'
        'Font-Awesome-7-Brands-Regular-400.otf',
  ]);
}

Future<void> _pumpSignUp(
  WidgetTester tester, {
  required Size size,
  _FakeAuthRepository? repository,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          repository ?? _FakeAuthRepository(),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // GERÇEK router kullanıyoruz: ekran başarı durumunda
        // `goNamed(timeline)` çağırıyor. Düz `MaterialApp` ile bu çağrı
        // patlar ve testin asıl doğrulamak istediği şeyi gölgeler.
        routerConfig: _testRouter(),
      ),
    ),
  );
  await tester.pump();
}

/// Kayıt ekranı + varış noktası. Uygulamanın gerçek router'ını kurmak
/// veritabanı ve tercihler gerektirirdi; test yalnızca bu iki rotayı bilmeli.
GoRouter _testRouter() => GoRouter(
  initialLocation: AppRoute.signUp.path,
  routes: [
    GoRoute(
      path: AppRoute.signUp.path,
      name: AppRoute.signUp.name,
      builder: (context, state) => const SignUpView(),
    ),
    GoRoute(
      path: AppRoute.home.path,
      name: AppRoute.home.name,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('ANA SAYFA'))),
    ),
  ],
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
  });

  testWidgets('tasarımdaki tüm öğeler ekranda', (tester) async {
    await _pumpSignUp(tester, size: const Size(390, 844));

    expect(find.text('Kayıt Ol'), findsOneWidget);
    expect(find.text('veya'), findsOneWidget);
    expect(find.text('Apple ile Devam Et'), findsOneWidget);
    expect(find.text('Google ile Devam Et'), findsOneWidget);
    expect(find.text('Zaten hesabın var mı?'), findsOneWidget);
    // Dört alan: Ad Soyad, e-posta, şifre, şifreyi tekrar gir
    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('boş formda önce ad hatası görünür', (tester) async {
    await _pumpSignUp(tester, size: const Size(390, 844));

    await tester.tap(find.text('Kayıt Ol'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Adını ve soyadını gir.'), findsOneWidget);
  });

  testWidgets('şifreler eşleşmezse ikinci alanda hata görünür', (tester) async {
    await _pumpSignUp(tester, size: const Size(390, 844));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ebrar Arın');
    await tester.enterText(fields.at(1), 'ebrar@example.com');
    await tester.enterText(fields.at(2), 'gizli123');
    await tester.enterText(fields.at(3), 'baskasey');

    await tester.tap(find.text('Kayıt Ol'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
  });

  testWidgets('geçerli formda repository çağrılır', (tester) async {
    final repository = _FakeAuthRepository();
    await _pumpSignUp(
      tester,
      size: const Size(390, 844),
      repository: repository,
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ebrar Arın');
    await tester.enterText(fields.at(1), 'ebrar@example.com');
    await tester.enterText(fields.at(2), 'gizli123');
    await tester.enterText(fields.at(3), 'gizli123');

    await tester.tap(find.text('Kayıt Ol'));
    await tester.pump();
    await tester.pump();

    expect(repository.signUpCalls, 1);
  });

  testWidgets('iki şifre alanının göz düğmesi bağımsız çalışır', (
    tester,
  ) async {
    await _pumpSignUp(tester, size: const Size(390, 844));

    TextField fieldAt(int i) =>
        tester.widget<TextField>(find.byType(TextField).at(i));

    expect(fieldAt(2).obscureText, isTrue);
    expect(fieldAt(3).obscureText, isTrue);

    // İlk şifre alanının göz düğmesine bas.
    await tester.tap(find.byTooltip('Şifreyi göster').first);
    await tester.pump();

    expect(fieldAt(2).obscureText, isFalse);
    // Diğeri ETKİLENMEMELİ.
    expect(fieldAt(3).obscureText, isTrue);
  });

  testWidgets('kimlik hatası SnackBar ile bildirilir', (tester) async {
    final repository = _FakeAuthRepository()
      ..response = const Err(AuthFailure());

    await _pumpSignUp(
      tester,
      size: const Size(390, 844),
      repository: repository,
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ebrar Arın');
    await tester.enterText(fields.at(1), 'ebrar@example.com');
    await tester.enterText(fields.at(2), 'gizli123');
    await tester.enterText(fields.at(3), 'gizli123');

    await tester.tap(find.text('Kayıt Ol'));
    await tester.pump();
    await tester.pump();

    expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
  });

  group('responsive', () {
    const sizes = <String, Size>{
      'küçük telefon (iPhone SE)': Size(320, 568),
      'küçük telefon': Size(360, 800),
      'standart telefon': Size(390, 844),
      'büyük telefon': Size(430, 932),
      'tablet dikey': Size(768, 1024),
      'telefon yatay': Size(844, 390),
    };

    sizes.forEach((label, size) {
      testWidgets('$label — taşma yok', (tester) async {
        await _pumpSignUp(tester, size: size);

        expect(
          tester.takeException(),
          isNull,
          reason: '$label boyutunda düzen taştı',
        );
        expect(find.text('Kayıt Ol'), findsOneWidget);
      });
    });

    // `_kFormHeight` sabitinin bekçisi — forma yeni alan eklenirse kırılır.
    const phones = <String, Size>{
      'küçük telefon': Size(360, 800),
      'standart telefon': Size(390, 844),
      'büyük telefon': Size(430, 932),
    };

    phones.forEach((label, size) {
      testWidgets('$label — kaydırmadan sığar', (tester) async {
        await _pumpSignUp(tester, size: size);

        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;

        expect(
          position.maxScrollExtent,
          0,
          reason:
              '$label boyutunda içerik ${position.maxScrollExtent.toInt()}px '
              'taşıyor. sign_up_view.dart içindeki _kFormHeight sabitini '
              'bu kadar artır.',
        );
      });
    });
  });
}
