/// Alt gezinme çubuğu testi.
///
/// `IzBottomNav` saf bir widget: router'a ve Riverpod'a bağlı değil, bu yüzden
/// hiçbir altyapı kurmadan test edilebiliyor. Saf widget yazmanın somut
/// getirisi budur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';

const _destinations = <IzNavDestination>[
  (icon: AppIcons.navHome, label: 'Ana Sayfa'),
  (icon: AppIcons.navMyLife, label: 'Hayatım'),
  (icon: AppIcons.navStore, label: 'Mağaza'),
  (icon: AppIcons.navProfile, label: 'Profilim'),
];

Future<void> _pump(
  WidgetTester tester, {
  int currentIndex = 0,
  ThemeData? theme,
  Size size = const Size(390, 844),
  void Function(int)? onSelect,
  VoidCallback? onAdd,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Scaffold(
        bottomNavigationBar: IzBottomNav(
          destinations: _destinations,
          currentIndex: currentIndex,
          onSelect: onSelect ?? (_) {},
          addIcon: AppIcons.add,
          addLabel: 'Ekle',
          onAdd: onAdd ?? () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('dört sekme ve ortadaki eylem görünür', (tester) async {
    await _pump(tester);

    for (final d in _destinations) {
      expect(find.text(d.label), findsOneWidget);
    }
    expect(find.text('Ekle'), findsOneWidget);
  });

  testWidgets('Ekle eylemi sekmelerin TAM ORTASINDA durur', (tester) async {
    await _pump(tester);

    final addX = tester.getCenter(find.text('Ekle')).dx;
    final secondX = tester.getCenter(find.text('Hayatım')).dx;
    final thirdX = tester.getCenter(find.text('Mağaza')).dx;

    // İki sekme solda, iki sekme sağda: eylem ikisinin arasında kalmalı.
    expect(addX, greaterThan(secondX));
    expect(addX, lessThan(thirdX));
  });

  testWidgets('sekmeye dokununca indeksi bildirir', (tester) async {
    int? selected;
    await _pump(tester, onSelect: (i) => selected = i);

    await tester.tap(find.text('Mağaza'));
    await tester.pump();

    expect(selected, 2);
  });

  testWidgets('Ekle SEKME DEĞİŞTİRMEZ, ayrı eylemi tetikler', (tester) async {
    var addTapped = false;
    int? selected;

    await _pump(
      tester,
      onSelect: (i) => selected = i,
      onAdd: () => addTapped = true,
    );

    await tester.tap(find.text('Ekle'));
    await tester.pump();

    expect(addTapped, isTrue);
    // Sekme seçimi TETİKLENMEMELİ — "Ekle" bir sayfa değil.
    expect(selected, isNull);
  });

  testWidgets('seçili sekme renkle ayrışır', (tester) async {
    await _pump(tester, currentIndex: 1);

    final theme = AppTheme.light();
    Color colorOf(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;

    expect(colorOf('Hayatım'), theme.colorScheme.primary);
    expect(colorOf('Ana Sayfa'), theme.colorScheme.onSurfaceVariant);
  });

  testWidgets('seçili durum ekran okuyucuya da bildirilir', (tester) async {
    // NFR-031: renk tek başına bilgi taşımamalı.
    await _pump(tester, currentIndex: 1);

    // `isSemantics` yalnızca belirtilen özellikleri kontrol eder;
    // `matchesSemantics` düğümün TAMAMINI eşlemek ister ve ilgilenmediğimiz
    // ayrıntılarda (dokunma eylemi, seçilebilirlik bayrağı) kırılır.
    expect(
      tester.getSemantics(find.text('Hayatım')),
      isSemantics(label: 'Hayatım', isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(find.text('Ana Sayfa')),
      isSemantics(label: 'Ana Sayfa', isSelected: false),
    );
  });

  group('tema', () {
    testWidgets('koyu temada zemin ve metin temadan gelir', (tester) async {
      final dark = AppTheme.dark();
      await _pump(tester, theme: dark, currentIndex: 0);

      final color = tester.widget<Text>(find.text('Ana Sayfa')).style!.color!;
      expect(color, dark.colorScheme.primary);
      // Açık temanın rengi SIZMAMALI.
      expect(color, isNot(AppTheme.light().colorScheme.primary));
    });
  });

  group('responsive', () {
    const sizes = <String, Size>{
      'küçük telefon': Size(320, 568),
      'standart telefon': Size(390, 844),
      'büyük telefon': Size(430, 932),
      'tablet': Size(768, 1024),
    };

    sizes.forEach((label, size) {
      testWidgets('$label — taşma yok', (tester) async {
        await _pump(tester, size: size);

        expect(
          tester.takeException(),
          isNull,
          reason: '$label boyutunda alt çubuk taştı',
        );
        // En dar ekranda bile beş etiketin hepsi çizilebilmeli.
        expect(find.text('Ana Sayfa'), findsOneWidget);
        expect(find.text('Ekle'), findsOneWidget);
      });
    });
  });
}
