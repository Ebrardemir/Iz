/// Yeni koleksiyon formu — FR-074, FR-078.
///
/// EKRANIN SÖZLERİ:
///   • kapak alanına dokunmak galeriyi açar
///   • TARİH ARALIĞI var (seride yok — koleksiyon anılardan önce kurulabiliyor)
///     ve tek takvimde iki tarih seçiliyor
///   • kişiler ve kategori AŞAĞI doğru açılır, aynı anda yalnızca biri açık
///   • AppBar'da tik YOK: oluşturma tek yerden
///   • ad boşsa oluşturmaz
///
/// "İlk Anıları Ekle" ve "Koleksiyonlarım"da görünme uçtan uca
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
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/collections/presentation/view_models/created_collections_view_model.dart';
import 'package:iz/features/collections/presentation/views/collection_editor_view.dart';
import 'package:iz/shared/widgets/iz_cover_illustration.dart';
import 'package:iz/shared/widgets/iz_cover_picker.dart';
import 'package:iz/shared/widgets/iz_form_row.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_media_picker.dart';
import '../helpers/real_fonts.dart';

final _today = DateTime(2026, 8, 13);

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
      clockProvider.overrideWithValue(FixedClock(_today)),
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
        // ROUTER'LI: ekran oluşturduktan sonra kendini kapatıyor.
        routerConfig: GoRouter(
          initialLocation: '/new',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, _) => const CollectionEditorView(),
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
        'Koleksiyon Adı',
        'Açıklama',
        'Tarih Aralığı',
        'İlgili Kişiler',
        'Kategori',
        'İlk Anıları Ekle',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      expect(find.text('Koleksiyonu Oluştur'), findsOneWidget);
    });

    testWidgets('AppBar\'da TİK YOK', (tester) async {
      // Seri formundaki kararın aynısı: iki ayrı "bitir" düğmesi hangisinin
      // ne yaptığını sorduruyordu.
      await pumpForm(tester);

      expect(find.byIcon(AppIcons.check), findsNothing);
    });

    testWidgets('SERİ FORMUYLA aynı parçalar', (tester) async {
      // İki form birbirinin kopyası değil; `shared/`taki aynı parçaların iki
      // dizilişi. Biri düzeltilince öteki de düzeliyor.
      await pumpForm(tester);

      expect(find.byType(IzFormCard), findsWidgets);
      expect(find.byType(IzExpandableRow), findsNWidgets(2));
    });
  });

  group('kapak görseli', () {
    testWidgets('kutuya dokunmak galeriyi açıp fotoğrafı koyuyor', (
      tester,
    ) async {
      await pumpForm(tester, pickerReturns: ['/tmp/kapak.jpg']);

      await tester.tap(find.text('Kapak Görseli Ekle'));
      await settle(tester);

      final picker = tester.widget<IzCoverPicker>(find.byType(IzCoverPicker));
      expect(picker.cover?.localPreviewPath, '/tmp/kapak.jpg');
      expect(find.byType(IzCoverIllustration), findsNothing);
      expect(find.text('Kapak Görselini Değiştir'), findsOneWidget);
    });
  });

  group('tarih aralığı', () {
    testWidgets('takvim açılıyor ve seçim satıra yazılıyor', (tester) async {
      // TEK TAKVİMDE İKİ TARİH: iki ayrı seçici kullanıcıyı iki kez aynı aya
      // götürüyordu.
      await pumpForm(tester);

      await tester.tap(find.text('Başlangıç – Bitiş'));
      await settle(tester);

      // Material'ın aralık seçicisi açıldı.
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
    });

    testWidgets('vazgeçince satır boş kalıyor', (tester) async {
      await pumpForm(tester);

      await tester.tap(find.text('Başlangıç – Bitiş'));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);

      expect(find.text('Başlangıç – Bitiş'), findsOneWidget);
    });
  });

  group('kişiler ve kategori', () {
    testWidgets('kişiler ÇOK seçim, satır açık kalıyor', (tester) async {
      await pumpForm(tester);
      await openSection(tester, 'İlgili Kişiler');

      await tester.tap(find.text('Annem'));
      await settle(tester);
      await tester.tap(find.text('Babam'));
      await settle(tester);

      expect(find.text('Elif'), findsOneWidget);
      expect(find.text('Annem, Babam'), findsOneWidget);
    });

    testWidgets('kategori TEK seçim, satır kapanıyor', (tester) async {
      await pumpForm(tester);
      await openSection(tester, 'Kategori');

      await tester.tap(find.text('Aile').first);
      await settle(tester);

      expect(find.text('Kategori seç'), findsNothing);
      expect(find.text('Seyahat'), findsNothing);
    });

    testWidgets('AKORDEON: ikinciyi açmak birinciyi kapatıyor', (tester) async {
      await pumpForm(tester);
      await openSection(tester, 'İlgili Kişiler');
      expect(find.text('Annem'), findsOneWidget);

      await openSection(tester, 'Kategori');

      expect(find.text('Annem'), findsNothing);
      expect(find.text('Seyahat'), findsWidgets);
    });
  });

  group('oluşturma', () {
    testWidgets('ad boşsa uyarıyor ve oluşturmuyor', (tester) async {
      await pumpForm(tester);

      await tester.tap(find.text('Koleksiyonu Oluştur'));
      await settle(tester);

      expect(find.text('Bir isim yazmadan oluşturamayız.'), findsOneWidget);
      expect(container.read(createdCollectionsProvider), isEmpty);
      expect(find.byType(CollectionEditorView), findsOneWidget);
    });

    testWidgets('yazmaya başlayınca uyarı kalkıyor', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.text('Koleksiyonu Oluştur'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, 'Kapadokya 2026');
      await settle(tester);

      expect(find.text('Bir isim yazmadan oluşturamayız.'), findsNothing);
    });

    testWidgets('ad varsa koleksiyon oluşuyor ve ekran kapanıyor', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.enterText(find.byType(TextField).first, 'Kapadokya 2026');
      await tester.enterText(find.byType(TextField).at(1), 'Balonlar ve vadi');
      await openSection(tester, 'İlgili Kişiler');
      await tester.tap(find.text('Annem'));
      await settle(tester);
      // Açılan kişi listesi düğmeyi ekranın DIŞINA itiyor ve `ListView`
      // görünmeyen çocukları hiç kurmuyor: `ensureVisible` de bulamıyor.
      // Gerçek kullanıcı gibi kaydırıyoruz.
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await settle(tester);
      await tester.tap(find.text('Koleksiyonu Oluştur'));
      await settle(tester);

      final created = container.read(createdCollectionsProvider).single;
      expect(created.title, 'Kapadokya 2026');
      expect(created.description, 'Balonlar ve vadi');
      expect(created.personIds, {'person-annem'});
      expect(find.byType(CollectionEditorView), findsNothing);
    });

    testWidgets('görünürlük varsayılan olarak ÖZEL', (tester) async {
      // BR-003: koleksiyon paylaşımın temel birimi ve kullanıcı paylaşmayı
      // ayrıca seçmeli.
      await pumpForm(tester);

      await tester.enterText(find.byType(TextField).first, 'Özel');
      await tester.tap(find.text('Koleksiyonu Oluştur'));
      await settle(tester);

      final collection = container
          .read(createdCollectionsProvider)
          .single
          .toCollection();
      expect(collection.isShared, isFalse);
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
  });
}
