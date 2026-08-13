/// Takvimin altındaki "seçili günün anıları" paneli.
///
/// Seçili gün ve anı listesi widget'a DIŞARIDAN veriliyor; testler bu sayede
/// sabit bir güne bakabiliyor. `DateTime.now()` kullansaydık tarih başlığı
/// testi her gün başka sonuç verirdi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/my_life/presentation/widgets/day_memories_panel.dart';
import 'package:iz/features/my_life/presentation/widgets/day_memory_card.dart';

import '../helpers/real_fonts.dart';

final _day = DateTime(2026, 8, 15);

const _oneMemory = <DayMemoryData>[
  (
    id: 'test-1',
    imageAsset: 'assets/images/home/memory_coffee.jpg',
    title: 'Kahve Molası',
    dateLabel: '15 Ağustos 2026',
    categoryLabel: 'Günlük',
  ),
];

const _twoMemories = <DayMemoryData>[
  ..._oneMemory,
  (
    id: 'test-2',
    imageAsset: 'assets/images/home/hero_today.jpg',
    title: 'Sahilde Sabah',
    dateLabel: '15 Ağustos 2026',
    categoryLabel: 'Seyahat',
  ),
];

/// Panel tek başına kuruluyor: `ProviderScope` yok, router yok. Saf widget
/// olmasının getirisi bu.
Future<List<DayMemoryData>> pumpPanel(
  WidgetTester tester, {
  List<DayMemoryData> memories = const [],
  VoidCallback? onAddMemory,
  Size size = const Size(390, 900),
  bool dark = false,
}) async {
  final opened = <DayMemoryData>[];

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
        // Gerçek ekranda da kaydırılabilir bir sütunun içinde duruyor;
        // panel yüksekliğini kendi içeriğinden alıyor.
        body: SingleChildScrollView(
          child: DayMemoriesPanel(
            day: _day,
            memories: memories,
            onOpenMemory: opened.add,
            onAddMemory: onAddMemory ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return opened;
}

void main() {
  setUpAll(loadRealFonts);

  group('başlık', () {
    testWidgets('seçili günün tarihini gösterir', (tester) async {
      await pumpPanel(tester, memories: _twoMemories);

      // Tarih ÇEVİRİDEN DEĞİL `intl`den geliyor; dil açıkça 'tr'.
      expect(find.text('15 Ağustos 2026'), findsWidgets);
    });

    testWidgets('anı sayısını çoğul kuralına göre yazar', (tester) async {
      await pumpPanel(tester, memories: _twoMemories);
      expect(find.text('2 anı'), findsOneWidget);

      await pumpPanel(tester, memories: _oneMemory);
      expect(find.text('1 anı'), findsOneWidget);
    });

    testWidgets('anı yokken sayaç "Anı yok" der', (tester) async {
      await pumpPanel(tester);
      expect(find.text('Anı yok'), findsOneWidget);
    });
  });

  group('boş durum', () {
    testWidgets('anı yokken davet gösterilir, kart gösterilmez', (
      tester,
    ) async {
      await pumpPanel(tester);

      expect(find.byType(DayMemoryCard), findsNothing);
      expect(find.text('Bu güne henüz iz düşmedi'), findsOneWidget);
      expect(find.text('Bu güne bir iz bırak'), findsOneWidget);
    });

    testWidgets('davete dokunmak eylemi tetikler', (tester) async {
      var added = 0;
      await pumpPanel(tester, onAddMemory: () => added++);

      await tester.tap(find.text('Bu güne bir iz bırak'));
      await tester.pump();

      expect(added, 1);
    });

    testWidgets('boş panel tasarımdaki 222 yüksekliğinde kalır', (
      tester,
    ) async {
      await pumpPanel(tester);

      // Tasarımın ayırdığı alan: takvimden sonra kalan boşluk. Boş durum
      // burayı doldurmalı, panel büzüşmemeli.
      expect(
        tester.getSize(find.byType(DayMemoriesPanel)).height,
        DayMemoriesPanel.kMinHeight,
      );
    });
  });

  group('anı listesi', () {
    testWidgets('her anı için bir kart çizilir', (tester) async {
      await pumpPanel(tester, memories: _twoMemories);

      expect(find.byType(DayMemoryCard), findsNWidgets(2));
      expect(find.text('Kahve Molası'), findsOneWidget);
      expect(find.text('Sahilde Sabah'), findsOneWidget);
    });

    testWidgets('kart "tarih • kategori" satırını gösterir', (tester) async {
      await pumpPanel(tester, memories: _oneMemory);

      expect(find.text('15 Ağustos 2026 • Günlük'), findsOneWidget);
    });

    testWidgets('karta dokunmak o anıyı bildirir', (tester) async {
      final opened = await pumpPanel(tester, memories: _twoMemories);

      await tester.tap(find.text('Sahilde Sabah'));
      await tester.pump();

      expect(opened.single.title, 'Sahilde Sabah');
    });

    testWidgets('iki kart tam olarak tasarımdaki 222\'yi doldurur', (
      tester,
    ) async {
      await pumpPanel(tester, memories: _twoMemories);

      // Tasarım iki kart üzerine kurulu: 8 + 24 + 10 + (81+10+81) + 8 = 222.
      // Bu sayı kayarsa ya kart yüksekliği ya panel dolgusu bozulmuş.
      expect(
        tester.getSize(find.byType(DayMemoriesPanel)).height,
        DayMemoriesPanel.kMinHeight,
      );
    });

    testWidgets('tek anı varken panel yine 222 kalır', (tester) async {
      await pumpPanel(tester, memories: _oneMemory);

      // Asgari yükseklik olmasa panel 131'e büzüşür ve alt çubukla arasında
      // boş bir şerit kalırdı.
      expect(
        tester.getSize(find.byType(DayMemoriesPanel)).height,
        DayMemoriesPanel.kMinHeight,
      );
    });

    testWidgets('üç anı varken panel BÜYÜR — taşma olmaz', (tester) async {
      const three = <DayMemoryData>[
        ..._twoMemories,
        (
          id: 'test-3',
          imageAsset: 'assets/images/auth/hero_light.jpg',
          title: 'Meydandaki Kahve',
          dateLabel: '15 Ağustos 2026',
          categoryLabel: 'İlişkiler',
        ),
      ];

      await pumpPanel(tester, memories: three);

      expect(find.byType(DayMemoryCard), findsNWidgets(3));
      expect(
        tester.getSize(find.byType(DayMemoriesPanel)).height,
        greaterThan(DayMemoriesPanel.kMinHeight),
      );
      // Sabit 222 verseydik üçüncü kart taşardı; `takeException` boş olmalı.
      expect(tester.takeException(), isNull);
    });
  });

  group('kart ölçüleri', () {
    testWidgets('kart tasarımdaki 81 yüksekliğinde', (tester) async {
      await pumpPanel(tester, memories: _oneMemory);

      expect(
        tester.getSize(find.byType(DayMemoryCard).first).height,
        DayMemoryCard.kHeight,
      );
    });

    testWidgets('kart sayfa marjından 10 daha içeride (30)', (tester) async {
      await pumpPanel(tester, memories: _oneMemory);

      // Figma: kart 330 genişlikte, 390'lık çerçevede left 30.
      final rect = tester.getRect(find.byType(DayMemoryCard).first);
      expect(rect.left, 30);
      expect(rect.width, 330);
    });

    testWidgets('kapak tasarımdaki 86 × 64', (tester) async {
      await pumpPanel(tester, memories: _oneMemory);

      expect(
        tester.getSize(find.byType(Image).first),
        const Size(DayMemoryCard.kCoverWidth, DayMemoryCard.kCoverHeight),
      );
    });

    testWidgets('alt çizgi 1px ve Brand-Default renginde', (tester) async {
      // BU TESTİN SEBEBİ: açık temada kart rengi panelin rengiyle AYNI
      // (#FAF8F3). Yani kartı ötekinden ayıran tek şey bu hairline. Sessizce
      // kaybolsa (yuvarlatılmış köşe onu kırpsa, `Expanded` yerini yese)
      // ekranda fark etmek zor olurdu — kartlar tek bir bloğa yapışırdı.
      await pumpPanel(tester, memories: _oneMemory);

      final expected = AppTheme.light().colorScheme.outlineVariant;
      final rule = find.descendant(
        of: find.byType(DayMemoryCard),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == expected,
        ),
      );

      expect(rule, findsOneWidget);
      expect(tester.getSize(rule).height, 1);
      // Köşe kırpması yüzünden çizgi kartın tam genişliği kadar görünmez ama
      // kutunun kendisi tam genişlikte olmalı.
      expect(tester.getSize(rule).width, 330);
    });
  });

  testWidgets('koyu temada da taşma/hata olmadan çizilir', (tester) async {
    await pumpPanel(tester, memories: _twoMemories, dark: true);
    expect(tester.takeException(), isNull);

    await pumpPanel(tester, dark: true);
    expect(tester.takeException(), isNull);
  });
}
