/// Ana sayfa düzen testleri.
///
/// Bu ekranın tasarımı bir FOTOĞRAFIN ÜZERİNE BİNEN kavisli panele dayanıyor.
/// Düzen tamamen ölçüye bağlı olduğu için gözle kontrol yetmez: burada
/// geometriyi sayı sayı doğruluyoruz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/home/presentation/views/home_view.dart';
import 'package:iz/features/home/presentation/widgets/glass_pill_button.dart';
import 'package:iz/features/home/presentation/widgets/home_hero_overlay.dart';
import 'package:iz/features/home/presentation/widgets/home_top_bar.dart';
import 'package:iz/features/home/presentation/widgets/memory_row_card.dart';
import 'package:iz/shared/widgets/curved_top_panel.dart';
import 'package:iz/shared/widgets/iz_wordmark.dart';

import '../helpers/real_fonts.dart';

/// Verilen ekran ölçüsünde ana sayfayı kurar.
Future<void> pumpHome(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool dark = false,
  double statusBar = 0,
  // Testlerin çoğu BOŞ hâli sınıyor; dolu hâl açıkça isteniyor.
  bool hasMemories = false,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0
    ..padding = FakeViewPadding(top: statusBar)
    ..viewPadding = FakeViewPadding(top: statusBar);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: HomeView(hasMemories: hasMemories),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Logo ölçüleri Figma ile karşılaştırılıyor; yedek fontla ölçüm sapar.
    await loadRealFonts();
  });
  group('CurvedTopPanel', () {
    test('yay yüksekliği genişlikle orantılı, ama sınırlı', () {
      // Telefon: oranla hesaplanır.
      expect(CurvedTopPanel.curveHeightFor(390), closeTo(66.5, 0.5));

      // Çok dar ekran alt sınıra, çok geniş ekran üst sınıra takılmalı;
      // yoksa tablette dev bir kavis, saatte hiç kavis olmayan bir çizgi
      // ortaya çıkardı.
      expect(
        CurvedTopPanel.curveHeightFor(120),
        CurvedTopPanel.curveHeightFor(200),
      );
      expect(
        CurvedTopPanel.curveHeightFor(1400),
        CurvedTopPanel.curveHeightFor(900),
      );
    });
  });

  group('HomeView', () {
    testWidgets('panel ekranın TAM genişliğini kaplar', (tester) async {
      // REGRESYON: Stack, konumlandırılmamış çocuğuna gevşek kısıt verir.
      // İçerik boşken panel kendini 0 genişlikte ölçüyor ve yay hiç
      // görünmüyordu. Bu test o hatayı bir daha geçirmez.
      await pumpHome(tester);

      final panel = tester.getRect(find.byType(CurvedTopPanel));
      expect(panel.width, 390);
    });

    testWidgets('panel görselin üzerine yay boyu kadar biner', (tester) async {
      await pumpHome(tester);

      final image = tester.getRect(find.byType(Image).first);
      final panel = tester.getRect(find.byType(CurvedTopPanel));
      final curve = CurvedTopPanel.curveHeightFor(390);

      // Kavisin EN YÜKSEK noktası (sağ uç) görselin bittiği yerden tam
      // `curve` kadar yukarıda olmalı; böylece en alçak nokta (sol uç)
      // görselin alt kenarına denk gelir ve solda boşluk kalmaz.
      expect(panel.top, closeTo(image.bottom - curve, 0.01));
    });

    testWidgets('panel en az sayfa sonuna kadar uzar', (tester) async {
      await pumpHome(tester);

      // İçerik eklendikçe panel ekrandan TAŞABİLİR (sayfa kaydırılır);
      // olmaması gereken şey panelin ekranın dibine YETİŞEMEMESİ — o zaman
      // altında scaffold zemini görünürdü.
      expect(
        tester.getRect(find.byType(CurvedTopPanel)).bottom,
        greaterThanOrEqualTo(844),
      );
    });

    for (final size in const [
      Size(320, 568), // en küçük telefon
      Size(390, 844), // referans
      Size(430, 932), // büyük telefon
      Size(600, 1024), // küçük tablet
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} taşmaz', (
        tester,
      ) async {
        await pumpHome(tester, size: size);
        expect(tester.takeException(), isNull);

        final panel = tester.getRect(find.byType(CurvedTopPanel));
        expect(panel.width, size.width);
        // Görsel alanı hiçbir ölçüde ekranın yarısını geçmemeli, yoksa
        // içeriğe yer kalmaz.
        expect(
          tester.getRect(find.byType(Image).first).height,
          lessThan(size.height / 2),
        );
      });
    }

    testWidgets('koyu temada da çizilir', (tester) async {
      await pumpHome(tester, dark: true);
      expect(tester.takeException(), isNull);
      expect(find.byType(CurvedTopPanel), findsOneWidget);
    });
  });

  /// FİGMA ÖLÇÜLERİ (390 genişlikte çerçeve):
  ///   şerit → left 20, top 36, width 350, height 40, space-between
  ///   "İZ"  → 46 × 44
  group('HomeTopBar', () {
    testWidgets('marka solda 20, zil sağda 20 px içeride', (tester) async {
      await pumpHome(tester);

      expect(tester.getRect(find.byType(IzWordmark)).left, 20);
      // 390 − 20 = 370. `space-between` düzeninin sağ ucu.
      expect(tester.getRect(find.byType(Icon).first).right, 370);
    });

    testWidgets('"İZ" kutusu tasarım ölçüsünde', (tester) async {
      await pumpHome(tester);

      final mark = tester.getRect(find.byType(IzWordmark));
      // Yükseklik TAM olmalı: `height: 1` sayesinde punto = kutu yüksekliği.
      // Figma 44 diyordu, ekranda küçük kaldığı için 60'a çıkarıldı.
      expect(mark.height, HomeTopBar.kWordmarkSize);
      // Genişlik puntoyla TAM orantılı büyümez: harf aralığı (2 px) sabit,
      // punto değişince oran hafifçe kayar. Figma'nın 46/44 oranına yakın
      // olması yeter.
      expect(mark.width, closeTo(46 / 44 * HomeTopBar.kWordmarkSize, 3));
    });

    testWidgets('şeridin dikey merkezi Figma ile aynı', (tester) async {
      await pumpHome(tester);

      // Figma: top 36 + height 40 → merkez 56. Bizim satırımız 48 yüksekliğinde
      // (dokunma hedefi), o yüzden hizayı merkezden kuruyoruz. Satırı 36'dan
      // başlatsaydık her şey 4 px aşağıda dururdu.
      final mark = tester.getRect(find.byType(IzWordmark));
      expect(mark.center.dy, closeTo(56, 0.5));
    });

    testWidgets('durum çubuğu varsa şerit onun altına iner', (tester) async {
      await pumpHome(tester, statusBar: 47);

      // Fotoğraf tam ekran; şerit sabit 36'da kalsaydı saat ve pil logonun
      // üstüne binerdi.
      expect(tester.getRect(find.byType(IzWordmark)).top, greaterThan(47));
    });

    testWidgets('zil dokunulabilir ve ekran okuyucuya tanıtılmış', (
      tester,
    ) async {
      await pumpHome(tester);

      final button = find.byType(IconButton);
      expect(button, findsOneWidget);
      // NFR-032 — 48×48 asgari dokunma hedefi.
      final rect = tester.getRect(button);
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(tester.widget<IconButton>(button).tooltip, 'Bildirimler');

      // TIKLANABİLİR olmalı. `onPressed: null` bırakılsaydı buton devre dışı
      // kalır, dokunmaya hiç tepki vermezdi.
      expect(tester.widget<IconButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pump();
      // Bildirim ekranı yok; şimdilik "yakında" bildirimi çıkıyor.
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('logo büyürken zil arayüz ölçeğinde kalır', (tester) async {
      await pumpHome(tester);

      // Marka öne çıksın diye logo Figma'nın üstüne çıkarıldı; ikon
      // ölçeği (28) tüm uygulamada ortak, onunla birlikte büyümemeli.
      final icon = tester.widget<Icon>(find.byType(Icon).first);
      expect(icon.size, 28);
      expect(
        tester.getRect(find.byType(IzWordmark)).height,
        greaterThan(icon.size!),
      );
    });

    testWidgets('profil dairesi YOK', (tester) async {
      await pumpHome(tester);

      // Referans tasarımda logonun sağında bir avatar vardı; istenmedi.
      // Şeritte yalnızca iki öğe olmalı.
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.byType(IconButton), findsOneWidget);
    });

    for (final width in [320.0, 390.0, 430.0, 600.0]) {
      testWidgets('${width.toInt()} px genişlikte kenar boşlukları korunur', (
        tester,
      ) async {
        await pumpHome(tester, size: Size(width, 844));

        // Kenar boşluğu bir MARJDIR, ölçekleyecek bir şey değil: her ekranda
        // 20 px. Ekran büyüdükçe aradaki boşluk büyür, kenarlar sabit kalır.
        expect(tester.getRect(find.byType(IzWordmark)).left, 20);
        expect(tester.getRect(find.byType(Icon).first).right, width - 20);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('şerit her zaman görselin üzerinde kalır', (tester) async {
      await pumpHome(tester);

      // Şerit fotoğrafın DIŞINA taşarsa beyaz metin krem panelde kaybolur.
      final heroBottom = tester.getRect(find.byType(Image).first).bottom;
      expect(
        tester.getRect(find.byType(HomeTopBar)).bottom,
        lessThan(heroBottom),
      );
    });
  });

  /// FOTOĞRAF ÜZERİNDEKİ METİN BLOĞU (boş durum).
  ///
  /// Kullanıcının henüz anısı yokken gösterilen hâl. Backend gelince yanına
  /// "bugünün izi" varyantı eklenecek; bu blok silinmeyecek, çünkü her yeni
  /// kullanıcı önce burayı görüyor.
  group('kahraman boş durumu', () {
    testWidgets('başlık ve Anı Ekle butonu görünür', (tester) async {
      await pumpHome(tester);

      expect(find.text('İlk İzini Bırak'), findsOneWidget);
      expect(
        find.text('Hatırlamak isteyeceğin bir anı seç ve sakla.'),
        findsOneWidget,
      );
      // Fotoğrafın üzerindeki cam buton. Aşağıdaki "SON ANILAR" boş durumu
      // da aynı etiketi taşıyor, o yüzden TİPE göre arıyoruz.
      expect(find.byType(GlassPillButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GlassPillButton),
          matching: find.text('Anı Ekle'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sıra: başlık → açıklama → buton', (tester) async {
      await pumpHome(tester);

      final title = tester.getRect(find.text('İlk İzini Bırak'));
      final subtitle = tester.getRect(
        find.text('Hatırlamak isteyeceğin bir anı seç ve sakla.'),
      );
      final button = tester.getRect(find.byType(GlassPillButton));

      expect(subtitle.top, greaterThanOrEqualTo(title.bottom));
      expect(button.top, greaterThanOrEqualTo(subtitle.bottom));
    });

    testWidgets('açıklama başlıktan küçük puntoda', (tester) async {
      await pumpHome(tester);

      double sizeOf(String text) =>
          tester.widget<Text>(find.text(text)).style!.fontSize!;

      expect(
        sizeOf('Hatırlamak isteyeceğin bir anı seç ve sakla.'),
        lessThan(sizeOf('İlk İzini Bırak')),
      );
    });

    testWidgets('başlık ve buton sol kenardan 20 px içeride', (tester) async {
      await pumpHome(tester);

      expect(tester.getRect(find.text('İlk İzini Bırak')).left, 20);
      expect(tester.getRect(find.byType(GlassPillButton)).left, 20);
    });

    testWidgets('buton fotoğrafın alt kenarına Figma mesafesinde', (
      tester,
    ) async {
      await pumpHome(tester);

      // Blok fotoğrafın altına en az bu kadar mesafede durmalı; daha
      // yakınında kavis metni yutuyor. Figma'daki 55, DOLU varyantın
      // (iki satır başlık) alt sınırı — boş durumda içerik kısa olduğu
      // için mesafe artar.
      final button = tester.getRect(find.byType(GlassPillButton));
      final heroBottom = tester.getRect(find.byType(Image).first).bottom;
      final visualBottom = button.bottom - GlassPillButton.kTapPadding;

      expect(heroBottom - visualBottom, greaterThanOrEqualTo(55));
    });

    testWidgets('açıklama İKİ SATIR', (tester) async {
      await pumpHome(tester);

      // Tek satıra sığsaydı cümle fotoğrafı boydan boya keserdi; metin
      // sütununun genişliği sarmayı üretiyor.
      final subtitle = tester.getRect(
        find.text('Hatırlamak isteyeceğin bir anı seç ve sakla.'),
      );
      final oneLine = tester
          .renderObject<RenderBox>(
            find.text('Hatırlamak isteyeceğin bir anı seç ve sakla.'),
          )
          .getMaxIntrinsicWidth(double.infinity);
      expect(subtitle.width, lessThan(oneLine));
      // İki satır: yükseklik tek satırın iki katı kadar.
      expect(subtitle.height, closeTo(48, 2));
    });

    testWidgets('zilin dalga efekti ikonun ortasından çıkar', (tester) async {
      await pumpHome(tester);

      // REGRESYON: ikon 48'lik dokunma kutusunun SAĞINA yaslanınca dalga
      // kutunun ortasından, yani ikonun 10 px solundan çıkıyordu ve
      // tıklayınca kayık görünüyordu.
      final button = tester.getRect(find.byType(IconButton));
      final icon = tester.getRect(find.byType(Icon).first);
      expect(button.center.dx, closeTo(icon.center.dx, 0.5));

      // Kaydırmaya rağmen ikonun görsel sağ kenarı yine 20 px içeride.
      expect(icon.right, 370);
    });

    testWidgets('açıklama ile buton arası 24', (tester) async {
      await pumpHome(tester);

      // Figma 8 diyordu; metin bir BLOK, buton ayrı bir EYLEM — aradaki
      // nefes satır arasından (8) belirgin şekilde büyük olmalı.
      // `getRect` butonun GÖRÜNMEZ dokunma payını da sayar, onu düşüyoruz.
      final subtitle = tester.getRect(
        find.text('Hatırlamak isteyeceğin bir anı seç ve sakla.'),
      );
      final button = tester.getRect(find.byType(GlassPillButton));
      final visualTop = button.top + GlassPillButton.kTapPadding;

      expect(visualTop - subtitle.bottom, closeTo(24, 0.5));
    });

    testWidgets('blok tasarımdaki 125 noktasından başlar', (tester) async {
      await pumpHome(tester, statusBar: 47);

      // REGRESYON: bloğu da durum çubuğu kadar aşağı kaydırdığımızda dolu
      // varyant tasarım ölçüsünde bile sığmayıp küçülüyordu. Şerit çubuğun
      // altına iner, blok yerinde kalır.
      // Üst başlık boş durumda çizilmez ama yer kaplar; bloğun üst kenarı
      // bu yüzden başlığın değil, o görünmez satırın üstü.
      final block = tester.getRect(find.byType(Visibility));
      expect(block.top, closeTo(125, 0.5));
    });

    testWidgets('butonun görünen boyu 36, dokunma alanı 48', (tester) async {
      await pumpHome(tester);

      // NFR-032: tasarımdaki 36 parmak için küçük. `tapTargetSize: padded`
      // görünümü bozmadan dokunma alanını büyütüyor.
      final rect = tester.getRect(find.byType(GlassPillButton));
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(GlassPillButton.kHeight, 36);
    });

    testWidgets('buton bir eyleme bağlı', (tester) async {
      await pumpHome(tester);

      // `onPressed: null` bırakılsaydı buton devre dışı kalırdı.
      // Nereye gittiği burada denenmiyor: bu kurulumda GoRouter yok.
      // Gerçek yönlendirme `app_smoke_test.dart` içinde, tam uygulamayla
      // sınanıyor — orası zincirin tamamını kuruyor.
      expect(
        tester.widget<GlassPillButton>(find.byType(GlassPillButton)).onPressed,
        isNotNull,
      );
    });

    for (final size in const [
      Size(320, 568), // en küçük telefon — en dar durum
      Size(390, 844),
      Size(430, 932),
      Size(600, 1024),
    ]) {
      for (final statusBar in [0.0, 47.0]) {
        testWidgets('${size.width.toInt()}x${size.height.toInt()} '
            'durumÇubuğu=${statusBar.toInt()} — çakışma yok', (tester) async {
          await pumpHome(tester, size: size, statusBar: statusBar);
          expect(tester.takeException(), isNull);

          // Metin bloğu üst şeridin ALTINDA kalmalı. Kısa telefonda
          // fotoğraf 240 px'e iniyor; sabit ölçülerle bu ikisi üst üste
          // biniyordu.
          final strip = tester.getRect(find.byType(HomeTopBar));
          final title = tester.getRect(find.text('İlk İzini Bırak'));
          expect(title.top, greaterThanOrEqualTo(strip.bottom));

          // Blok fotoğrafın DIŞINA taşarsa beyaz metin krem panelde kaybolur.
          final heroBottom = tester.getRect(find.byType(Image).first).bottom;
          final button = tester.getRect(find.byType(GlassPillButton));
          expect(button.bottom, lessThan(heroBottom));
        });
      }
    }

    testWidgets('katman fotoğrafın tamamını kaplar', (tester) async {
      await pumpHome(tester);

      // REGRESYON: `StackFit.expand` olmadan katman kendi içeriği kadar
      // küçülür, aşağıdan hizalama çalışmaz ve blok yukarı fırlar.
      final overlay = tester.getRect(find.byType(HomeHeroOverlay));
      final hero = tester.getRect(find.byType(Image).first);
      expect(overlay, hero);
    });
  });

  /// EKRANIN DOLU HÂLİ — kullanıcının anıları varken.
  ///
  /// `hasMemories` açıkken hem fotoğrafın üzerindeki blok hem de "SON
  /// ANILAR" listesi dolu varyanta geçer. İkisinin BİRLİKTE değişmesi
  /// önemli: biri dolu öteki boş kalırsa ekran kendisiyle çelişir.
  group('ekranın dolu hâli', () {
    testWidgets('kahraman ve liste birlikte dolu olur', (tester) async {
      await pumpHome(tester, hasMemories: true);

      // Fotoğrafın üzerinde "bugünün izi".
      expect(find.text('BUGÜNÜN İZİ'), findsOneWidget);
      expect(find.text('İlk İzini Bırak'), findsNothing);

      // Aşağıda üç anı kartı ve "Tümünü Gör".
      expect(find.byType(MemoryRowCard), findsNWidgets(3));
      expect(find.text('Tümünü Gör'), findsOneWidget);
      expect(find.text('Burada henüz bir iz yok.'), findsNothing);
    });

    testWidgets('boş hâlde liste yerine boş durum gelir', (tester) async {
      await pumpHome(tester);

      expect(find.byType(MemoryRowCard), findsNothing);
      // Gösterilecek bir şey yokken "Tümünü Gör" anlamsız.
      expect(find.text('Tümünü Gör'), findsNothing);
      expect(find.text('Burada henüz bir iz yok.'), findsOneWidget);
    });

    testWidgets('anı kartları Figma hizasında', (tester) async {
      await pumpHome(tester, hasMemories: true);

      // Kart 350 geniş, ekranın iki yanından 20 içeride.
      final card = tester.getRect(find.byType(MemoryRowCard).first);
      expect(card.left, 20);
      expect(card.width, 350);

      // Figma: kartlar 12 aralıklı → tepeler 80 px arayla.
      final second = tester.getRect(find.byType(MemoryRowCard).at(1));
      expect(second.top - card.top, closeTo(80, 1));
    });
  });

  /// DOLU VARYANT — kullanıcının anısı olduğunda.
  ///
  /// Henüz ekranda gösterilmiyor (veri kaynağı bağlı değil) ama tasarımı
  /// hazır: `HeroMemory` verildiğinde çiziliyor. Testler bu sözleşmenin
  /// bozulmadan durduğunu garanti ediyor.
  group('kahraman dolu durumu', () {
    const memory = (
      id: 'test-hero',
      title: 'İlk İzmir Tatilimiz',
      dateLabel: '1 hafta önce',
    );

    Future<void> pumpFilled(
      WidgetTester tester, {
      Size size = const Size(390, 844),
      double statusBar = 47,
    }) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1.0
        ..padding = FakeViewPadding(top: statusBar)
        ..viewPadding = FakeViewPadding(top: statusBar);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('tr'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: HomeView.heroHeightFor(size.height),
              width: size.width,
              child: const Stack(
                fit: StackFit.expand,
                children: [
                  HomeHeroOverlay(
                    memory: memory,
                    onAddMemory: _noop,
                    onViewMemory: _noop,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('üst başlık, başlık, tarih ve Anıyı Gör görünür', (
      tester,
    ) async {
      await pumpFilled(tester);

      expect(find.text('BUGÜNÜN İZİ'), findsOneWidget);
      expect(find.text('İlk İzmir Tatilimiz'), findsOneWidget);
      expect(find.text('1 hafta önce'), findsOneWidget);
      expect(find.text('Anıyı Gör'), findsOneWidget);
      // Boş durumun metinleri OLMAMALI.
      expect(find.text('İlk İzini Bırak'), findsNothing);
      expect(
        find.text('Hatırlamak isteyeceğin bir anı seç ve sakla.'),
        findsNothing,
      );
      expect(find.text('Anı Ekle'), findsNothing);
    });

    testWidgets('iki varyant aynı ölçülerde, tek fark ikinci satır', (
      tester,
    ) async {
      await pumpFilled(tester);
      final filledTitle = tester.getRect(find.text('İlk İzmir Tatilimiz'));
      final filledButton = tester.getRect(find.byType(GlassPillButton));

      await pumpHome(tester, statusBar: 47);
      final emptyTitle = tester.getRect(find.text('İlk İzini Bırak'));
      final emptyButton = tester.getRect(find.byType(GlassPillButton));

      // İki varyant aynı iskeleti paylaşıyor: üst başlık (boş durumda
      // çizilmez ama yer kaplar) / başlık / ikincil satır / buton.
      // Başlıklar aynı yerden başlar, butonlar aynı boydadır; tek fark
      // dolu varyanttaki başlığın BİR SATIR daha uzun olması.
      expect(emptyTitle.top, closeTo(filledTitle.top, 0.5));
      expect(emptyButton.height, filledButton.height);
      // Dolu başlık TAM BİR SATIR uzun. Satır yüksekliğini sabit yazmak
      // yerine boş varyantın tek satırından ölçüyoruz: punto değişse bile
      // test doğru kalır.
      expect(filledTitle.height, closeTo(emptyTitle.height * 2, 1));
    });

    /// TASARIM ÖLÇÜLERİ.
    ///
    /// Figma'dan BİREBİR alınanlar: bloğun başlangıcı (left 20, top 125),
    /// satır arası 8, üst başlığın puntosu (Poppins 10/18) ve başlığın iki
    /// satıra sarması (2 × 36).
    ///
    /// BİLEREK BÜYÜTÜLENLER: ikincil satır (12 yerine 14) ve buton yazısı
    /// (10 yerine 14). Figma değerleri fotoğrafın üzerinde okunmuyordu ve
    /// buton dokunulabilir görünmüyordu. Bu yüzden buton da tasarımdaki
    /// 255 yerine daha aşağıda; test o sapmayı SABİTLİYOR ki kazara
    /// değişmesin.
    testWidgets('tasarım ölçüleri tutuyor', (tester) async {
      await pumpFilled(tester);

      Rect r(String text) => tester.getRect(find.text(text));

      // Blok tam 125'te başlıyor, sol kenardan 20 içeride.
      expect(r('BUGÜNÜN İZİ').left, 20);
      expect(r('BUGÜNÜN İZİ').top, closeTo(125, 0.5));
      // Poppins 10/18 — Figma birebir.
      expect(r('BUGÜNÜN İZİ').height, 18);
      expect(r('BUGÜNÜN İZİ').width, closeTo(62, 2));

      // Başlık İKİ SATIR. Tek satıra kalsaydı fotoğrafı boydan boya
      // keserdi — sütun genişliği bu sarmayı üretiyor.
      final title = tester.renderObject<RenderBox>(
        find.text('İlk İzmir Tatilimiz'),
      );
      expect(
        r('İlk İzmir Tatilimiz').width,
        lessThan(title.getMaxIntrinsicWidth(double.infinity)),
      );
      // Başlık Display 36 → satır yüksekliği 44 (punto + 8), iki satır 88.
      // Sabit yazmak yerine kuraldan türetiyoruz: punto değişirse test de
      // kendiliğinden doğru kalır.
      const titleSize = 36.0;
      expect(r('İlk İzmir Tatilimiz').height, closeTo(2 * (titleSize + 8), 2));

      // Buton, boş varyanttakiyle AYNI boyda olmalı. Bir ara Figma'nın 10
      // puntosunu uygulayınca burası küçülmüş, iki varyant birbirini
      // tutmaz olmuştu.
      final button = tester.getRect(find.byType(GlassPillButton));
      expect(button.left, 20);
      expect(
        button.height - 2 * GlassPillButton.kTapPadding,
        GlassPillButton.kHeight,
      );

      // Blok fotoğrafın içinde kalmalı ve KÜÇÜLMEDEN çizilmeli.
      expect(tester.takeException(), isNull);
    });

    testWidgets('üst başlık büyük harfle geliyor (çeviriden)', (tester) async {
      await pumpFilled(tester);

      // Dart'ın `toUpperCase()` metodu dile duyarsızdır ve Türkçe 'i'
      // harfini 'I' yapar ("BUGUNUN IZI"). Bu yüzden büyük harf çeviride.
      expect(find.text('BUGÜNÜN İZİ'), findsOneWidget);
      expect(find.text('BUGÜNÜN IZI'), findsNothing);
    });

    for (final size in const [Size(320, 568), Size(390, 844), Size(430, 932)]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} taşmaz', (
        tester,
      ) async {
        await pumpFilled(tester, size: size);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

void _noop() {}
