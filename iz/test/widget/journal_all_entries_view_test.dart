/// "Tüm Günlükler" ekranı — FR-033.
///
/// EKRANIN SÖZLERİ:
///   • dört çip: Tümü · Bu Hafta · Bu Ay · Favoriler
///   • kayıtlar GÜNE göre gruplanıyor, tarih başlıkta
///   • satırda tarih bloğu ve saat YOK — kutu satırı kaplıyor
///   • boş durum SÜZGECE göre konuşuyor
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/journal/presentation/view_models/created_journal_entries_view_model.dart';
import 'package:iz/features/journal/presentation/views/journal_all_entries_view.dart';
import 'package:iz/features/journal/presentation/widgets/journal_entry_row.dart';
import 'package:iz/features/journal/presentation/widgets/journal_filter_chips.dart';

import '../helpers/app_harness.dart';
import '../helpers/real_fonts.dart';

/// 26 Temmuz 2026 bir PAZAR — haftanın son günü, sınır testleri için ideal.
final _today = DateTime(2026, 7, 26, 22);

late ProviderContainer container;

CreatedJournalEntry _entry(
  String id, {
  required DateTime date,
  String title = 'Bir gün',
  bool favorite = false,
}) => (
  entry: JournalEntry(
    id: id,
    entryDate: date,
    createdAt: date,
    text: 'Bugün sakin geçti.',
    title: title,
    privacyMode: JournalPrivacyMode.standard,
    isFavorite: favorite,
  ),
  photos: const [],
);

Future<void> pumpAll(
  WidgetTester tester, {
  List<CreatedJournalEntry> entries = const [],
  Size size = const Size(390, 900),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  container = ProviderContainer(
    overrides: [clockProvider.overrideWithValue(FixedClock(_today))],
  );
  addTearDown(container.dispose);

  final notifier = container.read(createdJournalEntriesProvider.notifier);
  // Ters sırayla: depo her yeni kaydı başa koyuyor.
  for (final entry in entries.reversed) {
    notifier.add(entry);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        home: const JournalAllEntriesView(),
      ),
    ),
  );
  await settle(tester);
}

Future<void> tapChip(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settle(tester);
}

void main() {
  setUpAll(loadRealFonts);

  group('yerleşim', () {
    testWidgets('başlık ve dört çip duruyor', (tester) async {
      await pumpAll(tester);

      expect(find.text('Tüm Günlükler'), findsOneWidget);
      for (final label in ['Tümü', 'Bu Hafta', 'Bu Ay', 'Favoriler']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });

    testWidgets('kayıtlar GÜNE göre gruplanıp başlık alıyor', (tester) async {
      await pumpAll(
        tester,
        entries: [
          _entry('a', date: DateTime(2026, 7, 26, 21), title: 'Akşam'),
          _entry('b', date: DateTime(2026, 7, 26, 9), title: 'Sabah'),
          _entry('c', date: DateTime(2026, 7, 25, 15), title: 'Dün'),
        ],
      );

      // İki gün, iki başlık; aynı günün iki kaydı tek başlık altında.
      expect(find.text('26 Temmuz 2026'), findsOneWidget);
      expect(find.text('25 Temmuz 2026'), findsOneWidget);
      expect(find.byType(JournalEntryRow), findsNWidgets(3));
    });

    testWidgets('satırda TARİH BLOĞU ve SAAT yok', (tester) async {
      // Kullanıcının kararı: tarih başlıkta yazıyor, kutu satırı kaplıyor.
      await pumpAll(
        tester,
        entries: [_entry('a', date: DateTime(2026, 7, 26, 21, 30))],
      );

      final row = tester.widget<JournalEntryRow>(find.byType(JournalEntryRow));
      expect(row.showTimestamp, isFalse);
      // "26" yalnızca başlıkta ("26 Temmuz 2026"), satırda değil.
      expect(find.text('26'), findsNothing);
      expect(find.text('21:30'), findsNothing);
    });

    testWidgets('kutu ana sayfadakinden GENİŞ', (tester) async {
      // Tarih bloğu kalkınca kazanılan yer metne gidiyor.
      await pumpAll(
        tester,
        entries: [_entry('a', date: DateTime(2026, 7, 26))],
      );

      final row = tester.getSize(find.byType(JournalEntryRow));
      // Ekran 390, iki yandan 16 dolgu.
      expect(row.width, 390 - 2 * 16);
    });
  });

  group('süzgeç', () {
    List<CreatedJournalEntry> spread() => [
      // Bu hafta (20-26 Temmuz, pazartesi-pazar).
      _entry('bugun', date: DateTime(2026, 7, 26), title: 'Bugün'),
      _entry('pazartesi', date: DateTime(2026, 7, 20), title: 'Pazartesi'),
      // Bu ay ama geçen hafta.
      _entry('gecenHafta', date: DateTime(2026, 7, 12), title: 'Geçen hafta'),
      // Geçen ay.
      _entry(
        'gecenAy',
        date: DateTime(2026, 6, 30),
        title: 'Geçen ay',
        favorite: true,
      ),
    ];

    testWidgets('Tümü hepsini gösteriyor', (tester) async {
      await pumpAll(tester, entries: spread());

      expect(find.byType(JournalEntryRow), findsNWidgets(4));
    });

    testWidgets('Bu Hafta yalnızca bu haftayı', (tester) async {
      await pumpAll(tester, entries: spread());
      await tapChip(tester, 'Bu Hafta');

      expect(find.text('Bugün'), findsOneWidget);
      expect(find.text('Pazartesi'), findsOneWidget);
      expect(find.text('Geçen hafta'), findsNothing);
      expect(find.text('Geçen ay'), findsNothing);
    });

    testWidgets('Bu Ay geçen ayı elemiyor... eliyor', (tester) async {
      await pumpAll(tester, entries: spread());
      await tapChip(tester, 'Bu Ay');

      expect(find.byType(JournalEntryRow), findsNWidgets(3));
      expect(find.text('Geçen ay'), findsNothing);
    });

    testWidgets('Favoriler yalnızca yıldızlıları', (tester) async {
      await pumpAll(tester, entries: spread());
      await tapChip(tester, 'Favoriler');

      expect(find.byType(JournalEntryRow), findsOneWidget);
      expect(find.text('Geçen ay'), findsOneWidget);
    });

    testWidgets('seçili çip işaretli kalıyor', (tester) async {
      await pumpAll(tester, entries: spread());
      await tapChip(tester, 'Bu Ay');

      final chips = tester.widget<JournalFilterChips>(
        find.byType(JournalFilterChips),
      );
      expect(chips.selected.key, 'thisMonth');
    });
  });

  group('boş durumlar', () {
    testWidgets('süzgece göre FARKLI konuşuyor', (tester) async {
      // "Bu hafta yazmadın" ile "hiç yazmadın" aynı şey değil; ikincisini
      // gören kullanıcı arşivinin silindiğini sanabilir.
      await pumpAll(
        tester,
        entries: [_entry('eski', date: DateTime(2026, 5, 3))],
      );

      await tapChip(tester, 'Bu Hafta');
      expect(find.textContaining('Bu hafta henüz yazmadın'), findsOneWidget);

      await tapChip(tester, 'Favoriler');
      expect(find.textContaining('yıldızlamadın'), findsOneWidget);
    });

    testWidgets('hiç kayıt yokken de çökmüyor', (tester) async {
      await pumpAll(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(JournalEntryRow), findsNothing);
    });
  });

  group('yıldız', () {
    testWidgets('satırdan yıldızlamak süzgeci besliyor', (tester) async {
      await pumpAll(
        tester,
        entries: [_entry('a', date: DateTime(2026, 7, 26), title: 'Bugün')],
      );

      await tester.tap(find.byTooltip('Yıldızla'));
      await settle(tester);
      await tapChip(tester, 'Favoriler');

      expect(find.text('Bugün'), findsOneWidget);
    });
  });

  group('dayanıklılık', () {
    testWidgets('2x yazı ölçeğinde taşma yok', (tester) async {
      await pumpAll(
        tester,
        entries: [_entry('a', date: DateTime(2026, 7, 26))],
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('küçük ekranda taşma yok', (tester) async {
      await pumpAll(
        tester,
        entries: [_entry('a', date: DateTime(2026, 7, 26))],
        size: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
