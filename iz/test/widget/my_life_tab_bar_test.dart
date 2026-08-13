/// "Hayatım" ekranının hap biçimli sekme çubuğu.
///
/// FIGMA ÖLÇÜLERİ (390 genişlikte çerçeve):
///   çubuk → 350 × 40, left 20, dolgu (4, 8, 4, 8), köşe 999, kenarlık 1px
///   hap   → 28 yüksek, dolgu (6, 12, 6, 12)
///
/// ⚠️ ETİKET GENİŞLİKLERİ TASARIMDAN BÜYÜK — bilerek. Figma 10 punto diyordu;
/// ekranda hem küçük hem soluk kaldığı için 12'ye çıkardık (harf aralığı da
/// 1'den 0.5'e indi). "KOLEKSİYONLAR" bu yüzden 91 değil ~100 px.
/// Hapın 28'lik boyu değişmedi: iki puntonun satır yüksekliği de 16.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/my_life/presentation/my_life_layout.dart';
import 'package:iz/features/my_life/presentation/widgets/my_life_tab_bar.dart';

import '../helpers/real_fonts.dart';

/// Ölçülen "KOLEKSİYONLAR" etiket genişliği. Punto ya da harf aralığı
/// değişirse bu sayı da değişir ve aşağıdaki testler seni uyarır.
const _kCollectionsLabelWidth = 100.0;

Future<List<MyLifeTab>> pumpTabs(
  WidgetTester tester, {
  MyLifeTab selected = MyLifeTab.calendar,
  Size size = const Size(390, 844),
  bool dark = false,
}) async {
  final tapped = <MyLifeTab>[];
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
          child: MyLifeTabBar(selected: selected, onSelected: tapped.add),
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
    // Etiket genişlikleri tasarımla karşılaştırılıyor.
    await loadRealFonts();
  });

  testWidgets('üç sekme de görünür', (tester) async {
    await pumpTabs(tester);

    expect(find.text('TAKVİM'), findsOneWidget);
    expect(find.text('KOLEKSİYONLAR'), findsOneWidget);
    expect(find.text('SERİLERİM'), findsOneWidget);
  });

  testWidgets('çubuk Figma ölçüsünde', (tester) async {
    await pumpTabs(tester);

    final bar = tester.getRect(find.byType(MyLifeTabBar));
    expect(bar.height, MyLifeTabBar.kHeight);
    // 390 − 2 × 20 = 350.
    expect(bar.width - 2 * MyLifeLayout.pageInset, 350);

    // İlk hap: 20 (kenar) + 8 (çubuk dolgusu) + 12 (hap dolgusu) = 40.
    expect(tester.getRect(find.text('TAKVİM')).left, closeTo(41, 1.5));

    expect(
      tester.getRect(find.text('KOLEKSİYONLAR')).width,
      closeTo(_kCollectionsLabelWidth, 2),
    );
  });

  testWidgets('yalnızca seçili sekmenin zemini var', (tester) async {
    await pumpTabs(tester);

    final primary = AppTheme.light().colorScheme.primary;
    final fills = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .toList();

    // Referansta seçili olmayanlarda kutu yok, yalnızca yazı görünüyor.
    expect(fills.where((c) => c == primary), hasLength(1));
    expect(fills.where((c) => c == Colors.transparent), hasLength(2));
  });

  testWidgets('seçili sekmenin yazısı zeminle kontrast', (tester) async {
    await pumpTabs(tester);

    final scheme = AppTheme.light().colorScheme;
    expect(
      tester.widget<Text>(find.text('TAKVİM')).style!.color,
      scheme.onPrimary,
    );
    expect(
      tester.widget<Text>(find.text('KOLEKSİYONLAR')).style!.color,
      // Seçili OLMAYAN etiket Text-Primary: seçiliyi zaten dolu yeşil hap
      // belirtiyor, ayırt etme işini yazının solukluğuna yüklemiyoruz.
      scheme.onSurface,
    );
  });

  testWidgets('dokunulan sekme yukarı bildirilir', (tester) async {
    final tapped = await pumpTabs(tester);

    await tester.tap(find.text('SERİLERİM'));
    await tester.pump();

    // Widget seçimi KENDİ DEĞİŞTİRMEZ: durumu ekran tutuyor.
    expect(tapped, [MyLifeTab.series]);
    expect(find.text('SERİLERİM'), findsOneWidget);
  });

  testWidgets('seçim dışarıdan gelir', (tester) async {
    await pumpTabs(tester, selected: MyLifeTab.collections);

    final scheme = AppTheme.light().colorScheme;
    expect(
      tester.widget<Text>(find.text('KOLEKSİYONLAR')).style!.color,
      scheme.onPrimary,
    );
  });

  testWidgets('ekran okuyucuya seçili sekme bildirilir', (tester) async {
    await pumpTabs(tester);

    // NFR-032: görme engelli kullanıcı hangi sekmede olduğunu bilmeli.
    // `isSemantics` yalnızca belirtilen özellikleri kontrol eder.
    expect(
      tester.getSemantics(find.text('TAKVİM')),
      isSemantics(label: 'TAKVİM', isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(find.text('SERİLERİM')),
      isSemantics(isSelected: false),
    );
  });

  testWidgets('390 pxde üç sekme KAYMADAN sığar', (tester) async {
    // BU TESTİN SEBEBİ: punto büyüttük. Bir adım daha büyütmek etiketleri
    // tasarım genişliğinde sığmaz hâle getirir ve çubuk telefonda yatay
    // kaydırılabilir olur — gezinme çubuğunun kaydırılması kötü bir deneyim.
    // Sığma sınırını mekanik olarak bekliyoruz.
    await pumpTabs(tester);

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(
      scrollable.position.maxScrollExtent,
      0,
      reason: 'Etiketler 390 pxde sığmıyor; punto ya da harf aralığı fazla',
    );
  });

  testWidgets('320 pxde sığmaz ve KAYDIRILIR — kırpılmaz', (tester) async {
    // Küçük telefonda üç etiket zaten 10 puntoda da sığmıyordu. Kırpmak ya
    // da küçültmek yerine kaydırmaya izin veriyoruz (bkz. widget notu).
    await pumpTabs(tester, size: const Size(320, 844));

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0, 600.0]) {
    testWidgets('${width.toInt()} px genişlikte taşmaz', (tester) async {
      await pumpTabs(tester, size: Size(width, 844));
      expect(tester.takeException(), isNull);

      // Dar ekranda etiketler KIRPILMAZ; gerekirse çubuk yatay kayar.
      expect(find.text('KOLEKSİYONLAR'), findsOneWidget);
      expect(
        tester.getRect(find.text('KOLEKSİYONLAR')).width,
        closeTo(_kCollectionsLabelWidth, 2),
      );
    });
  }

  testWidgets('koyu temada da çizilir', (tester) async {
    await pumpTabs(tester, dark: true);
    expect(tester.takeException(), isNull);
    expect(find.text('TAKVİM'), findsOneWidget);
  });
}
