/// Yeni ritüel formu — FR-075.
///
/// EKRANIN SÖZLERİ:
///   • kapak alanına dokunmak galeriyi açar, seçilen fotoğraf çizimin yerine
///     geçer
///   • tekrarlama / kişiler / kategori AŞAĞI doğru açılır ve aynı anda YALNIZCA
///     BİRİ açık kalır
///   • tekrarlama üç seçenek sunar: yıl, ay, hafta
///   • TARİH ALANI YOK — aralık seçilen anılardan türetilir
///   • ad boşsa oluşturmaz
///
/// Anı seçme ekranı ve "Serilerim"de görünme uçtan uca
/// `memory_navigation_test.dart`ta: ikisi de gerçek rota gerektiriyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/media/media_picker.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/rituals/presentation/view_models/created_rituals_view_model.dart';
import 'package:iz/features/rituals/presentation/views/ritual_editor_view.dart';
import 'package:iz/shared/widgets/iz_cover_illustration.dart';
import 'package:iz/shared/widgets/iz_cover_picker.dart';
import 'package:iz/shared/widgets/iz_form_row.dart';
import 'package:iz/shared/widgets/media_thumbnail.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_media_picker.dart';
import '../helpers/real_fonts.dart';

late ProviderContainer container;

Future<void> pumpForm(
  WidgetTester tester, {
  List<String> pickerReturns = const [],
  double textScale = 1,
  Size size = const Size(390, 940),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  container = ProviderContainer(
    overrides: [
      mediaPickerProvider.overrideWithValue(
        FakeMediaPicker(paths: pickerReturns),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        // ROUTER'LI: ekran oluşturduktan sonra kendini kapatıyor
        // (`context.pop`) ve o çağrı bir `GoRouter` arıyor.
        routerConfig: GoRouter(
          initialLocation: '/new',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, _) => const RitualEditorView(),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  await settle(tester);
}

/// Bir satırı açar.
Future<void> openSection(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settle(tester);
}

void main() {
  setUpAll(loadRealFonts);

  group('yerleşim', () {
    testWidgets('kapak, altı satır ve oluştur düğmesi duruyor', (tester) async {
      await pumpForm(tester);

      expect(find.byType(IzCoverPicker), findsOneWidget);
      expect(find.text('Kapak Görseli Ekle'), findsOneWidget);

      for (final label in [
        'Seri Adı',
        'Açıklama',
        'Tekrarlama',
        'İlgili Kişiler',
        'Kategori',
        'Bu Yıla Anı Ekle',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      expect(find.text('Seriyi Oluştur'), findsOneWidget);
    });

    testWidgets('TARİH SATIRI YOK', (tester) async {
      // Kullanıcının kararı: ritüelin tarihi anılardan gelir. Referansta bir
      // "Başlangıç Tarihi" satırı vardı; geri gelmesi sessiz bir gerileme.
      await pumpForm(tester);

      expect(find.textContaining('Tarih seç'), findsNothing);
      expect(find.textContaining('Başlangıç'), findsNothing);
      expect(find.byIcon(AppIcons.date), findsNothing);
    });

    testWidgets('tekrarlama "Her yıl" ile geliyor', (tester) async {
      // Ritüellerin çoğu yıllık; boş bırakmak kullanıcıyı zorunlu bir karara
      // sokardı.
      await pumpForm(tester);

      expect(find.text('Her yıl'), findsOneWidget);
    });

    testWidgets('başlangıçta hiçbir satır açık değil', (tester) async {
      await pumpForm(tester);

      // Seçenekler görünmüyor.
      expect(find.text('Her hafta'), findsNothing);
      expect(find.text('Annem'), findsNothing);
    });
  });

  group('kapak görseli', () {
    testWidgets('kutuya dokunmak galeriyi açıp fotoğrafı koyuyor', (
      tester,
    ) async {
      // Yalnızca "+" değil TÜM ALAN tıklanabilir olmalı: kişi formunda
      // "Fotoğraf Ekle" yazısının tıklanamadığını bir testte yakaladık.
      await pumpForm(tester, pickerReturns: ['/tmp/kapak.jpg']);

      await tester.tap(find.text('Kapak Görseli Ekle'));
      await settle(tester);

      final picker = tester.widget<IzCoverPicker>(find.byType(IzCoverPicker));
      expect(picker.cover?.localPreviewPath, '/tmp/kapak.jpg');
      // Çizim gitti, fotoğraf geldi.
      expect(find.byType(IzCoverIllustration), findsNothing);
      expect(find.byType(MediaThumbnail), findsOneWidget);
    });

    testWidgets('fotoğraf seçilince metin "Değiştir" oluyor', (tester) async {
      await pumpForm(tester, pickerReturns: ['/tmp/kapak.jpg']);

      await tester.tap(find.byIcon(AppIcons.add));
      await settle(tester);

      expect(find.text('Kapak Görselini Değiştir'), findsOneWidget);
      expect(find.text('Kapak Görseli Ekle'), findsNothing);
    });

    testWidgets('kullanıcı vazgeçerse çizim kalıyor', (tester) async {
      // Boş dönüş bir hata değil, bir karar.
      await pumpForm(tester);

      await tester.tap(find.byIcon(AppIcons.add));
      await settle(tester);

      expect(find.byType(IzCoverIllustration), findsOneWidget);
    });
  });

  group('tekrarlama', () {
    testWidgets('üç seçenek sunuyor: yıl, ay, hafta', (tester) async {
      await pumpForm(tester);
      await openSection(tester, 'Tekrarlama');

      // "Her yıl" hem satırın değeri hem seçenek olarak var.
      expect(find.text('Her yıl'), findsNWidgets(2));
      expect(find.text('Her ay'), findsOneWidget);
      expect(find.text('Her hafta'), findsOneWidget);
    });

    testWidgets('seçim satırın değerine yazılıyor ve satır KAPANIYOR', (
      tester,
    ) async {
      // Tek seçimde kullanıcının orada işi bitti.
      await pumpForm(tester);
      await openSection(tester, 'Tekrarlama');
      await tester.tap(find.text('Her ay'));
      await settle(tester);

      expect(find.text('Her ay'), findsOneWidget);
      expect(find.text('Her hafta'), findsNothing);
    });

    testWidgets('açık satıra tekrar dokunmak kapatıyor', (tester) async {
      await pumpForm(tester);
      await openSection(tester, 'Tekrarlama');
      expect(find.text('Her hafta'), findsOneWidget);

      await openSection(tester, 'Tekrarlama');
      expect(find.text('Her hafta'), findsNothing);
    });
  });

  group('ilgili kişiler', () {
    testWidgets('kişilerim listeleniyor', (tester) async {
      await pumpForm(tester);
      await openSection(tester, 'İlgili Kişiler');

      expect(find.text('Annem'), findsOneWidget);
      expect(find.text('Babam'), findsOneWidget);
    });

    testWidgets('ÇOK seçim: satır açık kalıyor, adlar birleşiyor', (
      tester,
    ) async {
      // Bir ritüel birden fazla kişiyle paylaşılıyor (aile yemeği).
      await pumpForm(tester);
      await openSection(tester, 'İlgili Kişiler');

      await tester.tap(find.text('Annem'));
      await settle(tester);
      await tester.tap(find.text('Babam'));
      await settle(tester);

      // Liste hâlâ açık.
      expect(find.text('Elif'), findsOneWidget);
      // Satırın değeri iki adı taşıyor.
      expect(find.text('Annem, Babam'), findsOneWidget);
    });

    testWidgets('tekrar dokunmak seçimi kaldırıyor', (tester) async {
      await pumpForm(tester);
      await openSection(tester, 'İlgili Kişiler');

      await tester.tap(find.text('Annem'));
      await settle(tester);
      await tester.tap(find.text('Annem').last);
      await settle(tester);

      expect(find.text('Kişi ekle'), findsOneWidget);
    });
  });

  group('kategori', () {
    testWidgets('sistem kategorileri listeleniyor ve seçiliyor', (
      tester,
    ) async {
      await pumpForm(tester);
      await openSection(tester, 'Kategori');

      // Sistem kategorileri kodda tanımlı, uydurma değil.
      expect(find.text('Aile'), findsWidgets);

      await tester.tap(find.text('Aile').first);
      await settle(tester);

      expect(find.text('Kategori seç'), findsNothing);
    });

    testWidgets('aynısına tekrar dokunmak seçimi kaldırıyor', (tester) async {
      // Kategori zorunlu değil; yanlış seçenin geri dönüş yolu olmalı.
      await pumpForm(tester);
      await openSection(tester, 'Kategori');
      await tester.tap(find.text('Aile').first);
      await settle(tester);

      await openSection(tester, 'Kategori');
      await tester.tap(find.text('Aile').last);
      await settle(tester);

      expect(find.text('Kategori seç'), findsOneWidget);
    });
  });

  group('akordeon: aynı anda tek satır', () {
    testWidgets('ikinciyi açmak birinciyi kapatıyor', (tester) async {
      // Hepsi birden açılabilse form üç ekran boyu uzayıp "Oluştur" düğmesi
      // görünmez oluyordu.
      await pumpForm(tester);
      await openSection(tester, 'Tekrarlama');
      expect(find.text('Her hafta'), findsOneWidget);

      await openSection(tester, 'İlgili Kişiler');

      expect(find.text('Her hafta'), findsNothing);
      expect(find.text('Annem'), findsOneWidget);
    });
  });

  group('oluşturma', () {
    testWidgets('ad boşsa uyarıyor ve oluşturmuyor', (tester) async {
      await pumpForm(tester);

      await tester.tap(find.text('Seriyi Oluştur'));
      await settle(tester);

      expect(find.text('Bir isim yazmadan oluşturamayız.'), findsOneWidget);
      expect(container.read(createdRitualsProvider), isEmpty);
      // Ekran kapanmadı.
      expect(find.byType(RitualEditorView), findsOneWidget);
    });

    testWidgets('yazmaya başlayınca uyarı kalkıyor', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.text('Seriyi Oluştur'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, 'Pazar Kahvaltısı');
      await settle(tester);

      expect(find.text('Bir isim yazmadan oluşturamayız.'), findsNothing);
    });

    testWidgets('ad varsa ritüel oluşuyor ve ekran kapanıyor', (tester) async {
      await pumpForm(tester);

      await tester.enterText(find.byType(TextField).first, 'Pazar Kahvaltısı');
      await openSection(tester, 'Tekrarlama');
      await tester.tap(find.text('Her hafta'));
      await settle(tester);
      await tester.tap(find.text('Seriyi Oluştur'));
      await settle(tester);

      final created = container.read(createdRitualsProvider);
      expect(created, hasLength(1));
      expect(created.single.title, 'Pazar Kahvaltısı');
      expect(created.single.recurrence.name, 'weekly');
      expect(find.byType(RitualEditorView), findsNothing);
    });

    testWidgets("AppBar'da TİK YOK: oluşturma tek yerden", (tester) async {
      // Kullanıcının kararı. İki ayrı "bitir" düğmesi hangisinin ne yaptığını
      // sorduruyordu; oluşturma yalnızca sayfanın sonundaki düğmede.
      await pumpForm(tester);

      expect(find.byIcon(AppIcons.check), findsNothing);
      expect(find.text('Seriyi Oluştur'), findsOneWidget);
    });

    testWidgets('kişiler, kategori ve açıklama kayda giriyor', (tester) async {
      await pumpForm(tester);

      await tester.enterText(find.byType(TextField).first, 'Aile Yemeği');
      await tester.enterText(find.byType(TextField).at(1), 'Her ayın ilk günü');
      await openSection(tester, 'İlgili Kişiler');
      await tester.tap(find.text('Annem'));
      await settle(tester);
      await openSection(tester, 'Kategori');
      await tester.tap(find.text('Aile').first);
      await settle(tester);
      await tester.tap(find.text('Seriyi Oluştur'));
      await settle(tester);

      final created = container.read(createdRitualsProvider).single;
      expect(created.description, 'Her ayın ilk günü');
      expect(created.personIds, {'person-annem'});
      expect(created.categoryId, isNotNull);
    });
  });

  group('dayanıklılık', () {
    testWidgets('2x yazı ölçeğinde taşma yok', (tester) async {
      await pumpForm(tester, textScale: 2);

      expect(tester.takeException(), isNull);
    });

    testWidgets('küçük ekranda taşma yok', (tester) async {
      await pumpForm(tester, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
    });

    testWidgets('satır yüksekliği referanstaki 60', (tester) async {
      await pumpForm(tester);

      final row = tester.getSize(find.byType(IzFormRow).first);
      expect(row.height, IzFormRow.kMinHeight);
    });
  });
}
