/// Takvim ızgarası.
///
/// "Bugün" widget'a DIŞARIDAN veriliyor; testler bu sayede sabit bir güne
/// bakabiliyor. `DateTime.now()` kullansaydık vurgu testi her gün başka
/// sonuç verirdi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/my_life/presentation/my_life_layout.dart';
import 'package:iz/features/my_life/presentation/widgets/calendar_grid.dart';
import 'package:iz/features/my_life/presentation/widgets/calendar_week_header.dart';

import '../helpers/real_fonts.dart';

final _august2026 = DateTime(2026, 8);
final _today = DateTime(2026, 8, 12);

Future<List<DateTime>> pumpGrid(
  WidgetTester tester, {
  DateTime? month,
  DateTime? today,
  Map<DateTime, String> covers = const {},
  Size size = const Size(390, 900),
  bool dark = false,
  bool withHeader = false,
}) async {
  final tapped = <DateTime>[];
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
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (withHeader) const CalendarWeekHeader(),
            CalendarGrid(
              month: month ?? _august2026,
              today: today ?? _today,
              covers: covers,
              onDaySelected: tapped.add,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return tapped;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });

  testWidgets('ayın günleri doğru hafta gününde', (tester) async {
    await pumpGrid(tester, withHeader: true);

    // 1 Ağustos 2026 CUMARTESİ. Sütun merkezleri örtüşmeli.
    final one = tester.getRect(find.text('1').first).center.dx;
    final cmt = tester.getRect(find.text('CMT')).center.dx;
    expect(one, closeTo(cmt, 1));
  });

  testWidgets('başlıklarla günler AYNI sütunda', (tester) async {
    await pumpGrid(tester, withHeader: true);

    // Takvimin en kritik sözleşmesi. Kayarsa kullanıcı hata olarak okur.
    for (final (label, day) in [
      ('PZT', '3'),
      ('SAL', '4'),
      ('ÇAR', '5'),
      ('PER', '6'),
      ('CUM', '7'),
      ('CMT', '8'),
      ('PAZ', '9'),
    ]) {
      // `.first` ŞART: tek haneli sayılar ızgarada İKİ kez geçiyor
      // (ağustosun 3'ü ve son satırdaki eylülün 3'ü). İlki ağustosunki.
      expect(
        tester.getRect(find.text(day).first).center.dx,
        closeTo(tester.getRect(find.text(label)).center.dx, 1),
        reason: '$label sütunu kaymış',
      );
    }
  });

  testWidgets('BUGÜN yeşil daire içinde', (tester) async {
    await pumpGrid(tester);

    final primary = AppTheme.light().colorScheme.primary;
    final circles = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.shape == BoxShape.circle);

    // Tam BİR gün vurgulanmalı.
    expect(circles.where((d) => d.color == primary), hasLength(1));

    // Vurgulanan gün 12 olmalı: rakamın rengi zeminle kontrast.
    expect(
      tester.widget<Text>(find.text('12')).style!.color,
      AppTheme.light().colorScheme.onPrimary,
    );
  });

  testWidgets('bugün BAŞKA AY ise hiçbir gün vurgulanmaz', (tester) async {
    await pumpGrid(tester, today: DateTime(2026, 5, 3));

    final primary = AppTheme.light().colorScheme.primary;
    final highlighted = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.shape == BoxShape.circle && d.color == primary);

    expect(highlighted, isEmpty);
  });

  testWidgets('komşu ayın günleri SOLUK', (tester) async {
    await pumpGrid(tester);

    final scheme = AppTheme.light().colorScheme;
    // 27 Temmuz — ızgaranın ilk hücresi, ağustosa ait değil.
    expect(
      tester.widget<Text>(find.text('27').first).style!.color,
      scheme.onSurfaceVariant,
    );
    // 3 Ağustos — ayın kendi günü.
    expect(
      tester.widget<Text>(find.text('3').first).style!.color,
      scheme.onSurface,
    );
  });

  testWidgets('anısı olan günde kapak görünür', (tester) async {
    await pumpGrid(
      tester,
      covers: {DateTime(2026, 8, 6): 'assets/images/home/memory_coffee.jpg'},
    );

    expect(find.byType(Image), findsOneWidget);
    final cover = tester.getRect(find.byType(Image));
    // FIGMA: 24 × 20.
    expect(cover.width, CalendarGrid.kCoverWidth);
    expect(cover.height, CalendarGrid.kCoverHeight);
  });

  testWidgets('bugün + anı bir arada TAŞMAZ', (tester) async {
    // REGRESYON: daire 32 iken 32 + 20 = 52 > 48 ve hücre taşıyordu.
    await pumpGrid(
      tester,
      covers: {_today: 'assets/images/home/memory_coffee.jpg'},
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('dokunulan gün yukarı bildirilir', (tester) async {
    final tapped = await pumpGrid(tester);

    await tester.tap(find.text('19'));
    await tester.pump();

    expect(tapped, hasLength(1));
    expect(tapped.single, DateTime(2026, 8, 19));
  });

  testWidgets('ekran okuyucuya seçili gün bildirilir', (tester) async {
    await pumpGrid(tester);

    expect(
      tester.getSemantics(find.text('12')),
      isSemantics(isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(find.text('19')),
      isSemantics(isSelected: false),
    );
  });

  testWidgets('ızgara Figma yüksekliğinde (6 hafta)', (tester) async {
    await pumpGrid(tester);

    // 6 hafta × (48 hücre + 8 boşluk) − son boşluk = 328.
    // Tasarımın 336'sı son satırın altındaki boşluğu da sayıyor.
    final grid = tester.getRect(find.byType(CalendarGrid));
    const expected = 6 * CalendarGrid.kCellHeight + 5 * CalendarGrid.kRowGap;
    expect(grid.height, expected);
  });

  for (final width in [320.0, 390.0, 430.0, 600.0]) {
    testWidgets('${width.toInt()} px genişlikte sütunlar eşit', (tester) async {
      await pumpGrid(tester, size: Size(width, 900));
      expect(tester.takeException(), isNull);

      final expected =
          (width - 2 * MyLifeLayout.pageInset) / MyLifeLayout.weekdayCount;
      final first = tester.getRect(find.text('3').first).center.dx;
      final second = tester.getRect(find.text('4').first).center.dx;
      expect(second - first, closeTo(expected, 1));
    });
  }

  testWidgets('koyu temada da çizilir', (tester) async {
    await pumpGrid(tester, dark: true);
    expect(tester.takeException(), isNull);
    expect(find.text('12'), findsOneWidget);
  });
}
