/// TÜRKÇE KARAKTER GİRİŞİ — bütün form alanlarında.
///
/// BU DOSYA BİR İDDİANIN KANITI: uygulama kodunda Türkçeye özgü harfleri
/// engelleyen hiçbir şey yok. Bir kullanıcı "Türkçe karakter girilmiyor"
/// dediğinde ilk bakılacak yer burası — testler geçiyorsa sorun uygulamada
/// değil, klavye/platform tarafındadır (emülatörde ana makine klavyesi,
/// masaüstünde IME gibi).
///
/// NEDEN GEREKLİ? Bir `inputFormatters` ya da `keyboardType` ayarı yanlışlıkla
/// harf kümesini kısıtlarsa hiçbir derleyici uyarmaz; ekranda yalnızca
/// "yazamıyorum" olarak görünür. Alanları tek tek yazıp geri okuyoruz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/media/media_picker.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/presentation/views/memory_editor_view.dart';
import 'package:iz/features/memories/presentation/widgets/memory_info_card.dart';
import 'package:iz/features/people/presentation/views/people_view.dart';
import 'package:iz/features/people/presentation/views/person_editor_view.dart';
import 'package:iz/shared/widgets/iz_labeled_field.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_media_picker.dart';
import '../helpers/fake_memory_repository.dart';
import '../helpers/real_fonts.dart';

/// Türkçenin İngilizcede olmayan harfleri, iki kasada.
///
/// Noktalı/noktasız i çifti BİLEREK ikisi de var: aramada tam bu çift sorun
/// çıkarıyordu (bkz. `localeSearchKey`).
const _turkishAlphabet = 'çÇğĞıIiİöÖşŞüÜ';

/// Gerçek bir cümle: harfler tek tek değil, kelime içinde de geçmeli.
const _turkishSentence = 'Şükrü, İzmir\'de ağabeyimin doğum günü şöleni';

late FakeMemoryRepository repository;

Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view
    ..physicalSize = const Size(390, 1000)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  repository = FakeMemoryRepository();
  addTearDown(repository.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 8, 12))),
        memoryRepositoryProvider.overrideWithValue(repository),
        mediaPickerProvider.overrideWithValue(FakeMediaPicker()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: '/screen',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(),
              routes: [GoRoute(path: 'screen', builder: (_, _) => screen)],
            ),
          ],
        ),
      ),
    ),
  );
  await settle(tester);
}

/// Alana yazar ve GERİ OKUR: girilen ile duran aynı mı?
Future<void> expectAccepts(
  WidgetTester tester,
  Finder field,
  String text, {
  required String where,
}) async {
  await tester.enterText(field, text);
  await settle(tester);

  expect(
    tester.widget<TextField>(field).controller?.text,
    text,
    reason: '$where: girilen metin bozuldu',
  );
  expect(find.text(text), findsWidgets, reason: '$where: ekranda görünmüyor');
}

Finder labeledField(String label) => find.descendant(
  of: find.ancestor(
    of: find.textContaining(label),
    matching: find.byType(IzLabeledField),
  ),
  matching: find.byType(TextField),
);

Finder cardField(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(MemoryInfoRow)),
  matching: find.byType(TextField),
);

void main() {
  setUpAll(loadRealFonts);

  group('yeni kişi formu', () {
    testWidgets('Ad alanı bütün Türkçe harfleri kabul ediyor', (tester) async {
      await pumpScreen(tester, const PersonEditorView());

      await expectAccepts(
        tester,
        labeledField('Ad'),
        _turkishAlphabet,
        where: 'Ad',
      );
    });

    testWidgets('İlişki alanı Türkçe cümle kabul ediyor', (tester) async {
      // Kullanıcı buraya kendi kelimesini yazıyor ("Annem", "ağabeyim") —
      // Türkçe harf kısıtlanırsa alanın anlamı kalmıyor.
      await pumpScreen(tester, const PersonEditorView());

      await expectAccepts(
        tester,
        labeledField('İlişkiniz'),
        'Ağabeyim',
        where: 'İlişkiniz',
      );
    });

    testWidgets('Kısa Not alanı uzun Türkçe metni kabul ediyor', (
      tester,
    ) async {
      await pumpScreen(tester, const PersonEditorView());

      await expectAccepts(
        tester,
        labeledField('Kısa Not'),
        _turkishSentence,
        where: 'Kısa Not',
      );
    });
  });

  group('anı formu', () {
    testWidgets('Başlık alanı Türkçe harfleri kabul ediyor', (tester) async {
      await pumpScreen(tester, const MemoryEditorView());

      await expectAccepts(
        tester,
        cardField('Başlık'),
        'Çeşme\'de şafak',
        where: 'Başlık',
      );
    });

    testWidgets('Konum ve Not alanları da kabul ediyor', (tester) async {
      // Başlıkta `maxLength` + `LengthLimitingTextInputFormatter` var; ötekiler
      // formatter'sız. İkisini birlikte sınıyoruz ki fark varsa görünsün.
      await pumpScreen(tester, const MemoryEditorView());

      await expectAccepts(
        tester,
        cardField('Konum'),
        'Iğdır, Ağrı',
        where: 'Konum',
      );
      await expectAccepts(
        tester,
        cardField('Not'),
        _turkishSentence,
        where: 'Not',
      );
    });

    testWidgets('UZUNLUK SINIRI Türkçe harfleri tek tek sayıyor', (
      tester,
    ) async {
      // `LengthLimitingTextInputFormatter` UTF-16 kod birimi sayıyor; Türkçe
      // harfler tek birim olduğu için 30 harf = 30 karakter. Birleşik bir
      // gösterim kullanılsaydı sınır yarı yolda dolardı.
      await pumpScreen(tester, const MemoryEditorView());

      const thirtyTurkish = 'şşşşşşşşşşşşşşşşşşşşşşşşşşşşşş';
      expect(thirtyTurkish.length, MemoryEditorView.kTitleMaxLength);

      await tester.enterText(cardField('Başlık'), thirtyTurkish);
      await settle(tester);

      expect(
        tester.widget<TextField>(cardField('Başlık')).controller?.text.length,
        MemoryEditorView.kTitleMaxLength,
      );
    });
  });

  group('kişi arama', () {
    testWidgets('arama alanı Türkçe harfleri kabul ediyor', (tester) async {
      await pumpScreen(tester, const PeopleView());

      await expectAccepts(
        tester,
        find.byType(TextField),
        'Ayşegül',
        where: 'arama',
      );
    });
  });
}
