/// Kişi detay ekranı — FR-062, FR-063.
///
/// BU EKRAN NEYİ SÖZ VERİYOR:
///   • kişiyi tanıtıyor (fotoğraf/silüet, ad, ilişki, doğum tarihi)
///   • ortak koleksiyonları GÖTÜRÜYOR (ok var), ritüelleri yalnızca BİLDİRİYOR
///     (ok yok)
///   • üç nokta düzenle/sil sunuyor, silme onay istiyor
///   • kullanıcının ÇIKARDIĞI parçalar geri gelmiyor: yaşam çizgisi, birlikte
///     anılar şeridi, "Birlikte Anı Ekle"
///
/// Süzülmüş koleksiyonlara gidiş uçtan uca `memory_navigation_test.dart`ta:
/// orada gerçek rota var ve süzmeyi kuran taraf rota.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/people/presentation/views/person_detail_preview_data.dart';
import 'package:iz/features/people/presentation/views/person_detail_view.dart';
import 'package:iz/features/people/presentation/widgets/person_detail_header.dart';
import 'package:iz/features/people/presentation/widgets/person_detail_rows.dart';
import 'package:iz/features/people/presentation/widgets/person_row.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';

import '../helpers/app_harness.dart';
import '../helpers/real_fonts.dart';

/// Koleksiyonu ve ritüeli olan kişi (önizleme verisinde "Annem").
const _full = 'person-annem';

/// Hiçbiri olmayan kişi — boş bölüm notlarını görebilmek için.
const _bare = 'person-dede';

Future<void> pumpDetail(
  WidgetTester tester, {
  String personId = _full,
  Size size = const Size(390, 900),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
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
        home: PersonDetailView(personId: personId),
      ),
    ),
  );
  await settle(tester);
}

void main() {
  setUpAll(loadRealFonts);

  group('başlık bloğu', () {
    testWidgets('ad, ilişki ve doğum tarihi duruyor', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Annem'), findsOneWidget);
      // Serbest etiketi olmayan kişide türün çevrilmiş adı gösteriliyor.
      expect(find.text('Anne / Baba'), findsOneWidget);
      // Doğum tarihinde YIL YOK: "ne zaman kutluyoruz" bilgisi.
      expect(find.text('18 Nisan'), findsOneWidget);
    });

    testWidgets('ad sayfadaki en büyük metin', (tester) async {
      // Ekranın konusu kişi; bölüm başlıkları onunla yarışmamalı.
      await pumpDetail(tester);

      final name = tester.widget<Text>(find.text('Annem'));
      final section = tester.widget<Text>(find.text('Koleksiyonlarımız'));

      expect(
        name.style!.fontSize,
        greaterThan(section.style!.fontSize!),
        reason: 'ad bölüm başlığından büyük olmalı',
      );
    });

    testWidgets('fotoğraf yoksa silüet ikonu çiziliyor', (tester) async {
      // Önizleme verisinde fotoğraf hattı yok; gerçek uygulamada da
      // fotoğrafsız kişi olacak, yani bu atılacak bir yer tutucu değil.
      await pumpDetail(tester);

      final avatar = tester.widget<PersonAvatar>(find.byType(PersonAvatar));
      expect(avatar.photo, isNull);
      expect(avatar.size, PersonDetailHeader.kAvatarSize);
    });

    testWidgets('avatar liste satırındakinden büyük', (tester) async {
      // Listede bir satır, burada ekranın konusu.
      await pumpDetail(tester);

      expect(
        PersonDetailHeader.kAvatarSize,
        greaterThan(PersonRow.kAvatarSize),
      );
    });

    testWidgets('doğum tarihi yoksa çip hiç çizilmiyor', (tester) async {
      // "—" göstermek boşluğu bilgi gibi sunmak olurdu.
      await pumpDetail(tester, personId: _bare);

      expect(find.text('Dede'), findsOneWidget);
      expect(find.byIcon(Icons.cake_outlined), findsNothing);
      expect(find.textContaining('Nisan'), findsNothing);
    });
  });

  group('koleksiyonlarımız', () {
    testWidgets('her koleksiyon adı ve anı sayısıyla listeleniyor', (
      tester,
    ) async {
      await pumpDetail(tester);

      final collections = PersonDetailPreviewData.collectionsOf(_full);
      expect(collections, isNotEmpty);

      for (final collection in collections) {
        expect(find.text(collection.title), findsOneWidget);
        // Türkçede sayıdan sonra çoğul eki yok: "8 anı".
        expect(find.text('${collection.memoryCount} anı'), findsOneWidget);
      }
    });

    testWidgets('satır dokunulabilir', (tester) async {
      await pumpDetail(tester);

      final row = tester.widget<PersonCollectionRow>(
        find.byType(PersonCollectionRow).first,
      );
      // Rota olmadan dokunuşu izleyemiyoruz; bağlantının VARLIĞINI burada,
      // gittiği yeri gezinme testinde doğruluyoruz.
      expect(row.onTap, isNotNull);
    });

    testWidgets('koleksiyonu olmayan kişide açıklama notu var', (tester) async {
      // Bölümü tamamen gizlemek de bir seçenekti; başlığın varlığı "burada
      // böyle bir şey olabilir" diyor.
      await pumpDetail(tester, personId: _bare);

      expect(find.text('Koleksiyonlarımız'), findsOneWidget);
      expect(
        find.text('Onunla paylaştığın bir koleksiyon henüz yok.'),
        findsOneWidget,
      );
      expect(find.byType(PersonCollectionRow), findsNothing);
    });
  });

  group('ritüellerimiz', () {
    testWidgets('ad ve kaç yıldır sürdüğü duruyor', (tester) async {
      await pumpDetail(tester);

      final rituals = PersonDetailPreviewData.ritualsOf(_full);
      expect(rituals, isNotEmpty);

      for (final ritual in rituals) {
        expect(find.text(ritual.title), findsOneWidget);
        expect(find.text('${ritual.years} yıl'), findsOneWidget);
      }
    });

    testWidgets('ritüel satırında OK YOK', (tester) async {
      // Kullanıcının kararı: "bunda detay olmaz". Ok koymak dokunulup hiçbir
      // şey olmayan bir satır üretirdi.
      await pumpDetail(tester);

      final ritualRow = find.byType(PersonRitualRow).first;
      expect(
        find.descendant(of: ritualRow, matching: find.byType(Icon)),
        findsOneWidget,
        reason: 'yalnızca ritüelin kendi ikonu olmalı, ok olmamalı',
      );
    });

    testWidgets('ritüel satırı dokunulabilir değil', (tester) async {
      await pumpDetail(tester);

      expect(
        find.descendant(
          of: find.byType(PersonRitualRow).first,
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('ritüeli olmayan kişide açıklama notu var', (tester) async {
      await pumpDetail(tester, personId: _bare);

      expect(find.text('Serilerimiz'), findsOneWidget);
      expect(
        find.text('Birlikte tekrarladığın bir seri henüz yok.'),
        findsOneWidget,
      );
      expect(find.byType(PersonRitualRow), findsNothing);
    });
  });

  group('üç nokta menüsü', () {
    testWidgets('düzenle ve sil çıkıyor', (tester) async {
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Kişi işlemleri'));
      await settle(tester);

      expect(find.text('Kişiyi Düzenle'), findsOneWidget);
      expect(find.text('Kişiyi Sil'), findsOneWidget);
    });

    testWidgets('silme yıkıcı renkte ve SONDA', (tester) async {
      // Parmak listede aşağı inerken yanlışlıkla silmeye denk gelmesin.
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Kişi işlemleri'));
      await settle(tester);

      final edit = tester.getCenter(find.text('Kişiyi Düzenle'));
      final delete = tester.getCenter(find.text('Kişiyi Sil'));
      expect(delete.dy, greaterThan(edit.dy));

      final deleteText = tester.widget<Text>(find.text('Kişiyi Sil'));
      final editText = tester.widget<Text>(find.text('Kişiyi Düzenle'));
      expect(deleteText.style!.color, isNot(editText.style!.color));
    });

    testWidgets('menü üç noktanın YANINDA açılıyor', (tester) async {
      // Kullanıcının isteği: "tam 3 noktanın yanında ya da altında".
      await pumpDetail(tester);

      final dots = tester.getCenter(find.byTooltip('Kişi işlemleri'));
      await tester.tap(find.byTooltip('Kişi işlemleri'));
      await settle(tester);

      final menu = tester.getRect(find.text('Kişiyi Düzenle'));
      expect(
        menu.top,
        greaterThan(dots.dy),
        reason: 'menü üç noktanın altında olmalı',
      );
      expect(
        (menu.right - dots.dx).abs(),
        lessThan(80),
        reason: 'menü üç noktaya yakın durmalı, ekranın ortasında değil',
      );
    });

    testWidgets('silmeye dokunmak ONAY istiyor', (tester) async {
      // NFR-034: kritik silme işleminde açık onay.
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Kişi işlemleri'));
      await settle(tester);
      await tester.tap(find.text('Kişiyi Sil'));
      await settle(tester);

      expect(find.text('Kişi silinsin mi?'), findsOneWidget);
      // FR-063 — silmek anıları silmiyor; kullanıcı bunu onaydan ÖNCE bilmeli.
      expect(find.textContaining('anılar'), findsOneWidget);
    });

    testWidgets('onay başlığı AÇIKLAMAYLA AYNI yazı tipinde', (tester) async {
      // Material'ın varsayılanı `headlineSmall` ve o yuva bizde Cormorant
      // (serif) tutuyor: "Kişi silinsin mi?" süslü çıkıp hemen altındaki
      // Poppins açıklamayla aynı aileden görünmüyordu. Düzeltme temada
      // (`dialogTheme.titleTextStyle`), yani bütün onay diyalogları için.
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Kişi işlemleri'));
      await settle(tester);
      await tester.tap(find.text('Kişiyi Sil'));
      await settle(tester);

      // Diyaloğun kendi metinleri stili TEMADAN alıyor; ekrandaki gerçek
      // yazı tipini `RenderParagraph` üzerinden okuyoruz.
      String fontOf(String text) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        return paragraph.text.style!.fontFamily!;
      }

      expect(
        fontOf('Kişi silinsin mi?'),
        fontOf(
          'Bu kişi silinecek. Onunla yaşadığın anılar silinmez, yalnızca '
          'bağlantısı kopar.',
        ),
      );
      expect(fontOf('Kişi silinsin mi?'), 'Poppins');
    });

    testWidgets('onayı iptal etmek hiçbir şey yapmıyor', (tester) async {
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Kişi işlemleri'));
      await settle(tester);
      await tester.tap(find.text('Kişiyi Sil'));
      await settle(tester);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester);

      expect(find.text('Kişi silinsin mi?'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      // Kişi hâlâ ekranda.
      expect(find.text('Annem'), findsOneWidget);
    });
  });

  group('çıkarılan parçalar geri gelmesin', () {
    testWidgets('yaşam çizgisi, birlikte anılar ve ekle düğmesi YOK', (
      tester,
    ) async {
      // Kullanıcının açık kararı. Sayfa tek bir soruya cevap veriyor: bu
      // kişiyle NELERİ paylaşıyoruz?
      await pumpDetail(tester);

      expect(find.textContaining('Yaşam Çizgisi'), findsNothing);
      expect(find.textContaining('Birlikte Anılarımız'), findsNothing);
      expect(find.textContaining('Birlikte Anı Ekle'), findsNothing);
    });

    testWidgets('AppBar başlık taşımıyor', (tester) async {
      // Ad hemen altta büyük duruyor; AppBar'a da yazmak aynı bilgiyi iki kez
      // göstermek olurdu.
      await pumpDetail(tester);

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Annem')),
        findsNothing,
      );
    });
  });

  group('alt çubuk', () {
    testWidgets('duruyor ve hiçbir sekme vurgulanmıyor', (tester) async {
      // Anı detayıyla aynı karar: kullanıcı bir kişiye bakarken uygulamanın
      // dışına düşmüş gibi hissetmemeli, ama bir sekmede de değil.
      await pumpDetail(tester);

      final nav = tester.widget<IzBottomNav>(find.byType(IzBottomNav));
      expect(nav.currentIndex, IzBottomNav.noSelection);
      expect(find.text('Ana Sayfa'), findsOneWidget);
    });
  });

  group('dayanıklılık', () {
    testWidgets('tanınmayan kimlikte çökmüyor', (tester) async {
      // Eski bağlantı ya da elle yazılmış rota.
      await pumpDetail(tester, personId: 'person-yok');

      expect(tester.takeException(), isNull);
      expect(find.byType(PersonDetailHeader), findsNothing);
    });

    testWidgets('2x yazı ölçeğinde taşma yok', (tester) async {
      // NFR-041: erişilebilirlik ölçeğinde de bozulmamalı.
      await pumpDetail(tester, textScale: 2);

      expect(tester.takeException(), isNull);
    });

    testWidgets('küçük ekranda taşma yok', (tester) async {
      await pumpDetail(tester, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
    });
  });
}
