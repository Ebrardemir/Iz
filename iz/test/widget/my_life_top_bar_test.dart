/// "Hayatım" ekranının üst şeridi.
///
/// FIGMA ÖLÇÜLERİ (390 genişlikte çerçeve):
///   şerit    → 350 × 52, top 24, left 20, padding 4, gap 12
///   başlık   → Cormorant SemiBold 24/32, sol kenar 24 (20 + 4)
///   eylemler → her ikon 28, aralarında 24, sağ kenar 366 (20 + 350 − 4)
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/my_life/presentation/widgets/my_life_top_bar.dart';

import '../helpers/real_fonts.dart';

Future<({int search, int filter})> pumpBar(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool dark = false,
}) async {
  var search = 0;
  var filter = 0;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      locale: const Locale('tr'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: MyLifeTopBar(onSearch: () => search++, onFilter: () => filter++),
      ),
    ),
  );
  await tester.pump();
  return (search: search, filter: filter);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Başlık ölçüsü tasarımla karşılaştırılıyor; yedek fontla ölçüm sapar.
    await loadRealFonts();
  });

  testWidgets('başlık ve iki eylem görünür', (tester) async {
    await pumpBar(tester);

    expect(find.text('HAYATIM'), findsOneWidget);
    expect(find.byIcon(AppIcons.search), findsOneWidget);
    expect(find.byIcon(AppIcons.filter), findsOneWidget);
  });

  testWidgets('başlık Figma ölçüsünde', (tester) async {
    await pumpBar(tester);

    final title = tester.getRect(find.text('HAYATIM'));
    // 20 (şerit kenarı) + 4 (şeridin kendi dolgusu).
    expect(title.left, 24);
    // Poppins 26 → satır yüksekliği 34.
    //
    // Figma serif 24/32 söylüyordu; başlık sayfanın geri kalanıyla aynı sesle
    // konuşsun diye Poppins'e geçtik ve bir punto büyüdü
    // (bkz. `IzScreenHeader`).
    expect(title.height, 34);
  });

  testWidgets('ikonlar 28 px ve aralarında 24 var', (tester) async {
    await pumpBar(tester);

    final search = tester.getRect(find.byIcon(AppIcons.search));
    final filter = tester.getRect(find.byIcon(AppIcons.filter));

    expect(search.width, 28);
    expect(filter.width, 28);

    // REGRESYON: `IconButton` ikonun her yanına 10 px görünmez pay ekler.
    // Tasarımdaki 24'ü doğrudan koyunca ekranda 44 görünüyordu.
    expect(filter.left - search.right, closeTo(24, 0.5));
  });

  testWidgets('son ikonun görsel sağ kenarı 366', (tester) async {
    await pumpBar(tester);

    // Figma: eylem kutusu 20 + 350 − 4 = 366'da bitiyor. Görünmez pay
    // telafi edilmeseydi ikon 356'da kalırdı.
    expect(tester.getRect(find.byIcon(AppIcons.filter)).right, closeTo(366, 1));
  });

  testWidgets('eylemler dokunulabilir ve tanıtılmış', (tester) async {
    var search = 0;
    var filter = 0;
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: MyLifeTopBar(
            onSearch: () => search++,
            onFilter: () => filter++,
          ),
        ),
      ),
    );
    await tester.pump();

    // NFR-032 — 48×48 dokunma hedefi ve ekran okuyucu etiketi.
    for (final button in tester.widgetList<IconButton>(
      find.byType(IconButton),
    )) {
      expect(button.tooltip, isNotNull);
    }
    for (final rect in [
      tester.getRect(find.byType(IconButton).first),
      tester.getRect(find.byType(IconButton).last),
    ]) {
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(rect.height, greaterThanOrEqualTo(48));
    }

    await tester.tap(find.byIcon(AppIcons.search));
    await tester.tap(find.byIcon(AppIcons.filter));
    await tester.pump();
    expect(search, 1);
    expect(filter, 1);
  });

  for (final width in [320.0, 390.0, 430.0, 600.0]) {
    testWidgets('${width.toInt()} px genişlikte kenarlar korunur', (
      tester,
    ) async {
      await pumpBar(tester, size: Size(width, 844));
      expect(tester.takeException(), isNull);

      // Kenar boşluğu bir MARJDIR: her ekranda aynı.
      expect(tester.getRect(find.text('HAYATIM')).left, 24);
      expect(
        tester.getRect(find.byIcon(AppIcons.filter)).right,
        closeTo(width - 24, 1),
      );
    });
  }

  testWidgets('koyu temada da çizilir', (tester) async {
    await pumpBar(tester, dark: true);
    expect(tester.takeException(), isNull);
    expect(find.text('HAYATIM'), findsOneWidget);
  });
}
