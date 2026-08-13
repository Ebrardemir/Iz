/// "SON ANILAR" listesindeki anı satırı.
///
/// Ölçüler Figma'dan; referans ekran görüntüsüyle de karşılaştırıldı
/// (kart 350 × 68, küçük resim 64, yazı sol kenarı 104-106).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/home/presentation/widgets/memory_row_card.dart';

import '../helpers/real_fonts.dart';

const MemoryRowData _memory = (
  id: 'test-1',
  imageAsset: 'assets/images/home/memory_coffee.jpg',
  title: 'Kahve Molası',
  dateLabel: '3 gün önce',
);

Future<int> pumpCard(
  WidgetTester tester, {
  bool showDivider = true,
  Size size = const Size(390, 400),
}) async {
  var taps = 0;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('tr'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          // Figma: kart 350 geniş, ekranın iki yanından 20 içeride.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MemoryRowCard(
              memory: _memory,
              showDivider: showDivider,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return taps;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });

  testWidgets('başlık, tarih ve ok görünür', (tester) async {
    await pumpCard(tester);

    expect(find.text('Kahve Molası'), findsOneWidget);
    expect(find.text('3 gün önce'), findsOneWidget);
    expect(find.byIcon(AppIcons.forward), findsOneWidget);
  });

  testWidgets('Figma ölçüleri tutuyor', (tester) async {
    await pumpCard(tester);

    final card = tester.getRect(find.byType(MemoryRowCard));
    expect(card.width, 350);
    expect(card.height, MemoryRowCard.kHeight);

    // Küçük resim 64 × 64, kartın 8'lik dolgusuyla ekranda 28'de başlar.
    final thumb = tester.getRect(find.byType(Image));
    expect(thumb.width, MemoryRowCard.kThumbSize);
    expect(thumb.height, MemoryRowCard.kThumbSize);
    expect(thumb.left, 28);

    // Yazı: 28 + 64 + 12 = 104. Referans ölçümü 106.
    expect(tester.getRect(find.text('Kahve Molası')).left, 104);

    // Ok 28 px ve kartın sağ iç kenarında.
    expect(
      tester.widget<Icon>(find.byIcon(AppIcons.forward)).size,
      AppIconSize.lg,
    );
    expect(tester.getRect(find.byIcon(AppIcons.forward)).right, 362);
  });

  testWidgets('başlık ile tarih uçlara yaslı', (tester) async {
    await pumpCard(tester);

    // Figma: sağ kutu 60 yüksekliğinde, başlık 24, tarih 16 → arada ~20
    // nefes kalıyor. Alt alta yapışık dursalardı liste sıkışık görünürdü.
    final title = tester.getRect(find.text('Kahve Molası'));
    final date = tester.getRect(find.text('3 gün önce'));
    expect(date.top - title.bottom, closeTo(20, 3));
  });

  testWidgets('dokunma yukarı bildirilir', (tester) async {
    var taps = 0;
    tester.view
      ..physicalSize = const Size(390, 400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MemoryRowCard(memory: _memory, onTap: () => taps++),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(MemoryRowCard));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('son satırda alt çizgi yok', (tester) async {
    // Çizgi kartın DEĞİL, sağ kutunun altında; son satırda hiç olmamalı,
    // yoksa liste "yarım kalmış" görünür.
    await pumpCard(tester, showDivider: false);

    final decorated = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.border != null);
    for (final d in decorated) {
      expect((d.border! as Border).bottom.color, Colors.transparent);
    }
  });

  testWidgets('uzun başlık kırpılır, satır taşmaz', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: MemoryRowCard(
            memory: (
              id: 'test-2',
              imageAsset: 'assets/images/home/memory_coffee.jpg',
              title: 'Çok uzun bir anı başlığı — tek satıra asla sığmayacak',
              dateLabel: '3 gün önce',
            ),
            onTap: _noop,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final title = tester.widget<Text>(find.textContaining('Çok uzun bir anı'));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
  });
}

void _noop() {}
