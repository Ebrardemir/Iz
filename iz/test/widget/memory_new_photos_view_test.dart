/// Yeni anı akışının ilk adımı — fotoğraf seçimi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/entitlement/entitlement.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/media/media_picker.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/memories/presentation/views/memory_new_photos_view.dart';
import 'package:iz/features/memories/presentation/widgets/photo_prompt_illustration.dart';

import '../helpers/fake_media_picker.dart';
import '../helpers/real_fonts.dart';

Future<void> pumpView(
  WidgetTester tester, {
  IzPlan plan = IzPlan.free,
  Size size = const Size(390, 844),
  bool dark = false,
  FakeMediaPicker? picker,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentPlanProvider.overrideWithValue(plan),
        mediaPickerProvider.overrideWithValue(picker ?? FakeMediaPicker()),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const MemoryNewPhotosView(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('tasarımdaki bütün parçalar ekranda', (tester) async {
    await pumpView(tester);

    // AppBar: çarpı + ortalı başlık.
    expect(find.text('Yeni Anı'), findsOneWidget);
    expect(find.byIcon(AppIcons.clear), findsOneWidget);

    expect(find.byType(PhotoPromptIllustration), findsOneWidget);
    expect(find.text('Bu anıdan geriye hangi kareler kalsın?'), findsOneWidget);
    expect(find.text('Galeriden Fotoğraf Seç'), findsOneWidget);
  });

  testWidgets('başlık ORTALI', (tester) async {
    // Uygulamanın genel `appBarTheme`ı sola yaslıyor; bu ekran ortalıyor.
    await pumpView(tester);

    final title = tester.getCenter(find.text('Yeni Anı'));
    expect(title.dx, closeTo(390 / 2, 1));
  });

  testWidgets('geri oku DEĞİL çarpı gösteriliyor', (tester) async {
    // Bu bir akışın ilk adımı: öncesi yok, dolayısıyla "geri" de yok.
    await pumpView(tester);

    expect(find.byIcon(AppIcons.clear), findsOneWidget);
    expect(find.byIcon(AppIcons.back), findsNothing);
  });

  group('fotoğraf limiti', () {
    testWidgets('ücretsiz planda 3 yazıyor', (tester) async {
      await pumpView(tester);
      expect(find.text('En fazla 3 fotoğraf seçebilirsin.'), findsOneWidget);
    });

    testWidgets('İZ+ planında 30 yazıyor — sayı SABİT DEĞİL', (tester) async {
      // BU TESTİN SEBEBİ: ekrana "3" yazmak kolaydı ama plan değiştiğinde
      // yalan söyleyen bir metin bırakırdı. Sayı entitlement matrisinden
      // geliyor (FR-041 / NFR-043).
      await pumpView(tester, plan: IzPlan.plus);
      expect(find.text('En fazla 30 fotoğraf seçebilirsin.'), findsOneWidget);
      expect(find.text('En fazla 3 fotoğraf seçebilirsin.'), findsNothing);
    });
  });

  group('galeri düğmesi', () {
    testWidgets('dokunma hedefi en az 48 (NFR-033)', (tester) async {
      await pumpView(tester);

      final button = find.widgetWithText(
        FilledButton,
        'Galeriden Fotoğraf Seç',
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    });

    testWidgets('seçiciye PLANIN limiti geçiliyor', (tester) async {
      // Seçicinin kendisi limiti uyguluyor: kullanıcıya 10 fotoğraf
      // seçtirip sonra "en fazla 3" demek kötü bir deneyim olurdu.
      final picker = FakeMediaPicker();
      await pumpView(tester, picker: picker);

      await tester.tap(find.text('Galeriden Fotoğraf Seç'));
      await tester.pump();

      expect(picker.receivedLimits, [3]);
    });

    testWidgets('İZ+ planında seçiciye 30 geçiliyor', (tester) async {
      final picker = FakeMediaPicker();
      await pumpView(tester, plan: IzPlan.plus, picker: picker);

      await tester.tap(find.text('Galeriden Fotoğraf Seç'));
      await tester.pump();

      expect(picker.receivedLimits, [30]);
    });

    testWidgets('vazgeçilirse sayfada kalınır, bildirim çıkmaz', (
      tester,
    ) async {
      // Boş seçim bir HATA DEĞİL, bir karar. Kullanıcıyı uyarmıyoruz.
      await pumpView(tester, picker: FakeMediaPicker());

      await tester.tap(find.text('Galeriden Fotoğraf Seç'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Galeriden Fotoğraf Seç'), findsOneWidget);
    });

    testWidgets('izin reddedilirse localize bildirim çıkar', (tester) async {
      await pumpView(
        tester,
        picker: FakeMediaPicker(
          failure: const PermissionFailure(permission: 'photos'),
        ),
      );

      await tester.tap(find.text('Galeriden Fotoğraf Seç'));
      await tester.pumpAndSettle();

      // Ham hata metni değil, çeviriden gelen kullanıcı metni.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('izin', findRichText: true), findsWidgets);
    });
  });

  group('düzen', () {
    testWidgets('başlık ve düğme AYNI genişliği paylaşıyor', (tester) async {
      // Referans tasarımda ikisi ortalanmış tek bir sütun gibi okunuyor.
      await pumpView(tester);

      final button = tester.getRect(
        find.widgetWithText(FilledButton, 'Galeriden Fotoğraf Seç'),
      );
      expect(button.width, closeTo(MemoryNewPhotosView.kContentWidth, 1));
      expect(button.center.dx, closeTo(390 / 2, 1));
    });

    for (final size in const [
      Size(320, 568), // en küçük telefon
      Size(390, 844),
      Size(430, 932),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} taşma yok', (
        tester,
      ) async {
        await pumpView(tester, size: size);
        expect(tester.takeException(), isNull);
        expect(find.text('Galeriden Fotoğraf Seç'), findsOneWidget);
      });
    }
  });

  testWidgets('koyu temada hata/taşma olmaz', (tester) async {
    // İllüstrasyonun bütün renkleri temadan geliyor; asset olsaydı krem
    // kareler koyu temada parlardı.
    await pumpView(tester, dark: true);

    expect(tester.takeException(), isNull);
    expect(find.byType(PhotoPromptIllustration), findsOneWidget);
  });
}
