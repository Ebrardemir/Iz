/// Ana sayfadaki 2×2 sayaç ızgarası.
///
/// Ölçüler referans ekran görüntüsünden PİKSEL PİKSEL çıkarıldı; Figma
/// katmanının kendi içinde tutarsız olduğu yerlerde (hücre 179 × 2 = 358,
/// kapsayıcı 350) ölçüm esas alındı. Testler o kararları sabitliyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/home/presentation/home_layout.dart';
import 'package:iz/features/home/presentation/widgets/home_stats_grid.dart';

import '../helpers/app_harness.dart';
import '../helpers/real_fonts.dart';

/// Dokunuşları kaydeden defter — hangi sayaca basıldığını doğrulamak için.
final List<String> tapped = [];

List<HomeStat> statsFor({bool tappable = true}) => [
  (
    icon: AppIcons.navJournal,
    label: 'GÜNLÜK',
    value: '128',
    unit: 'kayıt',
    onTap: tappable ? () => tapped.add('GÜNLÜK') : null,
  ),
  (
    icon: AppIcons.people,
    label: 'KİŞİLER',
    value: '7',
    unit: 'kişi',
    onTap: tappable ? () => tapped.add('KİŞİLER') : null,
  ),
  (
    icon: AppIcons.series,
    label: 'SERİLER',
    value: '3',
    unit: 'seri',
    onTap: tappable ? () => tapped.add('SERİLER') : null,
  ),
  (
    icon: AppIcons.collection,
    label: 'KOLEKSİYONLAR',
    value: '5',
    unit: 'koleksiyon',
    onTap: tappable ? () => tapped.add('KOLEKSİYONLAR') : null,
  ),
];

Future<void> pumpGrid(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool dark = false,
  bool tappable = true,
}) async {
  tapped.clear();
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
        body: Align(
          alignment: Alignment.topCenter,
          child: HomeStatsGrid(stats: statsFor(tappable: tappable)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Ölçüler tasarımla karşılaştırılıyor; yedek fontla ölçüm sapar.
    await loadRealFonts();
  });

  testWidgets('dört sayaç da görünür', (tester) async {
    await pumpGrid(tester);

    for (final text in [
      'GÜNLÜK',
      '128',
      'kayıt',
      'KİŞİLER',
      '7',
      'kişi',
      'SERİLER',
      '3',
      'seri',
      'KOLEKSİYONLAR',
      '5',
      'koleksiyon',
    ]) {
      expect(find.text(text), findsOneWidget, reason: '"$text" eksik');
    }
  });

  testWidgets('en uzun etiket KIRPILMAZ', (tester) async {
    await pumpGrid(tester);

    // REGRESYON: Figma'nın sağ dolgusu (16) bizim çizimimizde
    // "KOLEKSİYONLAR"a yetmiyor ve etiket "KOLEKSİYONL…" oluyordu.
    final box = tester.renderObject<RenderBox>(find.text('KOLEKSİYONLAR'));
    final natural = box.getMaxIntrinsicWidth(double.infinity);
    expect(box.size.width, greaterThanOrEqualTo(natural));
  });

  testWidgets('metin sütunu tasarımdaki yerde', (tester) async {
    await pumpGrid(tester);

    // Figma ölçümü: metin sol kenarı 89 ≈ 20 (ızgara) + 20 (dolgu)
    // + 32 (ikon) + 16 (ikon–yazı arası) = 88.
    expect(tester.getRect(find.text('GÜNLÜK')).left, closeTo(88, 1));

    // Sağ sütun: sol sütun + hücre genişliği (350 / 2 = 175).
    expect(tester.getRect(find.text('KİŞİLER')).left, closeTo(88 + 175, 2));
  });

  testWidgets('iki sütun EŞİT genişlikte', (tester) async {
    await pumpGrid(tester);

    // Figma hücreyi 179 diyor ama 2 × 179 = 358 > 350. Referans ölçümünde
    // dikey ayırıcı tam ortada (x = 194), yani sütunlar eşit.
    final left = tester.getRect(find.text('GÜNLÜK')).left;
    final right = tester.getRect(find.text('KİŞİLER')).left;
    // Izgaranın KUTUSU kenar boşluklarını da içeriyor; sütun genişliği
    // içerideki alanın yarısı.
    final grid = tester.getRect(find.byType(HomeStatsGrid));
    final columnWidth = (grid.width - 2 * HomeLayout.pageInset) / 2;
    expect(right - left, closeTo(columnWidth, 2));
  });

  testWidgets('satırlar ve sütunlar ayırıcıyla bölünmüş', (tester) async {
    await pumpGrid(tester);

    // İki satır arasında 1 yatay, her satırda 1 dikey ayırıcı.
    expect(find.byType(Divider), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNWidgets(2));
  });

  testWidgets('ikonlar altın vurgu renginde ve 32 px', (tester) async {
    await pumpGrid(tester);

    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons, hasLength(4));
    final gold = AppTheme.light().colorScheme.tertiary;
    for (final icon in icons) {
      expect(icon.size, 32);
      expect(icon.color, gold);
    }
  });

  testWidgets('sayı, etiket ve birim ayrı ölçülerde', (tester) async {
    await pumpGrid(tester);

    double sizeOf(String text) =>
        tester.widget<Text>(find.text(text)).style!.fontSize!;

    // FIGMA: etiket 12, sayı 20, birim 12.
    expect(sizeOf('GÜNLÜK'), 12);
    expect(sizeOf('128'), 20);
    expect(sizeOf('kayıt'), 12);
  });

  for (final size in const [
    Size(320, 568), // en küçük telefon
    Size(390, 844),
    Size(430, 932),
    Size(600, 1024), // tablet
  ]) {
    testWidgets('${size.width.toInt()} px genişlikte taşmaz', (tester) async {
      await pumpGrid(tester, size: size);
      expect(tester.takeException(), isNull);

      // Kenar boşluğu bir MARJDIR: her ekranda 20 px.
      expect(tester.getRect(find.text('GÜNLÜK')).left, closeTo(88, 1));
      expect(find.text('KOLEKSİYONLAR'), findsOneWidget);
    });
  }

  testWidgets('koyu temada da çizilir', (tester) async {
    await pumpGrid(tester, dark: true);
    expect(tester.takeException(), isNull);
    expect(find.byType(HomeStatsGrid), findsOneWidget);
  });

  group('dokunma', () {
    testWidgets('KİŞİLER sayacına dokunmak o bölümü açıyor', (tester) async {
      // Sayaç bir ÖZET: arkasında bir bölüm var ve dokununca oraya gidiyor.
      await pumpGrid(tester);

      await tester.tap(find.text('KİŞİLER'));
      await settle(tester);

      expect(tapped, ['KİŞİLER']);
    });

    testWidgets('her hücre KENDİ sayacını bildiriyor', (tester) async {
      // Hepsi aynı geri çağırmaya bağlansa bu test de geçerdi; dördünü tek
      // tek deniyoruz.
      await pumpGrid(tester);

      for (final label in ['GÜNLÜK', 'KİŞİLER', 'SERİLER', 'KOLEKSİYONLAR']) {
        await tester.tap(find.text(label));
        await settle(tester);
      }

      expect(tapped, ['GÜNLÜK', 'KİŞİLER', 'SERİLER', 'KOLEKSİYONLAR']);
    });

    testWidgets('hedefi olmayan hücre dokunulamaz', (tester) async {
      // `onTap` null geldiğinde hücre sessizce dokunulamaz kalıyor —
      // dokunulup hiçbir şey olmayan bir hücreden iyi.
      await pumpGrid(tester, tappable: false);

      expect(find.byType(InkWell), findsNothing);

      await tester.tap(find.text('KİŞİLER'));
      await settle(tester);
      expect(tapped, isEmpty);
    });
  });
}
