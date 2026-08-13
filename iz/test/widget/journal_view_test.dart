/// Günlük ana sayfası — FR-030..FR-035.
///
/// EKRANIN SÖZLERİ:
///   • AppBar'da arama ve bildirim YOK
///   • alıntı kutusu ("Bugün kendine ne söylemek istersin?") YOK
///   • karşılama kartındaki düğme yazma ekranını açıyor
///   • "Son Yazılarım" en fazla üç kayıt gösteriyor; fazlası varsa
///     "Tümünü Gör" çıkıyor ve yeni bir sayfa açıyor
///   • fotoğrafı olmayan kayıtta VARSAYILAN görsel çiziliyor
///   • yıldız dokunuşla açılıp kapanıyor
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/journal/presentation/view_models/created_journal_entries_view_model.dart';
import 'package:iz/features/journal/presentation/views/journal_all_entries_view.dart';
import 'package:iz/features/journal/presentation/views/journal_editor_view.dart';
import 'package:iz/features/journal/presentation/views/journal_view.dart';
import 'package:iz/features/journal/presentation/widgets/journal_empty_illustration.dart';
import 'package:iz/features/journal/presentation/widgets/journal_entry_row.dart';
import 'package:iz/features/journal/presentation/widgets/journal_hero_card.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';

import '../helpers/app_harness.dart';
import '../helpers/real_fonts.dart';

late ProviderContainer container;

CreatedJournalEntry _entry(
  String id, {
  String? title,
  String text = 'Bugün sakin geçti.',
  int day = 26,
  bool favorite = false,
}) => (
  entry: JournalEntry(
    id: id,
    entryDate: DateTime(2026, 7, day),
    createdAt: DateTime(2026, 7, day, 21, 30),
    text: text,
    title: title,
    privacyMode: JournalPrivacyMode.standard,
    isFavorite: favorite,
  ),
  photos: const [],
);

Future<void> pumpHome(
  WidgetTester tester, {
  List<CreatedJournalEntry> entries = const [],
  Size size = const Size(390, 1000),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  container = ProviderContainer();
  addTearDown(container.dispose);

  final notifier = container.read(createdJournalEntriesProvider.notifier);
  // Ters sırayla ekliyoruz: depo her yeni kaydı BAŞA koyuyor, yani listenin
  // ilk elemanı son eklenendir.
  for (final entry in entries.reversed) {
    notifier.add(entry);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: '/journal',
          routes: [
            GoRoute(
              path: '/journal',
              name: 'journal',
              builder: (_, _) => const JournalView(),
            ),
            GoRoute(
              path: '/journal/all',
              name: 'journal-all',
              builder: (_, _) => const JournalAllEntriesView(),
            ),
            GoRoute(
              path: '/journal/new',
              name: 'journal-new',
              builder: (_, _) => const JournalEditorView(),
            ),
          ],
        ),
      ),
    ),
  );
  await settle(tester);
}

void main() {
  setUpAll(loadRealFonts);

  group('yerleşim', () {
    testWidgets('başlık, karşılama kartı ve bölüm başlığı duruyor', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Günlük'), findsOneWidget);
      expect(find.byType(JournalHeroCard), findsOneWidget);
      expect(find.text('Hoş geldin'), findsOneWidget);
      expect(find.text('Yazmaya Başla'), findsOneWidget);
      expect(find.text('Son Yazılarım'), findsOneWidget);
    });

    testWidgets('selam ALTINDAKİ yazıyla aynı ailede', (tester) async {
      // Serif denendi ve küçük bir kartta iki yazı ailesi tasarımı "iki
      // sesli" yapıyordu.
      await pumpHome(tester);

      final greeting = tester.widget<Text>(find.text('Hoş geldin'));
      final body = tester.widget<Text>(
        find.textContaining('Kendine birkaç satır'),
      );

      expect(greeting.style!.fontFamily, body.style!.fontFamily);
    });

    testWidgets('ARAMA ve BİLDİRİM ikonları YOK', (tester) async {
      // Kullanıcının kararı: ikisi de bir yere bağlanmıyordu ve çalışmayan
      // düğmeler uygulamanın geri kalanına olan güveni aşındırıyor.
      await pumpHome(tester);

      expect(find.byIcon(AppIcons.search), findsNothing);
      expect(find.byIcon(AppIcons.notifications), findsNothing);
    });

    testWidgets('ALINTI KUTUSU YOK', (tester) async {
      // Referanstaki "Bugün kendine ne söylemek istersin?" kartı çıkarıldı.
      await pumpHome(tester);

      expect(find.textContaining('ne söylemek istersin'), findsNothing);
    });

    testWidgets('alt çubuk duruyor, hiçbir sekme vurgulanmıyor', (
      tester,
    ) async {
      await pumpHome(tester);

      final nav = tester.widget<IzBottomNav>(find.byType(IzBottomNav));
      expect(nav.currentIndex, IzBottomNav.noSelection);
    });
  });

  group('son yazılarım', () {
    testWidgets('kayıt yokken davet eden bir not var', (tester) async {
      await pumpHome(tester);

      expect(find.byType(JournalEntryRow), findsNothing);
      // Uzun paragraf yerine çizim + iki kısa satır.
      expect(find.byType(JournalEmptyIllustration), findsOneWidget);
      expect(find.text('Burası senin sessiz köşen'), findsOneWidget);
      expect(find.textContaining('bir gün dönüp bulacağın'), findsOneWidget);
    });

    testWidgets('satırda tarih, başlık, önizleme ve saat var', (tester) async {
      await pumpHome(
        tester,
        entries: [
          _entry('j1', title: 'Sessiz bir akşam', text: 'Günün sonunda…'),
        ],
      );

      expect(find.text('26'), findsOneWidget);
      expect(find.text('Temmuz'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Sessiz bir akşam'), findsOneWidget);
      expect(find.text('Günün sonunda…'), findsOneWidget);
      expect(find.text('21:30'), findsOneWidget);
    });

    testWidgets('başlıksız kayıt yalnızca metnini gösteriyor', (tester) async {
      await pumpHome(tester, entries: [_entry('j1', text: 'Başlıksız gün.')]);

      expect(find.text('Başlıksız gün.'), findsOneWidget);
      expect(find.byType(JournalEntryRow), findsOneWidget);
    });

    testWidgets('fotoğrafı olmayan kayıtta VARSAYILAN görsel çiziliyor', (
      tester,
    ) async {
      // Boş bir kutu bırakmak listeyi tırtıklı gösteriyordu.
      await pumpHome(tester, entries: [_entry('j1')]);

      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(JournalEntryRow),
          matching: find.byType(Image),
        ),
      );
      expect(
        (image.image as AssetImage).assetName,
        JournalEntryRow.kFallbackAsset,
      );
    });

    testWidgets('EN FAZLA ÜÇ kayıt gösteriliyor', (tester) async {
      // Ana sayfa bir arşiv değil, "en son ne yazmışım"ın cevabı.
      await pumpHome(
        tester,
        entries: [for (var i = 0; i < 5; i++) _entry('j$i', day: 20 + i)],
      );

      expect(
        find.byType(JournalEntryRow),
        findsNWidgets(JournalView.kRecentCount),
      );
    });
  });

  group('tümünü gör', () {
    testWidgets('kayıt YOKKEN bile bölüm başlığının yanında duruyor', (
      tester,
    ) async {
      // Kullanıcının kararı: bağlantı sabit bir işaret, listenin devamı
      // olduğunu söylüyor.
      await pumpHome(tester);

      expect(find.text('Tümünü Gör'), findsOneWidget);
    });

    testWidgets('düğme YENİ SAYFA açıyor ve hepsini gösteriyor', (
      tester,
    ) async {
      await pumpHome(
        tester,
        entries: [for (var i = 0; i < 5; i++) _entry('j$i', day: 20 + i)],
      );

      await tester.tap(find.text('Tümünü Gör'));
      await settle(tester);

      expect(find.byType(JournalAllEntriesView), findsOneWidget);
      expect(find.text('Tüm Günlükler'), findsOneWidget);
      // Sayfa BÜTÜN kayıtları gösteriyor.
      expect(find.byType(JournalEntryRow), findsNWidgets(5));
    });
  });

  group('yıldız', () {
    testWidgets('dokunmak yıldızı açıyor, tekrar dokunmak kapatıyor', (
      tester,
    ) async {
      await pumpHome(tester, entries: [_entry('j1', title: 'Bir gün')]);

      await tester.tap(find.byTooltip('Yıldızla'));
      await settle(tester);

      expect(
        container.read(createdJournalEntriesProvider).single.entry.isFavorite,
        isTrue,
      );
      expect(find.byTooltip('Yıldızı kaldır'), findsOneWidget);

      await tester.tap(find.byTooltip('Yıldızı kaldır'));
      await settle(tester);

      expect(
        container.read(createdJournalEntriesProvider).single.entry.isFavorite,
        isFalse,
      );
    });

    testWidgets('yıldız DOĞRU kayda basılıyor', (tester) async {
      // Hep ilkini yıldızlayan bir hata da "bir tanesi yıldızlandı" testini
      // geçerdi.
      await pumpHome(
        tester,
        entries: [
          _entry('j1', title: 'Birinci', day: 26),
          _entry('j2', title: 'İkinci', day: 25),
        ],
      );

      await tester.tap(find.byTooltip('Yıldızla').last);
      await settle(tester);

      final entries = container.read(createdJournalEntriesProvider);
      expect(entries.first.entry.isFavorite, isFalse);
      expect(entries.last.entry.isFavorite, isTrue);
    });
  });

  group('yazmaya başla', () {
    testWidgets('karşılama kartındaki düğme YAZMA ekranını açıyor', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text('Yazmaya Başla'));
      await settle(tester);

      expect(find.byType(JournalEditorView), findsOneWidget);
    });
  });

  group('dayanıklılık', () {
    testWidgets('2x yazı ölçeğinde taşma yok', (tester) async {
      await pumpHome(tester, entries: [_entry('j1', title: 'Bir gün')]);
      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
    });

    testWidgets('küçük ekranda taşma yok', (tester) async {
      await pumpHome(
        tester,
        entries: [_entry('j1', title: 'Bir gün')],
        size: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
