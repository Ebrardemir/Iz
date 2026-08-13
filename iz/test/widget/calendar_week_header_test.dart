/// Takvimin gün başlığı satırı.
///
/// EN ÖNEMLİ SÖZLEŞME: sütun merkezleri EŞİT aralıklı olmalı. Takvim
/// ızgarası da aynı bölmeyi kullanacak; başlıklar günlerden kayarsa
/// kullanıcı bunu hata olarak okur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/my_life/presentation/my_life_layout.dart';
import 'package:iz/features/my_life/presentation/widgets/calendar_week_header.dart';

import '../helpers/real_fonts.dart';

Future<void> pumpHeader(
  WidgetTester tester, {
  Locale locale = const Locale('tr'),
  Size size = const Size(390, 844),
  bool dark = false,
}) async {
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
      home: const Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: CalendarWeekHeader(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });

  testWidgets('yedi gün, PAZARTESİDEN başlayarak', (tester) async {
    await pumpHeader(tester);

    // Tasarım pazartesiyle başlıyor; Türkiye ve Avrupa'nın kuralı bu.
    for (final label in ['PZT', 'SAL', 'ÇAR', 'PER', 'CUM', 'CMT', 'PAZ']) {
      expect(find.text(label), findsOneWidget, reason: '"$label" eksik');
    }
  });

  testWidgets('gün adları uygulamanın dilinden geliyor', (tester) async {
    await pumpHeader(tester, locale: const Locale('en'));

    // Çeviri dosyasına yedi anahtar eklemiyoruz: adlar `intl`den geliyor,
    // yeni bir dil eklenince kendiliğinden doğru olur.
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('SUN'), findsOneWidget);
    expect(find.text('PZT'), findsNothing);
  });

  testWidgets('sütunlar EŞİT aralıklı', (tester) async {
    await pumpHeader(tester);

    final centers = [
      for (final label in ['PZT', 'SAL', 'ÇAR', 'PER', 'CUM', 'CMT', 'PAZ'])
        tester.getRect(find.text(label)).center.dx,
    ];

    // 390 − 2 × 20 = 350; yedi sütun → 50. İlk merkez 20 + 25 = 45.
    expect(centers.first, closeTo(45, 1));
    for (var i = 1; i < centers.length; i++) {
      expect(
        centers[i] - centers[i - 1],
        closeTo(50, 1),
        reason: '$i. sütun kaymış',
      );
    }
  });

  testWidgets('satır Figma yüksekliğinde', (tester) async {
    await pumpHeader(tester);

    expect(
      tester.getRect(find.byType(CalendarWeekHeader)).height,
      CalendarWeekHeader.kHeight,
    );
    // FIGMA: Poppins Regular 14/20.
    final style = tester.widget<Text>(find.text('PZT')).style!;
    expect(style.fontSize, 14);
    expect(style.color, AppTheme.light().colorScheme.onSurfaceVariant);
  });

  test('etiketler haftanın ilk gününden başlar', () {
    // Widget kurmadan da doğrulanabilir: saf bir dönüşüm.
    final labels = CalendarWeekHeader.labelsFor(const Locale('tr'));
    expect(labels, hasLength(MyLifeLayout.weekdayCount));
    expect(labels.first, 'PZT');
    expect(labels.last, 'PAZ');
  });

  for (final width in [320.0, 390.0, 430.0, 600.0]) {
    testWidgets('${width.toInt()} px genişlikte sütunlar eşit kalır', (
      tester,
    ) async {
      await pumpHeader(tester, size: Size(width, 844));
      expect(tester.takeException(), isNull);

      final expected =
          (width - 2 * MyLifeLayout.pageInset) / MyLifeLayout.weekdayCount;
      final first = tester.getRect(find.text('PZT')).center.dx;
      final second = tester.getRect(find.text('SAL')).center.dx;
      expect(second - first, closeTo(expected, 1));
    });
  }

  testWidgets('koyu temada da çizilir', (tester) async {
    await pumpHeader(tester, dark: true);
    expect(tester.takeException(), isNull);
    expect(find.text('PZT'), findsOneWidget);
  });
}
