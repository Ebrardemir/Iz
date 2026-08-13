/// Seri kartı, yıl şeridi ve kaydırma göstergesi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/my_life/presentation/widgets/series_card.dart';
import 'package:iz/features/my_life/presentation/widgets/series_section.dart';

import '../helpers/real_fonts.dart';

/// Dört yıl → tasarımdaki tam sığan hâl (kaydırma yok).
const _fourYears = <SeriesYearData>[
  (
    memoryId: 'y1',
    year: 2026,
    imageAsset: 'assets/images/home/hero_today.jpg',
    placeLabel: 'Çeşme',
  ),
  (
    memoryId: 'y2',
    year: 2025,
    imageAsset: 'assets/images/home/memory_coffee.jpg',
    placeLabel: 'Kaş',
  ),
  (
    memoryId: 'y3',
    year: 2024,
    imageAsset: 'assets/images/auth/hero_light.jpg',
    placeLabel: 'Datça',
  ),
  (
    memoryId: 'y4',
    year: 2023,
    imageAsset: 'assets/images/home/hero_today.jpg',
    placeLabel: 'Ayvalık',
  ),
];

const _summer = (
  id: 'rit-yaz',
  iconKey: 'summer',
  title: 'Yaz Tatillerimiz',
  subtitle: 'Her yıl yaz aylarında',
  years: _fourYears,
);

const _birthday = (
  id: 'rit-dogumgunu',
  iconKey: 'birthday',
  title: 'Annemin Doğum Günleri',
  subtitle: 'Her yıl 3 Mart\'ta',
  years: <SeriesYearData>[
    (
      memoryId: 'b1',
      year: 2026,
      imageAsset: 'assets/images/home/memory_coffee.jpg',
      placeLabel: 'Ankara',
    ),
  ],
);

Widget _wrap(Widget child, {bool dark = false}) => MaterialApp(
  theme: dark ? AppTheme.dark() : AppTheme.light(),
  locale: const Locale('tr'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  setUpAll(loadRealFonts);

  group('görünen yıllar (saf hesap)', () {
    // Tasarımdaki ölçüler: öğe 64, aralık 17 → adım 81. Şerit 307 geniş.
    ({int first, int count}) visible(double offset, {int years = 5}) =>
        resolveVisibleYears(
          scrollOffset: offset,
          viewportWidth: 307,
          yearCount: years,
          itemWidth: 64,
          gap: 17,
        );

    test('başta ilk dört yıl görünür', () {
      // 4×64 + 3×17 = 307 → tam dört öğe sığıyor.
      expect(visible(0), (first: 0, count: 4));
    });

    test('sona kaydırınca pencere sağa kayar', () {
      // 5 yıl → içerik 388, pencere 307 → maxScroll 81.
      expect(visible(81), (first: 1, count: 4));
    });

    test('yarısından azı görünen yıl SAYILMAZ', () {
      // BU EŞİK OLMASA gösterge kaydırma boyunca titrerdi: kenardan 1 px
      // giren yıl da noktayı doldururdu.
      //
      // offset 20 → 4. öğe (index 4) 324..388 aralığında, pencere
      // 20..327 → sadece 3 px görünüyor, yarısından az.
      expect(visible(20).count, 4);
      expect(visible(20).first, 0);
    });

    test('pencere BÜYÜMEZ, KAYAR', () {
      // 5. öğe 324'te başlıyor; yarısı (32 px) görünsün diye pencerenin
      // 356'ya ulaşması gerekiyor → offset 49. Ama o anda 1. öğenin de
      // yalnızca 15 px'i kalıyor, yani o çıkıyor.
      //
      // Sonuç: dolu nokta sayısı sabit, pencere sağa kayıyor. Gösterge
      // "kaç yılım var, hangilerine bakıyorum" derken bu davranış doğru —
      // dolu nokta sayısının kaydırma boyunca oynaması kafa karıştırırdı.
      expect(visible(49), (first: 1, count: 4));
    });

    test('on iki yıllı seride pencere dört yılda kalır', () {
      final result = visible(81 * 4, years: 12);
      expect(result.count, 4);
      expect(result.first, 4);
    });

    test('aşırı kaydırmada (bounce) boş dönmez', () {
      // iOS'ta parmak bırakılınca `pixels` sınırı aşabiliyor; gösterge
      // tamamen boş kalmasın.
      expect(visible(-60).count, greaterThan(0));
      expect(visible(9999).count, greaterThan(0));
      expect(visible(9999).first, 4);
    });

    test('yıl yoksa çökmez', () {
      expect(visible(0, years: 0), (first: 0, count: 0));
    });
  });

  group('nokta aralığı (saf hesap)', () {
    // Ray 259 (307 − 2×24), nokta 8, yıl adımı 81 (64 kutu + 17 aralık).
    double spacing(int count) => resolveDotSpacing(
      railWidth: 259,
      dotSize: 8,
      count: count,
      itemStride: 81,
    );

    test('sığdığı sürece aralık YIL ADIMINA eşit', () {
      // Böylece noktalar üstteki yıl sütunlarının altına düşüyor.
      expect(spacing(2), 81);
      expect(spacing(3), 81);
      expect(spacing(4), 81);
    });

    test('dört nokta raya sığar, kalanı düz çizgi', () {
      // 4 nokta → 3×81 + 8 = 251 ≤ 259.
      final width = 3 * spacing(4) + 8;
      expect(width, lessThanOrEqualTo(259));
    });

    test('sığmayınca sıkışır ama rayı taşırmaz', () {
      for (final count in [5, 8, 12, 16]) {
        final width = (count - 1) * spacing(count) + 8;
        expect(
          width,
          lessThanOrEqualTo(259),
          reason: '$count nokta rayı taşırıyor',
        );
      }
    });

    test('sıkışan aralık yıl adımından küçük olur', () {
      expect(spacing(12), lessThan(81));
      expect(spacing(16), lessThan(spacing(12)));
    });

    test('tek nokta çökmez', () {
      expect(spacing(1), 81);
      expect(spacing(0), 81);
    });
  });

  group('gösterge konumu (saf hesap)', () {
    test('kaydırma başındayken nokta solda', () {
      expect(
        resolveSeriesIndicatorOffset(
          scrollOffset: 0,
          maxScrollExtent: 120,
          trackWidth: 259,
          dotSize: 8,
        ),
        0,
      );
    });

    test('kaydırma sonundayken nokta rayın sağ ucunda — TAŞMAZ', () {
      // Noktanın kendi genişliği kadar geri çekilmeli, yoksa raydan çıkar.
      expect(
        resolveSeriesIndicatorOffset(
          scrollOffset: 120,
          maxScrollExtent: 120,
          trackWidth: 259,
          dotSize: 8,
        ),
        259 - 8,
      );
    });

    test('ortadayken nokta ortada', () {
      expect(
        resolveSeriesIndicatorOffset(
          scrollOffset: 60,
          maxScrollExtent: 120,
          trackWidth: 208,
          dotSize: 8,
        ),
        100,
      );
    });

    test('aşırı kaydırmada (bounce) sınırda kalır', () {
      // iOS'ta parmak bırakılınca `pixels` geçici olarak sınırı aşar.
      expect(
        resolveSeriesIndicatorOffset(
          scrollOffset: 200,
          maxScrollExtent: 120,
          trackWidth: 259,
          dotSize: 8,
        ),
        259 - 8,
      );
      expect(
        resolveSeriesIndicatorOffset(
          scrollOffset: -40,
          maxScrollExtent: 120,
          trackWidth: 259,
          dotSize: 8,
        ),
        0,
      );
    });

    test('kaydırılacak şey yoksa ve ray dar olsa da çökmez', () {
      expect(
        resolveSeriesIndicatorOffset(
          scrollOffset: 0,
          maxScrollExtent: 0,
          trackWidth: 4,
          dotSize: 8,
        ),
        0,
      );
    });
  });

  group('kart', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      SeriesCardData series = _summer,
      VoidCallback? onOpen,
      ValueChanged<SeriesYearData>? onOpenYear,
      Size size = const Size(390, 900),
      bool dark = false,
    }) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          Padding(
            // Ekranda 20'lik sayfa marjı içinde duruyor → 350 genişlik.
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SeriesCard(
              series: series,
              onOpen: onOpen ?? () {},
              onOpenYear: onOpenYear ?? (_) {},
            ),
          ),
          dark: dark,
        ),
      );
      await tester.pump();
    }

    testWidgets('başlık, altyazı ve yıllar görünür', (tester) async {
      await pumpCard(tester);

      expect(find.text('Yaz Tatillerimiz'), findsOneWidget);
      expect(find.text('Her yıl yaz aylarında'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('2023'), findsOneWidget);
      expect(find.text('Çeşme'), findsOneWidget);
    });

    testWidgets('ikon iconKey\'den çözülüyor', (tester) async {
      await pumpCard(tester);
      expect(find.byIcon(AppIcons.forKey('summer')), findsOneWidget);

      await pumpCard(tester, series: _birthday);
      expect(find.byIcon(AppIcons.forKey('birthday')), findsOneWidget);
    });

    testWidgets('bilinmeyen iconKey çökmez, yedek ikona düşer', (tester) async {
      // Eski bir sürümden gelen veri uygulamayı kırmamalı.
      await pumpCard(
        tester,
        series: (
          id: 'x',
          iconKey: 'boyle-bir-anahtar-yok',
          title: 'Test',
          subtitle: 'Test',
          years: _fourYears,
        ),
      );

      expect(find.byIcon(AppIcons.fallbackCategory), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('karta dokunmak seriyi açar', (tester) async {
      var opened = 0;
      await pumpCard(tester, onOpen: () => opened++);

      await tester.tap(find.text('Yaz Tatillerimiz'));
      await tester.pump();

      expect(opened, 1);
    });

    testWidgets('yıla dokunmak SERİYİ değil o yılı açar', (tester) async {
      var opened = 0;
      final years = <SeriesYearData>[];
      await pumpCard(tester, onOpen: () => opened++, onOpenYear: years.add);

      await tester.tap(find.text('2024'));
      await tester.pump();

      expect(years.single.year, 2024);
      expect(opened, 0);
    });

    testWidgets('yıl öğesi 64 geniş, kapağı 56 × 56', (tester) async {
      // Figma: öğe 64 × 108, kapak 56 × 56.
      await pumpCard(tester);

      final item = find.ancestor(
        of: find.text('2026'),
        matching: find.byWidgetPredicate((w) => w is SizedBox && w.width == 64),
      );
      expect(item, findsOneWidget);
      expect(tester.getSize(item).width, 64);

      expect(tester.getSize(find.byType(Image).first), const Size(56, 56));
    });

    testWidgets('yıl şeridi tasarımdaki 108 yüksekliğinde', (tester) async {
      await pumpCard(tester);

      final strip = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == SeriesCard.kYearStripHeight,
      );
      expect(strip, findsOneWidget);
    });

    testWidgets('konumu olmayan yıl da aynı hizada kalır', (tester) async {
      // Konum opsiyonel; yokken kapaklar kaymamalı.
      const withoutPlace = (
        id: 'x',
        iconKey: 'ritual',
        title: 'Test',
        subtitle: 'Test',
        years: <SeriesYearData>[
          (
            memoryId: 'a',
            year: 2026,
            imageAsset: 'assets/images/home/hero_today.jpg',
            placeLabel: null,
          ),
          (
            memoryId: 'b',
            year: 2025,
            imageAsset: 'assets/images/home/hero_today.jpg',
            placeLabel: 'Venedik',
          ),
        ],
      );

      await pumpCard(tester, series: withoutPlace);

      expect(
        tester.getRect(find.text('2026')).top,
        tester.getRect(find.text('2025')).top,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('koyu temada hata/taşma olmaz', (tester) async {
      await pumpCard(tester, dark: true);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kaydırılabilir şeritte ray GERÇEKTEN çizilir', (tester) async {
      // BU TESTİN SEBEBİ: ray, çocuksuz bir `ColoredBox`. Yatayda gevşek bir
      // kısıt alırsa kendini 0 genişlikte ölçer ve sessizce kaybolur — bu
      // hatayı `day_memory_card.dart`ın alt çizgisinde bir kez yaşadık,
      // burada da tekrar etti. Genişliği ölçüyoruz ki üçüncüsü olmasın.
      await pumpCard(tester, size: const Size(320, 900));

      final rail = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 1,
      );

      expect(rail, findsOneWidget);
      expect(tester.getSize(rail).width, greaterThan(100));
    });

    testWidgets('şerit sığsa da ray VE noktalar çizilir', (tester) async {
      // Tek yıllı bir seride de gösterge duruyor. "Kaydırılacak şey yoksa
      // gizle" kuralı KALDIRILDI: o kural hareketli nokta içindi ("devamı
      // var" yalanı). Yıl başına nokta yalan söylemiyor — bir nokta bir yıl
      // demek ve dolu olması "görüyorsun" demek. Gösterge her kartta
      // durunca kartların alt kenarı da aynı ritmi tutuyor.
      await pumpCard(tester, series: _birthday);

      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.height == 1),
        findsOneWidget,
      );
    });

    testWidgets('küçük ekranda şerit kayar, taşma olmaz', (tester) async {
      // iPhone SE genişliği: dört yıl artık sığmıyor.
      await pumpCard(tester, size: const Size(320, 900));

      expect(tester.takeException(), isNull);
      expect(find.text('2026'), findsOneWidget);
    });
  });

  group('liste', () {
    Future<void> pumpSection(
      WidgetTester tester, {
      List<SeriesCardData> series = const [_summer, _birthday],
    }) async {
      tester.view
        ..physicalSize = const Size(390, 1400)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          SeriesSection(
            series: series,
            onOpenSeries: (_) {},
            onOpenYear: (_) {},
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('her seri için bir kart çizilir', (tester) async {
      await pumpSection(tester);

      expect(find.byType(SeriesCard), findsNWidgets(2));
      // KOLEKSİYONLARDAN FARKI: katlama yok, hepsi açık.
      expect(find.text('Yaz Tatillerimiz'), findsOneWidget);
      expect(find.text('Annemin Doğum Günleri'), findsOneWidget);
    });

    testWidgets('seri yokken boş durum gösterilir', (tester) async {
      await pumpSection(tester, series: const []);

      expect(find.byType(SeriesCard), findsNothing);
      expect(find.text('Henüz bir seri yok'), findsOneWidget);
    });
  });
}
