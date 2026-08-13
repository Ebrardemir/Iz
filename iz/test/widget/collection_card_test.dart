/// Koleksiyon kartı ve KOLEKSİYONLAR sekmesinin listesi.
///
/// Katlama durumu widget'ın DIŞINDA (listede) yaşıyor; testler bu sayede
/// "açık" ve "kapalı" hâlleri tek tek kurabiliyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/my_life/presentation/widgets/collection_card.dart';
import 'package:iz/features/my_life/presentation/widgets/collections_section.dart';

import '../helpers/real_fonts.dart';

const _memories = <CollectionMemoryData>[
  (
    id: 'm1',
    imageAsset: 'assets/images/home/hero_today.jpg',
    title: 'Balonlar havalanırken',
    dateLabel: '10 Mayıs 2026',
  ),
  (
    id: 'm2',
    imageAsset: 'assets/images/home/memory_coffee.jpg',
    title: 'Güvercinlik Vadisi',
    dateLabel: '12 Mayıs 2026',
  ),
  (
    id: 'm3',
    imageAsset: 'assets/images/auth/hero_light.jpg',
    title: 'Kızılçukur\'da gün batımı',
    dateLabel: '14 Mayıs 2026',
  ),
];

const _kapadokya = (
  id: 'col-1',
  coverAsset: 'assets/images/home/hero_today.jpg',
  title: 'Kapadokya 2026',
  summary: '3 anı • 10-14 Mayıs 2026',
  memories: _memories,
);

const _universite = (
  id: 'col-2',
  coverAsset: 'assets/images/auth/hero_light.jpg',
  title: 'Üniversite Yıllarım',
  summary: '2 anı • 20 Eylül 2021 — 14 Haziran 2025',
  memories: <CollectionMemoryData>[],
);

Widget _wrap(Widget child, {bool dark = false}) => MaterialApp(
  theme: dark ? AppTheme.dark() : AppTheme.light(),
  locale: const Locale('tr'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> _sizeTo(WidgetTester tester, [Size size = const Size(390, 900)]) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  return Future<void>.value();
}

void main() {
  setUpAll(loadRealFonts);

  group('tek kart', () {
    Future<List<CollectionMemoryData>> pumpCard(
      WidgetTester tester, {
      required bool isExpanded,
      VoidCallback? onToggle,
      void Function(CollectionMemoryData, Rect)? onActions,
    }) async {
      final opened = <CollectionMemoryData>[];
      await _sizeTo(tester);

      await tester.pumpWidget(
        _wrap(
          CollectionCard(
            collection: _kapadokya,
            isExpanded: isExpanded,
            onToggle: onToggle ?? () {},
            onOpenMemory: opened.add,
            onMemoryActions: onActions ?? (_, _) {},
          ),
        ),
      );
      await tester.pump();
      return opened;
    }

    testWidgets('kapalıyken tasarımdaki 86 yüksekliğinde', (tester) async {
      await pumpCard(tester, isExpanded: false);

      expect(
        tester.getSize(find.byType(CollectionCard)).height,
        CollectionCard.kCollapsedHeight,
      );
    });

    testWidgets('kapalıyken anılar gösterilmez', (tester) async {
      await pumpCard(tester, isExpanded: false);

      expect(find.text('Kapadokya 2026'), findsOneWidget);
      expect(find.text('3 anı • 10-14 Mayıs 2026'), findsOneWidget);
      // Anı satırları yalnızca açık kartta var.
      expect(find.text('Balonlar havalanırken'), findsNothing);
    });

    testWidgets('kapalıyken chevron AŞAĞI, açıkken YUKARI bakar', (
      tester,
    ) async {
      await pumpCard(tester, isExpanded: false);
      expect(find.byIcon(AppIcons.expand), findsOneWidget);
      expect(find.byIcon(AppIcons.collapse), findsNothing);

      await pumpCard(tester, isExpanded: true);
      expect(find.byIcon(AppIcons.collapse), findsOneWidget);
      expect(find.byIcon(AppIcons.expand), findsNothing);
    });

    testWidgets('açıkken üç anı satırı ve kapak şeridi görünür', (
      tester,
    ) async {
      await pumpCard(tester, isExpanded: true);

      expect(find.text('Balonlar havalanırken'), findsOneWidget);
      expect(find.text('Güvercinlik Vadisi'), findsOneWidget);
      expect(find.text('Kızılçukur\'da gün batımı'), findsOneWidget);
      expect(find.text('10 Mayıs 2026'), findsOneWidget);
    });

    testWidgets('üç anıyla açık kart tasarımdaki 370 yüksekliğinde', (
      tester,
    ) async {
      await pumpCard(tester, isExpanded: true);

      // Tasarım üç anı satırı üzerine kurulu:
      // 1 + 4 + 120 (kapak) + 72 (başlık) + 3×56 + 4 + 1 = 370.
      // Bu sayı kayarsa satır yüksekliği, kapak şeridi ya da dolgu bozulmuş.
      expect(tester.getSize(find.byType(CollectionCard)).height, 370);
    });

    testWidgets('kart 350 genişlikte', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: SizedBox(
              width: 350,
              child: CollectionCard(
                collection: _kapadokya,
                isExpanded: false,
                onToggle: _noop,
                onOpenMemory: _noopMemory,
                onMemoryActions: _noopActions,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.getSize(find.byType(CollectionCard)).width, 350);
    });

    testWidgets('başlığa dokunmak katlamayı tetikler', (tester) async {
      var toggles = 0;
      await pumpCard(tester, isExpanded: false, onToggle: () => toggles++);

      await tester.tap(find.text('Kapadokya 2026'));
      await tester.pump();

      expect(toggles, 1);
    });

    testWidgets('anı satırına dokunmak o anıyı bildirir', (tester) async {
      final opened = await pumpCard(tester, isExpanded: true);

      await tester.tap(find.text('Güvercinlik Vadisi'));
      await tester.pump();

      expect(opened.single.id, 'm2');
    });

    testWidgets('üç noktaya dokunmak KATLAMAYI değil eylemi tetikler', (
      tester,
    ) async {
      // BU TESTİN SEBEBİ: satırın tamamı `InkWell` olsaydı üç nokta da
      // anıyı açardı ve eylem sayfasına hiç ulaşılamazdı.
      var toggles = 0;
      final actions = <CollectionMemoryData>[];
      final opened = await pumpCard(
        tester,
        isExpanded: true,
        onToggle: () => toggles++,
        onActions: (memory, _) => actions.add(memory),
      );

      await tester.tap(find.byIcon(AppIcons.more).first);
      await tester.pump();

      expect(actions.single.id, 'm1');
      expect(opened, isEmpty);
      expect(toggles, 0);
    });

    testWidgets('üç noktanın dokunma hedefi 48 (NFR-033)', (tester) async {
      await pumpCard(tester, isExpanded: true);

      final button = find
          .ancestor(
            of: find.byIcon(AppIcons.more).first,
            matching: find.byType(IconButton),
          )
          .first;

      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
    });

    testWidgets('koyu temada hata/taşma olmaz', (tester) async {
      await _sizeTo(tester);
      await tester.pumpWidget(
        _wrap(
          const CollectionCard(
            collection: _kapadokya,
            isExpanded: true,
            onToggle: _noop,
            onOpenMemory: _noopMemory,
            onMemoryActions: _noopActions,
          ),
          dark: true,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('liste (akordeon)', () {
    Future<void> pumpSection(
      WidgetTester tester, {
      List<CollectionCardData> collections = const [_kapadokya, _universite],
    }) async {
      await _sizeTo(tester, const Size(390, 1400));
      await tester.pumpWidget(
        _wrap(
          CollectionsSection(
            collections: collections,
            onOpenMemory: (_) {},
            onMemoryActions: (_, _) {},
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('ekran açılınca İLK kart açık gelir', (tester) async {
      await pumpSection(tester);

      // Kapadokya açık → anıları görünür; Üniversite kapalı.
      expect(find.text('Balonlar havalanırken'), findsOneWidget);
      expect(find.byIcon(AppIcons.collapse), findsOneWidget);
      expect(find.byIcon(AppIcons.expand), findsOneWidget);
    });

    testWidgets('başka karta dokunmak öncekini KAPATIR', (tester) async {
      await pumpSection(tester);

      await tester.tap(find.text('Üniversite Yıllarım'));
      await tester.pump();

      // Akordeon: aynı anda tek kart açık.
      expect(find.text('Balonlar havalanırken'), findsNothing);
      expect(find.byIcon(AppIcons.collapse), findsOneWidget);
    });

    testWidgets('açık karta tekrar dokunmak onu kapatır', (tester) async {
      await pumpSection(tester);

      await tester.tap(find.text('Kapadokya 2026'));
      await tester.pump();

      expect(find.text('Balonlar havalanırken'), findsNothing);
      // Hepsi kapalı → hiç yukarı chevron kalmaz.
      expect(find.byIcon(AppIcons.collapse), findsNothing);
      expect(find.byIcon(AppIcons.expand), findsNWidgets(2));
    });

    testWidgets('koleksiyon yokken boş durum gösterilir', (tester) async {
      await pumpSection(tester, collections: const []);

      expect(find.byType(CollectionCard), findsNothing);
      expect(find.text('Henüz bir koleksiyon yok'), findsOneWidget);
    });
  });
}

void _noop() {}
void _noopMemory(CollectionMemoryData _) {}
void _noopActions(CollectionMemoryData _, Rect _) {}
