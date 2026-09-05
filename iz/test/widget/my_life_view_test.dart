/// "Hayatım" ekranının SEKME davranışı ve anı eylem sayfası.
///
/// Ekran `clockProvider`dan "bugün"ü okuyor; testte sabit bir saat veriyoruz
/// ki takvim vurgusu ve tarih başlıkları çalıştırıldığı güne göre değişmesin.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/my_life/presentation/views/my_life_view.dart';
import 'package:iz/features/my_life/presentation/widgets/calendar_grid.dart';
import 'package:iz/features/my_life/presentation/widgets/collection_card.dart';
import 'package:iz/features/my_life/presentation/widgets/day_memories_panel.dart';
import 'package:iz/features/my_life/presentation/widgets/series_card.dart';

import '../helpers/collections_fixture.dart';
import '../helpers/real_fonts.dart';

final _today = DateTime(2026, 8, 12);

Future<void> pumpMyLife(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [clockProvider.overrideWithValue(FixedClock(_today))],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Builder(
          builder: (context) => MyLifeView(
            collections: CollectionsFixture.cards(
              AppL10n.of(context),
              locale: 'tr',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadRealFonts);

  group('sekme geçişi', () {
    testWidgets('varsayılan sekme TAKVİM', (tester) async {
      await pumpMyLife(tester);

      expect(find.byType(CalendarGrid), findsOneWidget);
      expect(find.byType(DayMemoriesPanel), findsOneWidget);
      expect(find.byType(CollectionCard), findsNothing);
    });

    testWidgets('KOLEKSİYONLAR sekmesi takvimin yerini alır', (tester) async {
      await pumpMyLife(tester);

      await tester.tap(find.text('KOLEKSİYONLAR'));
      await tester.pump();

      expect(find.byType(CollectionCard), findsWidgets);
      // Takvim ve gün paneli artık ağaçta OLMAMALI. `IndexedStack`
      // kullansaydık ikisi de kurulu kalır ve kaydırma boyu yanlış çıkardı.
      expect(find.byType(CalendarGrid), findsNothing);
      expect(find.byType(DayMemoriesPanel), findsNothing);
    });

    testWidgets('SERİLERİM sekmesi seri kartlarını gösterir', (tester) async {
      await pumpMyLife(tester);

      await tester.tap(find.text('SERİLERİM'));
      await tester.pump();

      expect(find.byType(SeriesCard), findsWidgets);
      expect(find.byType(CalendarGrid), findsNothing);

      // Sekme çubuğu yerinde kalmalı — kullanıcı gezinmeye devam edebilsin.
      expect(find.text('TAKVİM'), findsOneWidget);
      expect(find.text('KOLEKSİYONLAR'), findsOneWidget);
    });

    testWidgets('altyazı tekrar tipinden türetiliyor', (tester) async {
      await pumpMyLife(tester);
      await tester.tap(find.text('SERİLERİM'));
      await tester.pump();

      // Mevsimlik ritüel (anchorMonth 7) → yaz.
      expect(find.text('Her yıl yaz aylarında'), findsOneWidget);
      // Yıllık ritüel (3 Mart) → Türkçe bulunma hâli eki doğru olmalı.
      expect(find.text('Her yıl 3 Mart\'ta'), findsOneWidget);
      expect(find.text('Her yıl 15 Mayıs\'ta'), findsOneWidget);
    });

    testWidgets('TAKVİM sekmesine dönülebilir', (tester) async {
      await pumpMyLife(tester);

      await tester.tap(find.text('KOLEKSİYONLAR'));
      await tester.pump();
      await tester.tap(find.text('TAKVİM'));
      await tester.pump();

      expect(find.byType(CalendarGrid), findsOneWidget);
    });
  });

  group('koleksiyonlar sekmesi', () {
    Future<void> openCollections(WidgetTester tester) async {
      await pumpMyLife(tester);
      await tester.tap(find.text('KOLEKSİYONLAR'));
      await tester.pump();
    }

    testWidgets('özet satırı sayaç ve tarih aralığını birleştirir', (
      tester,
    ) async {
      await openCollections(tester);

      // Özet önizleme verisinde HAZIR YAZILI DEĞİL: sayaç çeviriden,
      // aralık `AppDateFormats.range`den geliyor.
      expect(find.text('3 anı • 10-14 Mayıs 2026'), findsOneWidget);
    });

    testWidgets('üç noktaya dokunmak menüyü açar', (tester) async {
      await openCollections(tester);

      await tester.tap(find.byIcon(AppIcons.more).first);
      await tester.pumpAndSettle();

      expect(find.text('Anıya git'), findsOneWidget);
      expect(find.text('Sil'), findsOneWidget);
    });

    testWidgets('menü dokunulan üç noktanın ALTINDA açılır', (tester) async {
      await openCollections(tester);

      // İkinci satırın üç noktası — ortada bir yer, hem aşağı hem yukarı
      // açılabilecek kadar boşluk var.
      final dots = find.byIcon(AppIcons.more).at(1);
      final dotsRect = tester.getRect(dots);

      await tester.tap(dots);
      await tester.pumpAndSettle();

      final menuRect = tester.getRect(find.text('Anıya git'));

      // Menü çıpanın ALTINDA ve sağ tarafında olmalı: dokunduğun yerle
      // bağını koruyor. Alttan açılan sayfada bu bağ kopuyordu.
      expect(menuRect.top, greaterThan(dotsRect.bottom));
      expect(menuRect.left, greaterThan(dotsRect.left - 240));
    });

    testWidgets('Sil, NFR-034 gereği onay diyaloğundan geçer', (tester) async {
      await openCollections(tester);

      await tester.tap(find.byIcon(AppIcons.more).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      // Menü kapanmış, onay diyaloğu açılmış olmalı — ikisi üst üste
      // binmemeli.
      expect(find.text('Anı silinsin mi?'), findsOneWidget);
      expect(find.text('Vazgeç'), findsOneWidget);
      expect(find.text('Anıya git'), findsNothing);
    });

    testWidgets('onayda Vazgeç seçilince hiçbir şey olmaz', (tester) async {
      await openCollections(tester);

      await tester.tap(find.byIcon(AppIcons.more).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(find.text('Anı silinsin mi?'), findsNothing);
      // Kart hâlâ listede.
      expect(find.byType(CollectionCard), findsWidgets);
    });

    testWidgets('menü dışına dokunmak onu kapatır', (tester) async {
      await openCollections(tester);

      await tester.tap(find.byIcon(AppIcons.more).first);
      await tester.pumpAndSettle();

      // Perde görünmez ama dokunuşu yakalıyor: yıkıcı bir eylem içeren menüyü
      // yanlışlıkla açan kullanıcı çıkabilmeli.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.text('Anıya git'), findsNothing);
    });
  });
}
