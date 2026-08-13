/// Halka menünün DOKUNULABİLİRLİĞİ.
///
/// NEDEN AYRI BİR TEST DOSYASI?
/// Bu widget'ta aynı sınıf hataya İKİ KEZ düştük: daireler `Transform` ile
/// yerlerine taşınıyor ve `RenderBox` kendi boyunun dışındaki bir noktayı
/// çocuklarına hiç sormuyor. Sonuç her seferinde aynı — öğe EKRANDA GÖRÜNÜYOR
/// ama DOKUNULAMIYOR. Gözle fark edilmesi neredeyse imkânsız.
///
/// Bu yüzden burada her seçeneğin hem dairesine hem ETİKETİNE dokunup
/// geri çağırmanın çalıştığını doğruluyoruz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/shared/widgets/iz_radial_menu.dart';

import '../helpers/real_fonts.dart';

/// Beş seçenek — referans tasarımdaki sıra.
const _labels = ['Koleksiyon', 'Seri', 'Anı', 'Günlük Kaydı', 'Kişi'];
const _icons = [
  AppIcons.collection,
  AppIcons.ritual,
  AppIcons.memory,
  AppIcons.navJournal,
  AppIcons.person,
];

/// Menüyü açar ve dokunulan seçeneklerin etiketlerini biriktirir.
Future<List<String>> pumpMenu(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double bottomInset = 72,
}) async {
  final pressed = <String>[];

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
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showIzRadialMenu(
                context,
                semanticTitle: 'Ne eklemek istersin?',
                bottomInset: bottomInset,
                actions: [
                  for (var i = 0; i < _labels.length; i++)
                    (
                      icon: _icons[i],
                      label: _labels[i],
                      onPressed: () => pressed.add(_labels[i]),
                    ),
                ],
              ),
              child: const Text('AÇ'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('AÇ'));
  await tester.pumpAndSettle();

  return pressed;
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('beş seçenek ve kapatma düğmesi görünür', (tester) async {
    await pumpMenu(tester);

    for (final label in _labels) {
      expect(find.text(label), findsOneWidget, reason: '$label görünmüyor');
    }
    expect(find.byIcon(AppIcons.clear), findsOneWidget);
  });

  group('ETİKETE dokunmak çalışıyor', () {
    // ASIL BEKÇİ. `Transform` görseli taşıyıp dokunma kutusunu yerinde
    // bıraktığında ilk kaybolan şey etiket oluyor — daire hâlâ çalışıyor,
    // bu yüzden elle denerken sorun gözden kaçıyor.
    for (final label in _labels) {
      testWidgets(label, (tester) async {
        final pressed = await pumpMenu(tester);

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(pressed, [label]);
      });
    }
  });

  group('DAİREYE dokunmak çalışıyor', () {
    for (var i = 0; i < _labels.length; i++) {
      testWidgets(_labels[i], (tester) async {
        final pressed = await pumpMenu(tester);

        await tester.tap(find.byIcon(_icons[i]));
        await tester.pumpAndSettle();

        expect(pressed, [_labels[i]]);
      });
    }
  });

  group('kapanma yolları', () {
    testWidgets('çarpı menüyü kapatır, hiçbir eylem çalışmaz', (tester) async {
      final pressed = await pumpMenu(tester);

      await tester.tap(find.byIcon(AppIcons.clear));
      await tester.pumpAndSettle();

      expect(find.text('Anı'), findsNothing);
      expect(pressed, isEmpty);
    });

    testWidgets('boşluğa dokunmak kapatır', (tester) async {
      final pressed = await pumpMenu(tester);

      // Buğulu zemin — halkanın dışında bir nokta.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.text('Anı'), findsNothing);
      expect(pressed, isEmpty);
    });
  });

  group('yerleşim', () {
    testWidgets('kapatma düğmesi alt çubuğun hemen üstünde', (tester) async {
      const bottomInset = 72.0;
      await pumpMenu(tester, bottomInset: bottomInset);

      final close = tester.getRect(find.byIcon(AppIcons.clear));
      const navTop = 844 - bottomInset;

      // "Çok az yukarıda": boşluk küçük ve pozitif olmalı.
      final gap = navTop - close.bottom;
      expect(gap, greaterThan(0), reason: 'Çarpı alt çubuğa binmiş');
      expect(gap, lessThan(48), reason: 'Çarpı alt çubuktan çok uzak');
    });

    testWidgets('Anı tepede, Koleksiyon solda, Kişi sağda', (tester) async {
      await pumpMenu(tester);

      final memory = tester.getCenter(find.byIcon(AppIcons.memory));
      final collection = tester.getCenter(find.byIcon(AppIcons.collection));
      final person = tester.getCenter(find.byIcon(AppIcons.person));

      // Anı en üstteki yuvada — asıl eylem en görünür yerde.
      expect(memory.dy, lessThan(collection.dy));
      expect(memory.dy, lessThan(person.dy));
      // Koleksiyon solda, Kişi sağda; Anı ikisinin ortasında.
      expect(collection.dx, lessThan(memory.dx));
      expect(person.dx, greaterThan(memory.dx));
      expect(memory.dx, closeTo((collection.dx + person.dx) / 2, 1));
    });

    testWidgets('küçük ekranda da taşma/hata olmaz', (tester) async {
      // iPhone SE.
      await pumpMenu(tester, size: const Size(320, 667));

      expect(tester.takeException(), isNull);
      for (final label in _labels) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });
}
