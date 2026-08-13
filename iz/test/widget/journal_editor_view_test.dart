/// Yeni günlük formu — FR-030, FR-031.
///
/// EKRANIN SÖZLERİ:
///   • AppBar'da üç nokta YOK (henüz var olmayan bir kaydı silmek anlamsız)
///   • duygu etiketleri şeridi YOK — puan zaten aynı soruyu soruyor
///   • ruh hâli 1..10, dokunulmadıysa PUANSIZ kaydediliyor
///   • başlık OPSİYONEL, not ZORUNLU
///   • en fazla üç fotoğraf ve hepsi opsiyonel
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
import 'package:iz/features/journal/presentation/view_models/created_journal_entries_view_model.dart';
import 'package:iz/features/journal/presentation/views/journal_editor_view.dart';
import 'package:iz/features/journal/presentation/widgets/journal_greeting_card.dart';
import 'package:iz/features/journal/presentation/widgets/journal_mood_slider.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';
import 'package:iz/shared/widgets/iz_photo_strip.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_media_picker.dart';
import '../helpers/real_fonts.dart';

final _today = DateTime(2026, 8, 13, 21, 40);

late ProviderContainer container;

Future<void> pumpForm(
  WidgetTester tester, {
  List<String> pickerReturns = const [],
  double textScale = 1,
  Size size = const Size(390, 1000),
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
        routerConfig: GoRouter(
          initialLocation: '/new',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, _) => const JournalEditorView(),
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

/// Not alanına yazar (ilk alan başlık).
Future<void> writeNotes(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).at(1), text);
  await settle(tester);
}

void main() {
  setUpAll(loadRealFonts);

  group('yerleşim', () {
    testWidgets('karşılama, ruh hâli, başlık, notlar ve fotoğraf duruyor', (
      tester,
    ) async {
      await pumpForm(tester);

      expect(find.byType(JournalGreetingCard), findsOneWidget);
      expect(find.text('Merhaba'), findsOneWidget);
      // Davet cümlesi havuzdan geliyor (FR-032).
      final greeting = tester.widget<JournalGreetingCard>(
        find.byType(JournalGreetingCard),
      );
      expect(greeting.prompt, isNotEmpty);
      expect(find.byType(JournalMoodSlider), findsOneWidget);
      expect(find.textContaining('Başlık'), findsOneWidget);
      expect(find.text('Notlarım'), findsOneWidget);
      expect(find.text('Bugünden bir kare'), findsOneWidget);
      expect(find.text('Kaydı Oluştur'), findsOneWidget);
    });

    testWidgets('AppBar\'da ÜÇ NOKTA YOK', (tester) async {
      // Kullanıcının kararı: henüz var olmayan bir kaydı silmek anlamsız.
      await pumpForm(tester);

      expect(find.byIcon(AppIcons.more), findsNothing);
      expect(find.byIcon(AppIcons.delete), findsNothing);
    });

    testWidgets('DUYGU ETİKETLERİ şeridi YOK', (tester) async {
      // Referansta "Minnettar / Huzurlu / Enerjik…" vardı; kullanıcı
      // kaldırttı — puan zaten aynı soruyu soruyor.
      await pumpForm(tester);

      expect(find.text('Minnettar'), findsNothing);
      expect(find.text('Huzurlu'), findsNothing);
      expect(find.text('Enerjik'), findsNothing);
    });

    testWidgets('başlık OPSİYONEL diye işaretli', (tester) async {
      await pumpForm(tester);

      expect(find.textContaining('(Opsiyonel)'), findsWidgets);
    });

    testWidgets('not kutusu başlık alanından BÜYÜK', (tester) async {
      // Kullanıcının isteği: "notlarım kısmı daha büyük bi kutu olabilir".
      await pumpForm(tester);

      final title = tester.getSize(find.byType(TextField).first);
      final notes = tester.getSize(find.byType(TextField).at(1));

      expect(notes.height, greaterThan(title.height * 3));
    });
  });

  group('ruh hâli', () {
    testWidgets('uçlarda SAYI değil sözcük var', (tester) async {
      // Önce "1 en zor, 10 en iyi hissettiğin an." yazıyordu: bir ölçeği
      // tarif eden, kullanıcıya hiçbir şey hissettirmeyen bir cümle.
      await pumpForm(tester);

      expect(find.text('Zorlu bir gündü'), findsOneWidget);
      expect(find.text('Güzel bir gündü'), findsOneWidget);
      expect(find.textContaining('en zor'), findsNothing);
    });

    testWidgets('başlangıçta SEÇİLMEMİŞ', (tester) async {
      // "Hiç işaretlemedim" ile "5 hissettim" aynı şey değil.
      await pumpForm(tester);

      final slider = tester.widget<JournalMoodSlider>(
        find.byType(JournalMoodSlider),
      );
      expect(slider.value, isNull);
    });

    testWidgets('kaydırınca puan seçiliyor ve kayda giriyor', (tester) async {
      await pumpForm(tester);

      // Şeridin sağına dokunmak yüksek bir puan veriyor.
      final slider = find.byType(Slider);
      await tester.tapAt(
        tester.getCenter(slider) +
            Offset(tester.getSize(slider).width / 2 - 8, 0),
      );
      await settle(tester);

      final widget = tester.widget<JournalMoodSlider>(
        find.byType(JournalMoodSlider),
      );
      expect(widget.value, JournalMoodSlider.kMax);

      await writeNotes(tester, 'Bugün iyiydi.');
      await tester.tap(find.text('Kaydı Oluştur'));
      await settle(tester);

      final created = container.read(createdJournalEntriesProvider).single;
      expect(created.entry.moodScore, JournalMoodSlider.kMax);
    });

    testWidgets('dokunulmazsa kayıt PUANSIZ gidiyor', (tester) async {
      await pumpForm(tester);

      await writeNotes(tester, 'Sessiz bir gün.');
      await tester.tap(find.text('Kaydı Oluştur'));
      await settle(tester);

      final created = container.read(createdJournalEntriesProvider).single;
      expect(created.entry.moodScore, isNull);
    });
  });

  group('fotoğraflar', () {
    testWidgets('en fazla ÜÇ ve sınır önceden yazıyor', (tester) async {
      // Kaybolan bir "+" kutusu tek başına bilgi değil.
      await pumpForm(tester);

      final strip = tester.widget<IzPhotoStrip>(find.byType(IzPhotoStrip));
      expect(strip.limit, 3);
      expect(find.text('İstersen en fazla 3 fotoğraf ekle.'), findsOneWidget);
    });

    testWidgets('galeriden gelen fotoğraflar şeride giriyor', (tester) async {
      await pumpForm(tester, pickerReturns: ['/tmp/a.jpg', '/tmp/b.jpg']);

      // Şeridin İÇİNDEKİ "+": alt çubuğun ortasındaki düğme de aynı ikonu
      // kullanıyor ve ikona göre seçmek iki eşleşme buluyordu.
      await tester.tap(
        find.descendant(
          of: find.byType(IzPhotoStrip),
          matching: find.byIcon(AppIcons.add),
        ),
      );
      await settle(tester);

      final strip = tester.widget<IzPhotoStrip>(find.byType(IzPhotoStrip));
      expect(strip.photos, hasLength(2));
    });

    testWidgets('fotoğrafsız kayıt da oluşuyor', (tester) async {
      // Fotoğraf OPSİYONEL: günlük hızlı yazılan bir şey.
      await pumpForm(tester);

      await writeNotes(tester, 'Fotoğrafsız.');
      await tester.tap(find.text('Kaydı Oluştur'));
      await settle(tester);

      expect(
        container.read(createdJournalEntriesProvider).single.photos,
        isEmpty,
      );
    });
  });

  group('oluşturma', () {
    testWidgets('not boşsa uyarıyor ve kaydetmiyor', (tester) async {
      // FR-030 — günlüğün olmazsa olmazı yazının kendisi.
      await pumpForm(tester);

      await tester.tap(find.text('Kaydı Oluştur'));
      await settle(tester);

      expect(find.text('Birkaç kelime yazmadan kaydedemeyiz.'), findsOneWidget);
      expect(container.read(createdJournalEntriesProvider), isEmpty);
      expect(find.byType(JournalEditorView), findsOneWidget);
    });

    testWidgets('yazmaya başlayınca uyarı kalkıyor', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.text('Kaydı Oluştur'));
      await settle(tester);

      await writeNotes(tester, 'Bir şeyler.');

      expect(find.text('Birkaç kelime yazmadan kaydedemeyiz.'), findsNothing);
    });

    testWidgets('BAŞLIKSIZ kayıt geçerli', (tester) async {
      // Başlık zorunlu olsaydı yazma eşiği yükselirdi.
      await pumpForm(tester);

      await writeNotes(tester, 'Başlıksız gün.');
      await tester.tap(find.text('Kaydı Oluştur'));
      await settle(tester);

      final created = container.read(createdJournalEntriesProvider).single;
      expect(created.entry.title, isNull);
      expect(created.entry.text, 'Başlıksız gün.');
    });

    testWidgets('başlık ve not kayda giriyor, ekran kapanıyor', (tester) async {
      await pumpForm(tester);

      await tester.enterText(find.byType(TextField).first, 'Uzun bir gün');
      await writeNotes(tester, 'Sabah kahvemi balkonda içtim.');
      await tester.tap(find.text('Kaydı Oluştur'));
      await settle(tester);

      final created = container.read(createdJournalEntriesProvider).single;
      expect(created.entry.title, 'Uzun bir gün');
      expect(created.entry.text, 'Sabah kahvemi balkonda içtim.');
      expect(find.byType(JournalEditorView), findsNothing);
    });

    testWidgets('kayıt GÜNE yazılıyor, saate değil', (tester) async {
      // FR-033 — takvim görünümü günleri grupluyor; saat taşıyan bir tarih
      // "aynı gün" karşılaştırmasını bozardı.
      await pumpForm(tester);

      await writeNotes(tester, 'Gün.');
      await tester.tap(find.text('Kaydı Oluştur'));
      await settle(tester);

      final date = container
          .read(createdJournalEntriesProvider)
          .single
          .entry
          .entryDate;
      expect(date, DateTime(2026, 8, 13));
    });
  });

  group('alt çubuk', () {
    testWidgets('duruyor ve hiçbir sekme vurgulanmıyor', (tester) async {
      // Kullanıcının isteği ve referansta da var: günlük uygulamanın bir
      // sekmesi gibi yaşıyor, buradan çıkış yolu kapalı kalmamalı.
      await pumpForm(tester);

      final nav = tester.widget<IzBottomNav>(find.byType(IzBottomNav));
      expect(nav.currentIndex, IzBottomNav.noSelection);
      expect(find.text('Ana Sayfa'), findsOneWidget);
    });
  });

  group('davet cümlesi', () {
    testWidgets('kayda HANGİ davete cevap verildiği yazılıyor', (tester) async {
      // FR-032. Metin değil SIRA kimliği: çeviri değişse de bağ kopmuyor.
      await pumpForm(tester);

      await writeNotes(tester, 'Bugün.');
      await tester.tap(find.text('Kaydı Oluştur'));
      await settle(tester);

      final created = container.read(createdJournalEntriesProvider).single;
      expect(created.entry.promptId, startsWith('prompt-'));
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
