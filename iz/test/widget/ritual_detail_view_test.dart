/// Seri detay ekranı — FR-075, FR-076.
///
/// EKRANIN SÖZLERİ:
///   • kapak var, ALTINDA YAZI YOK
///   • üç kutu sayıları anılardan türetiyor; şehir verisi yoksa o kutu hiç
///     çizilmiyor
///   • anı satırında üç nokta YOK, satır anıya götürüyor
///   • liste dörtten uzunsa kısalıyor ve "Tümünü Gör" onu YERİNDE açıyor
///   • üç nokta menüsü: Düzenle / Sil, silme onay istiyor
///   • kullanıcının çıkardıkları geri gelmiyor: "Yıllar" şeridi, "Kolaj
///     Oluştur", "Bu Yıla Anı Ekle"
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/rituals/presentation/views/ritual_detail_preview_data.dart';
import 'package:iz/features/rituals/presentation/views/ritual_detail_view.dart';
import 'package:iz/features/rituals/presentation/widgets/ritual_detail_parts.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';

import '../helpers/app_harness.dart';
import '../helpers/real_fonts.dart';

const _cover = MediaItem(
  id: 'preview:cover',
  type: MediaType.photo,
  originalStatus: MediaOriginalStatus.available,
  localPreviewPath: 'assets/images/home/hero_today.jpg',
);

RitualDetailMemory _memory(
  int year, {
  String? place = 'Çeşme',
  String? category = 'Seyahat',
}) => (
  id: 'mem-$year',
  imageAsset: 'assets/images/home/hero_today.jpg',
  title: '$year yazı',
  dateLabel: '14 Temmuz $year',
  year: year,
  categoryLabel: category,
  placeLabel: place,
);

/// Açılan anı kimlikleri — satırın gerçekten götürdüğünü doğrulamak için.
late List<String> opened;

Future<void> pumpDetail(
  WidgetTester tester, {
  RitualDetailData? ritual,
  Size size = const Size(390, 900),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  opened = [];

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('tr'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: child!,
      ),
      home: RitualDetailView(
        ritual:
            ritual ??
            (
              id: 'rit-yaz',
              title: 'Yaz Tatillerimiz',
              cover: _cover,
              memories: [_memory(2026), _memory(2025), _memory(2024)],
            ),
        onOpenMemory: opened.add,
      ),
    ),
  );
  await settle(tester);
}

void main() {
  setUpAll(loadRealFonts);

  group('yerleşim', () {
    testWidgets('başlık AppBar\'da, kapak altında YAZI YOK', (tester) async {
      // Referansta kapağın altında bir slogan vardı; kullanıcı kaldırttı ve
      // haklı — o cümleyi kimse yazmıyor, uygulamanın uydurması olurdu.
      await pumpDetail(tester);

      expect(find.text('Yaz Tatillerimiz'), findsOneWidget);
      expect(find.byType(RitualDetailCover), findsOneWidget);
      expect(find.textContaining('biriken anılar'), findsNothing);
    });

    testWidgets('kapağı olmayan seride kapak hiç çizilmiyor', (tester) async {
      // Boş gri bir dikdörtgen, sayfanın en üstünde bir "eksik" duygusu
      // bırakıyordu.
      await pumpDetail(
        tester,
        ritual: (
          id: 'r',
          title: 'Kapaksız',
          cover: null,
          memories: [_memory(2026)],
        ),
      );

      expect(find.byType(AspectRatio), findsNothing);
    });

    testWidgets('ÇIKARILANLAR geri gelmemiş', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Yıllar'), findsNothing);
      expect(find.textContaining('Kolaj'), findsNothing);
      expect(find.textContaining('Anı Ekle'), findsNothing);
    });
  });

  group('üç kutu', () {
    testWidgets('yıl, anı ve şehir sayıları anılardan geliyor', (tester) async {
      // Aynı yıla iki anı: "3 anı" ama "2 yıl". Aynı şehir iki kez: "1 şehir".
      await pumpDetail(
        tester,
        ritual: (
          id: 'r',
          title: 'Yaz',
          cover: _cover,
          memories: [_memory(2026), _memory(2026), _memory(2025)],
        ),
      );

      expect(find.text('2 yıl'), findsOneWidget);
      expect(find.text('3 anı'), findsOneWidget);
      expect(find.text('1 şehir'), findsOneWidget);
    });

    testWidgets('konum yoksa ŞEHİR KUTUSU hiç çizilmiyor', (tester) async {
      // "0 şehir / Keşfedildi" bir bilgi değil, boşluğun süslenmiş hâli.
      await pumpDetail(
        tester,
        ritual: (
          id: 'r',
          title: 'Yaz',
          cover: _cover,
          memories: [
            _memory(2026, place: null),
            _memory(2025, place: '  '),
          ],
        ),
      );

      expect(find.text('Keşfedildi'), findsNothing);
      expect(find.text('Birlikte'), findsOneWidget);
      expect(find.text('Toplam'), findsOneWidget);
    });
  });

  group('anı listesi', () {
    testWidgets('satırda ad, tarih ve kategori çipi var', (tester) async {
      await pumpDetail(tester);

      expect(find.text('2026 yazı'), findsOneWidget);
      expect(find.text('14 Temmuz 2026'), findsOneWidget);
      expect(find.text('Seyahat'), findsWidgets);
    });

    testWidgets('kategorisi olmayan anıda çip yok', (tester) async {
      await pumpDetail(
        tester,
        ritual: (
          id: 'r',
          title: 'Yaz',
          cover: _cover,
          memories: [_memory(2026, category: null)],
        ),
      );

      expect(find.text('Seyahat'), findsNothing);
      expect(find.text('2026 yazı'), findsOneWidget);
    });

    testWidgets('ÜÇ NOKTA YOK', (tester) async {
      // Kullanıcının kararı: satırın tek işi o anıya gitmek.
      await pumpDetail(tester);

      expect(
        find.descendant(
          of: find.byType(RitualMemoryRow).first,
          matching: find.byIcon(AppIcons.more),
        ),
        findsNothing,
      );
    });

    testWidgets('satıra dokunmak O anıya götürüyor', (tester) async {
      // Sabit bir kimliğe gitmek de testi geçerdi; ikinci satıra dokunuyoruz.
      await pumpDetail(tester);

      await tester.tap(find.text('2025 yazı'));
      await settle(tester);

      expect(opened, ['mem-2025']);
    });

    testWidgets('anısı olmayan seride açıklama notu var', (tester) async {
      await pumpDetail(
        tester,
        ritual: (id: 'r', title: 'Yeni', cover: _cover, memories: []),
      );

      expect(find.text('Bu Serideki Anılar'), findsOneWidget);
      expect(find.byType(RitualMemoryRow), findsNothing);
      expect(find.textContaining('henüz anı bağlamadın'), findsOneWidget);
    });
  });

  group('tümünü gör', () {
    RitualDetailData longSeries() => (
      id: 'r',
      title: 'Uzun',
      cover: _cover,
      memories: [for (var year = 2026; year >= 2020; year--) _memory(year)],
    );

    testWidgets('dörtten uzun liste KISALIYOR', (tester) async {
      await pumpDetail(tester, ritual: longSeries());

      expect(
        find.byType(RitualMemoryRow),
        findsNWidgets(RitualDetailView.kCollapsedCount),
      );
      expect(find.text('Tümünü Gör'), findsOneWidget);
    });

    testWidgets('"Tümünü Gör" listeyi YERİNDE açıyor', (tester) async {
      // Ayrı sayfa açmıyor: kapak ve sayılar yukarıda kalmalı, "yedi anıdan
      // dördünü görüyorum" bilgisini veren şey onlar.
      await pumpDetail(tester, ritual: longSeries());

      await tester.tap(find.text('Tümünü Gör'));
      await settle(tester);

      // Aynı ekrandayız.
      expect(find.byType(RitualDetailCover), findsOneWidget);
      expect(find.text('Daha Az Göster'), findsOneWidget);
      // Kısaltmadan fazlası çizildi (kalanlar kaydırınca geliyor).
      expect(
        find.byType(RitualMemoryRow, skipOffstage: false).evaluate().length,
        greaterThan(RitualDetailView.kCollapsedCount),
      );
    });

    testWidgets('kısa listede düğme HİÇ YOK', (tester) async {
      // Hiçbir şey açmayan bir düğme, kullanıcıyı bir şey kaçırdığına
      // inandırıyordu.
      await pumpDetail(tester);

      expect(find.text('Tümünü Gör'), findsNothing);
      expect(find.text('Daha Az Göster'), findsNothing);
    });
  });

  group('üç nokta menüsü', () {
    testWidgets('düzenle ve sil çıkıyor, sil SONDA ve kırmızı', (tester) async {
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Seri işlemleri'));
      await settle(tester);

      final edit = tester.getCenter(find.text('Seriyi Düzenle'));
      final delete = tester.getCenter(find.text('Seriyi Sil'));
      expect(delete.dy, greaterThan(edit.dy));

      final deleteText = tester.widget<Text>(find.text('Seriyi Sil'));
      final editText = tester.widget<Text>(find.text('Seriyi Düzenle'));
      expect(deleteText.style!.color, isNot(editText.style!.color));
    });

    testWidgets('silme ONAY istiyor ve anıların kalacağını söylüyor', (
      tester,
    ) async {
      // Kişi silmedeki sözle aynı: bir KABI silmek içindekini silmiyor.
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Seri işlemleri'));
      await settle(tester);
      await tester.tap(find.text('Seriyi Sil'));
      await settle(tester);

      expect(find.text('Seri silinsin mi?'), findsOneWidget);
      expect(find.textContaining('anılar silinmez'), findsOneWidget);
    });

    testWidgets('onay başlığı AÇIKLAMAYLA aynı yazı tipinde', (tester) async {
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Seri işlemleri'));
      await settle(tester);
      await tester.tap(find.text('Seriyi Sil'));
      await settle(tester);

      String fontOf(String text) => tester
          .renderObject<RenderParagraph>(find.text(text))
          .text
          .style!
          .fontFamily!;

      expect(fontOf('Seri silinsin mi?'), 'Poppins');
    });
  });

  group('alt çubuk', () {
    testWidgets('duruyor ve hiçbir sekme vurgulanmıyor', (tester) async {
      // Anı ve kişi detaylarıyla aynı karar: kullanıcı bir seriye bakarken
      // uygulamanın dışına düşmüş gibi hissetmemeli, ama bir sekmede de değil.
      await pumpDetail(tester);

      final nav = tester.widget<IzBottomNav>(find.byType(IzBottomNav));
      expect(nav.currentIndex, IzBottomNav.noSelection);
      expect(find.text('Ana Sayfa'), findsOneWidget);
    });
  });

  group('dayanıklılık', () {
    testWidgets('seri bulunamazsa çökmüyor', (tester) async {
      await pumpDetail(
        tester,
        ritual: (
          id: '',
          title: '',
          cover: null,
          memories: <RitualDetailMemory>[],
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('2x yazı ölçeğinde taşma yok', (tester) async {
      // Üç kutu yan yana ve içlerinde iki satır var: ölçek büyüyünce ilk
      // kırılacak yer burası.
      await pumpDetail(tester, textScale: 2);

      expect(tester.takeException(), isNull);
    });

    testWidgets('küçük ekranda taşma yok', (tester) async {
      await pumpDetail(tester, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
    });
  });
}
