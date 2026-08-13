/// Giriş ekranı widget testi.
///
/// İKİ ŞEYİ DOĞRULUYOR:
///   1. MVVM bağlantısı — yazılan metin ViewModel'e gidiyor, hata forma
///      dönüyor, başarı yönlendiriyor.
///   2. RESPONSIVE — küçük telefondan tablete kadar hiçbir ekran boyutunda
///      taşma (overflow) olmuyor.
///
/// (2) özellikle değerli: taşma hataları yalnızca o boyuttaki cihazda
/// görünür ve elle test edilmezse kullanıcıya ulaşır.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/auth/data/repositories/stub_auth_repository.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/domain/repositories/auth_repository.dart';
import 'package:iz/features/auth/presentation/views/sign_in_view.dart';

/// Testin ağ gecikmesi beklemesin diye anında cevap veren sahte repository.
class _FakeAuthRepository implements AuthRepository {
  Result<AuthSession> response = const Ok(AuthSession(userId: 'u1'));
  int signInCalls = 0;

  @override
  Future<Result<AuthSession>> signInWithEmail(AuthCredentials c) async {
    signInCalls++;
    return response;
  }

  @override
  Future<Result<AuthSession>> signUpWithEmail(SignUpDraft d) async => response;

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

Future<void> _pumpSignIn(
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
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SignInView(),
      ),
    ),
  );
  await tester.pump();
}

/// Testin GERÇEK fontlarla koşması şart.
///
/// `flutter test` varsayılan olarak metrikleri farklı bir yedek font kullanır;
/// o fontla ölçülen yükseklikler uygulamadakinden sapar ve "ekrana sığıyor mu"
/// testi yanlış cevap verir. Fontları elle yükleyerek testi üretimle
/// aynı zemine oturtuyoruz.
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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
  });

  testWidgets('tasarımdaki tüm öğeler ekranda', (tester) async {
    await _pumpSignIn(tester, size: const Size(390, 844));

    expect(find.text('Tekrar hoş geldin'), findsOneWidget);
    expect(
      find.text('Değerli anılarına kaldığın yerden devam et.'),
      findsOneWidget,
    );
    expect(find.text('Giriş Yap'), findsOneWidget);
    expect(find.text('Hesap Oluştur'), findsOneWidget);
    expect(find.text('Şifremi unuttum'), findsOneWidget);
    expect(find.text('veya'), findsOneWidget);
    expect(find.text('Apple ile Giriş Yap'), findsOneWidget);
    expect(find.text('Google ile Giriş Yap'), findsOneWidget);
    expect(
      find.text('Verilerin güvende. Gizliliğine saygı duyuyoruz.'),
      findsOneWidget,
    );
  });

  testWidgets('boş formda e-posta hatası alanın altında görünür', (
    tester,
  ) async {
    await _pumpSignIn(tester, size: const Size(390, 844));

    await tester.tap(find.text('Giriş Yap'));
    await tester.pump();
    await tester.pump();

    expect(find.text('E-posta adresini gir.'), findsOneWidget);
  });

  testWidgets('geçersiz e-posta biçimi bildirilir', (tester) async {
    await _pumpSignIn(tester, size: const Size(390, 844));

    await tester.enterText(find.byType(TextField).first, 'ebrar');
    await tester.enterText(find.byType(TextField).last, 'gizli123');
    await tester.tap(find.text('Giriş Yap'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Geçerli bir e-posta adresi gir.'), findsOneWidget);
  });

  testWidgets('kimlik hatası SnackBar ile bildirilir', (tester) async {
    final repository = _FakeAuthRepository()
      ..response = const Err(AuthFailure());

    await _pumpSignIn(
      tester,
      size: const Size(390, 844),
      repository: repository,
    );

    await tester.enterText(find.byType(TextField).first, 'ebrar@example.com');
    await tester.enterText(find.byType(TextField).last, 'gizli123');
    await tester.tap(find.text('Giriş Yap'));
    await tester.pump();
    await tester.pump();

    expect(repository.signInCalls, 1);
    expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
  });

  testWidgets('şifre görünürlüğü değiştirilebilir', (tester) async {
    await _pumpSignIn(tester, size: const Size(390, 844));

    TextField passwordField() =>
        tester.widget<TextField>(find.byType(TextField).last);

    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byTooltip('Şifreyi göster'));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
    expect(find.byTooltip('Şifreyi gizle'), findsOneWidget);
  });

  group('responsive — hiçbir boyutta taşma olmamalı', () {
    // Gerçek cihaz ölçüleri: en küçük yaygın telefondan tablete.
    const sizes = <String, Size>{
      'küçük telefon (iPhone SE)': Size(320, 568),
      'standart telefon': Size(390, 844),
      'büyük telefon': Size(430, 932),
      'tablet dikey': Size(768, 1024),
      'tablet yatay': Size(1024, 768),
      'telefon yatay': Size(844, 390),
    };

    sizes.forEach((label, size) {
      testWidgets(label, (tester) async {
        await _pumpSignIn(tester, size: size);

        // Taşma olsaydı Flutter test sırasında exception atardı; bu satır
        // onu açıkça yakalar ve hangi boyutta olduğunu söyler.
        expect(
          tester.takeException(),
          isNull,
          reason: '$label boyutunda düzen taştı',
        );
        expect(find.text('Giriş Yap'), findsOneWidget);
      });
    });

    // Yaygın telefonlarda ekran KAYDIRMA GEREKTİRMEMELİ.
    //
    // Bu test `_kCardContentHeight` sabitinin bekçisidir: karta yeni bir alan
    // veya buton eklenirse form büyür, o sabit eskir ve içerik ekrandan taşar.
    // Test o anda kırılır ve kaç piksel eklemen gerektiğini söyler.
    const phones = <String, Size>{
      'küçük telefon': Size(360, 800),
      'standart telefon': Size(390, 844),
      'büyük telefon': Size(430, 932),
    };

    phones.forEach((label, size) {
      testWidgets('$label — kaydırmadan sığar', (tester) async {
        await _pumpSignIn(tester, size: size);

        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;

        expect(
          position.maxScrollExtent,
          0,
          reason:
              '$label boyutunda içerik ${position.maxScrollExtent.toInt()}px '
              'taşıyor. sign_in_view.dart içindeki _kCardContentHeight '
              'sabitini bu kadar artır.',
        );
      });
    });

    testWidgets('geniş ekranda form okunur genişlikte kalır', (tester) async {
      await _pumpSignIn(tester, size: const Size(1024, 768));

      // Tablette buton ekranın tamamına yayılmamalı — okunabilirlik sınırı.
      final buttonWidth = tester.getSize(find.text('Giriş Yap')).width;
      expect(buttonWidth, lessThan(600));
    });
  });
}
