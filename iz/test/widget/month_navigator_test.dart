/// Takvimin üstündeki ay gezinme satırı.
///
/// FIGMA ÖLÇÜLERİ (390 genişlikte çerçeve):
///   satır → 350 × 40 (gerçekte 48, bkz. widget notu), left 20, dolgu 8
///   oklar → 32 × 32, görsel kenarları 28 ve 362
///   ay adı→ Poppins SemiBold 20/16, genişlik 149, tam ortada
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/my_life/presentation/widgets/month_navigator.dart';

import '../helpers/real_fonts.dart';

/// Tasarımdaki ay. Testin `DateTime.now()`a bağlanmaması ŞART: yoksa
/// ağustos bitince test kendiliğinden kırılırdı.
final _august2026 = DateTime(2026, 8);

Future<({int previous, int next})> pumpNavigator(
  WidgetTester tester, {
  DateTime? month,
  Locale locale = const Locale('tr'),
  Size size = const Size(390, 844),
  bool dark = false,
}) async {
  var previous = 0;
  var next = 0;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: MonthNavigator(
            month: month ?? _august2026,
            onPrevious: () => previous++,
            onNext: () => next++,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (previous: previous, next: next);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });

  testWidgets('ay adı ve iki ok görünür', (tester) async {
    await pumpNavigator(tester);

    expect(find.text('AĞUSTOS 2026'), findsOneWidget);
    expect(find.byIcon(AppIcons.back), findsOneWidget);
    expect(find.byIcon(AppIcons.forward), findsOneWidget);
  });

  testWidgets('ay adı TÜRKÇE kurala göre büyük harf', (tester) async {
    // REGRESYON: Dart'ın `toUpperCase()` metodu dili bilmez ve Türkçedeki
    // noktalı `i` harfini `I` yapar. Nisan ayı bunu açığa çıkarır.
    await pumpNavigator(tester, month: DateTime(2026, 4));

    expect(find.text('NİSAN 2026'), findsOneWidget);
    expect(find.text('NISAN 2026'), findsNothing);
  });

  testWidgets('ay adı uygulamanın dilinden geliyor', (tester) async {
    // REGRESYON: biçimleyiciye dil verilmezse `Intl.defaultLocale` genel
    // değişkenine düşüyor ve ay adı İngilizce çıkıyordu.
    await pumpNavigator(tester, locale: const Locale('en'));

    expect(find.text('AUGUST 2026'), findsOneWidget);
  });

  testWidgets('Figma ölçüleri tutuyor', (tester) async {
    await pumpNavigator(tester);

    final row = tester.getRect(find.byType(MonthNavigator));
    expect(row.height, MonthNavigator.kHeight);

    // Okların GÖRSEL kenarları: 20 (satır kenarı) + 8 (dolgu) = 28,
    // sağda 370 − 8 = 362.
    expect(tester.getRect(find.byIcon(AppIcons.back)).left, 28);
    expect(tester.getRect(find.byIcon(AppIcons.forward)).right, 362);
    expect(tester.getRect(find.byIcon(AppIcons.back)).width, 32);

    final label = tester.getRect(find.text('AĞUSTOS 2026'));
    // FIGMA: 149 × 16.
    expect(label.width, closeTo(149, 2));
    expect(label.height, 16);
  });

  testWidgets('ay adı okların uzunluğundan bağımsız ORTADA', (tester) async {
    await pumpNavigator(tester);

    final row = tester.getRect(find.byType(MonthNavigator));
    final label = tester.getRect(find.text('AĞUSTOS 2026'));
    expect(label.center.dx, closeTo(row.center.dx, 1));
  });

  testWidgets('oklar yön bildirir ve tanıtılmış', (tester) async {
    var previous = 0;
    var next = 0;
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
          body: MonthNavigator(
            month: _august2026,
            onPrevious: () => previous++,
            onNext: () => next++,
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
    for (final icon in [AppIcons.back, AppIcons.forward]) {
      final box = tester.getRect(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton)),
      );
      expect(box.width, greaterThanOrEqualTo(48));
      expect(box.height, greaterThanOrEqualTo(48));
    }

    await tester.tap(find.byIcon(AppIcons.back));
    await tester.tap(find.byIcon(AppIcons.forward));
    await tester.pump();
    expect(previous, 1);
    expect(next, 1);
  });

  for (final width in [320.0, 390.0, 430.0, 600.0]) {
    testWidgets('${width.toInt()} px genişlikte kenarlar korunur', (
      tester,
    ) async {
      await pumpNavigator(tester, size: Size(width, 844));
      expect(tester.takeException(), isNull);

      expect(tester.getRect(find.byIcon(AppIcons.back)).left, 28);
      expect(tester.getRect(find.byIcon(AppIcons.forward)).right, width - 28);
    });
  }

  testWidgets('koyu temada da çizilir', (tester) async {
    await pumpNavigator(tester, dark: true);
    expect(tester.takeException(), isNull);
    expect(find.text('AĞUSTOS 2026'), findsOneWidget);
  });
}
