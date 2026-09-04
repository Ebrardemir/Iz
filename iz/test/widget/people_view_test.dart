/// Kişiler sekmesi — boş durum.
///
/// Ekranın asıl iddiası: kullanıcının hiç kişisi yokken bu sayfa ne olduğunu
/// ANLATIYOR ve ilk adımı atmaya davet ediyor. Kişi eklendiğinde hiç
/// gösterilmemeli — o dallanma da burada sınanıyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/people/data/repositories/person_repository_impl.dart';
import 'package:iz/features/people/presentation/views/people_view.dart';
import 'package:iz/features/people/presentation/widgets/people_empty_illustration.dart';
import 'package:iz/features/people/presentation/widgets/person_row.dart';
import 'package:iz/shared/widgets/iz_screen_header.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_person_repository.dart';
import '../helpers/people_fixture.dart';
import '../helpers/real_fonts.dart';

Future<void> pumpPeople(
  WidgetTester tester, {
  bool hasPeople = false,
  Size size = const Size(390, 844),
  bool dark = false,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Ekran artık depodan okuyor; iki hâli deponun İÇERİĞİYLE kuruyoruz.
  // Eskiden bir `hasPeople` bayrağı vardı ve veri kaynağı olmadığı için
  // zorunluydu; şimdi gerçek yola daha yakınız.
  final repository = FakePersonRepository(
    hasPeople ? PeopleFixture.people : const [],
  );
  addTearDown(repository.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [personRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        home: const PeopleView(),
      ),
    ),
  );
  await settle(tester);
}

Future<void> typeSearch(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await settle(tester);
}

void main() {
  setUpAll(loadRealFonts);

  group('başlık şeridi', () {
    testWidgets('"Kişilerim" ve alt satırı duruyor', (tester) async {
      await pumpPeople(tester);

      expect(find.text('Kişilerim'), findsOneWidget);
      expect(find.text('Hayatına iz bırakanlar burada yaşar.'), findsOneWidget);
    });

    testWidgets('"Hayatım" ile AYNI bileşen', (tester) async {
      // Kullanıcının isteği buydu. Ölçüleri iki yere elle yazsaydık birini
      // değiştirdiğimizde öteki sessizce geride kalırdı.
      await pumpPeople(tester);

      expect(find.byType(IzScreenHeader), findsOneWidget);
    });

    testWidgets('başlık SOLA yaslı, ortalı değil', (tester) async {
      await pumpPeople(tester);

      final left = tester.getTopLeft(find.text('Kişilerim')).dx;
      expect(left, lessThan(390 / 3), reason: 'başlık ortalanmış görünüyor');
    });

    testWidgets('arama/filtre ikonu YOK', (tester) async {
      // Boş bir listede aranacak bir şey yok; "Hayatım"da olan eylemler
      // burada boşa dokunulan düğmeler olurdu.
      await pumpPeople(tester);

      final header = tester.widget<IzScreenHeader>(find.byType(IzScreenHeader));
      expect(header.actions, isEmpty);
    });
  });

  group('boş durum', () {
    testWidgets('illüstrasyon, metinler ve düğme sırayla', (tester) async {
      await pumpPeople(tester);

      final illo = tester.getCenter(find.byType(PeopleEmptyIllustration)).dy;
      final title = tester.getCenter(find.text('Burası onlarla dolacak.')).dy;
      final action = tester.getCenter(find.text('İlk Kişini Ekle')).dy;

      expect(illo, lessThan(title));
      expect(title, lessThan(action));
    });

    testWidgets('açıklama ve eylem metni referanstaki gibi', (tester) async {
      await pumpPeople(tester);

      expect(
        find.text(
          'Annen, en yakın arkadaşın, belki kedin… Kimi eklersen, onunla '
          'yaşadıklarınız tek bir çizgide birikmeye başlar.',
        ),
        findsOneWidget,
      );
      expect(find.text('İlk Kişini Ekle'), findsOneWidget);
    });

    testWidgets('düğme yeni kişi formuna götürüyor', (tester) async {
      // Bir süre "yakında" diyordu (form yoktu); artık gerçek bir yol.
      // Rota gerektirdiği için burada yalnızca çağrının yapıldığını
      // sınayamıyoruz — uçtan uca doğrulama
      // `memory_navigation_test.dart`ta, gerçek uygulama kurulu hâlde.
      await pumpPeople(tester);

      expect(find.text('İlk Kişini Ekle'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'İlk Kişini Ekle'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('metin bloğu ekranın tamamına yayılmıyor', (tester) async {
      // Açıklama üç satıra bölünsün, düğme ekranı kaplamasın: referansta
      // üçü de aynı ölçüyü paylaşıyor.
      await pumpPeople(tester);

      final button = tester.getSize(find.byType(FilledButton)).width;
      expect(button, lessThanOrEqualTo(300.5));
    });
  });

  group('kişi varken', () {
    testWidgets('boş durum HİÇ gösterilmiyor', (tester) async {
      // Kullanıcının isteği: kişi eklendiyse bu sayfa görünmeyecek.
      await pumpPeople(tester, hasPeople: true);

      expect(find.byType(PeopleEmptyIllustration), findsNothing);
      expect(find.text('Burası onlarla dolacak.'), findsNothing);
      expect(find.text('İlk Kişini Ekle'), findsNothing);
    });

    testWidgets('başlık şeridi YERİNDE kalıyor', (tester) async {
      // Şerit ekrana ait, boş duruma değil.
      await pumpPeople(tester, hasPeople: true);

      expect(find.text('Kişilerim'), findsWidgets);
      expect(find.byType(IzScreenHeader), findsOneWidget);
    });
  });

  group('dayanıklılık', () {
    testWidgets('karanlık temada da çiziliyor', (tester) async {
      await pumpPeople(tester, dark: true);

      expect(tester.takeException(), isNull);
      expect(find.byType(PeopleEmptyIllustration), findsOneWidget);
    });

    testWidgets('küçük ekranda illüstrasyon KÜÇÜLÜYOR, taşma yok', (
      tester,
    ) async {
      // Sabit 272 piksel, 320 piksellik bir telefonda metni ekrandan aşağı
      // itiyordu.
      await pumpPeople(tester, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(PeopleEmptyIllustration)).width,
        lessThan(PeopleEmptyIllustration.kSize),
      );
    });

    testWidgets('BÜYÜK yazı ölçeğinde kaydırılabiliyor', (tester) async {
      // NFR-032: kırpmak yerine kaydırılsın.
      await pumpPeople(tester, textScale: 2, size: const Size(390, 640));

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('liste', () {
    testWidgets('kişiler adıyla ve ilişkisiyle sıralanıyor', (tester) async {
      await pumpPeople(tester, hasPeople: true);

      expect(find.byType(PersonRow), findsWidgets);
      expect(find.text('Annem'), findsOneWidget);
      // İlişki adı ÇEVİRİDEN geliyor (bkz. person_l10n.dart), önizleme
      // verisinden değil.
      expect(find.text('Anne / Baba'), findsWidgets);
    });

    testWidgets('fotoğrafı olmayan kişide kişi İKONU çiziliyor', (
      tester,
    ) async {
      // Önizleme verisinde fotoğraf yok; gerçek uygulamada da fotoğrafsız
      // kişi olacak, yani bu atılacak bir yer tutucu değil.
      await pumpPeople(tester, hasPeople: true);

      expect(find.byType(PersonAvatar), findsWidgets);
      expect(find.byIcon(AppIcons.person), findsWidgets);
    });

    testWidgets('her satırda detaya götüren OK var', (tester) async {
      await pumpPeople(tester, hasPeople: true);

      final rows = find.byType(PersonRow).evaluate().length;
      expect(
        find.descendant(
          of: find.byType(PersonRow),
          matching: find.byIcon(AppIcons.forward),
        ),
        findsNWidgets(rows),
      );
    });

    testWidgets('SAYAÇLAR yok — anı/ritüel sayısı gösterilmiyor', (
      tester,
    ) async {
      // Kullanıcının isteği. Sayılar satırın sağını doldurup adı ve ilişkiyi
      // ikinci plana atıyordu.
      await pumpPeople(tester, hasPeople: true);

      expect(find.textContaining('anı'), findsNothing);
      expect(find.textContaining('ritüel'), findsNothing);
    });

    testWidgets('satır kişi detayına götürüyor', (tester) async {
      // Bir süre "yakında" diyordu (detay ekranı yoktu); artık gerçek bir yol.
      // Rota gerektirdiği için burada yalnızca satırın tıklanabilir olduğunu
      // doğruluyoruz — uçtan uca test `memory_navigation_test.dart`ta.
      await pumpPeople(tester, hasPeople: true);

      final row = tester.widget<PersonRow>(find.byType(PersonRow).first);
      expect(row.onTap, isNotNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('başlıkta "+ Kişi Ekle" var', (tester) async {
      await pumpPeople(tester, hasPeople: true);

      expect(find.text('Kişi Ekle'), findsOneWidget);
    });

    testWidgets('BOŞ durumda "+ Kişi Ekle" yok — büyük düğme zaten var', (
      tester,
    ) async {
      // İkisi birden olsa hangisine basacağı belirsiz kalırdı.
      await pumpPeople(tester);

      expect(find.text('Kişi Ekle'), findsNothing);
      expect(find.text('İlk Kişini Ekle'), findsOneWidget);
    });
  });

  group('arama', () {
    testWidgets('alan ipucuyla duruyor', (tester) async {
      await pumpPeople(tester, hasPeople: true);

      expect(find.text('Kişilerde ara'), findsOneWidget);
    });

    testWidgets('yazınca liste SÜZÜLÜYOR', (tester) async {
      await pumpPeople(tester, hasPeople: true);
      final all = find.byType(PersonRow).evaluate().length;

      await typeSearch(tester, 'elif');

      expect(find.byType(PersonRow), findsOneWidget);
      expect(find.text('Elif'), findsOneWidget);
      expect(all, greaterThan(1), reason: 'süzme öncesi tek satır varmış');
    });

    testWidgets('TÜRKÇE: "irem" noktalı İ ile yazılmış adı buluyor', (
      tester,
    ) async {
      // Dart'ın `toLowerCase()`i Türkçeyi bilmiyor; ekran doğru yardımcıyı
      // kullanıyor mu diye uçtan uca bakıyoruz (bkz. `localeSearchKey`).
      await pumpPeople(tester, hasPeople: true);

      await typeSearch(tester, 'irem');

      expect(find.text('İrem'), findsOneWidget);
      expect(find.byType(PersonRow), findsOneWidget);
    });

    testWidgets('İLİŞKİDE de arıyor', (tester) async {
      await pumpPeople(tester, hasPeople: true);

      await typeSearch(tester, 'arkadaş');

      // "Arkadaşım" ve "İş arkadaşım" — üç kişi.
      expect(find.byType(PersonRow), findsNWidgets(3));
    });

    testWidgets('bulunamayınca ARANAN METİN geri gösteriliyor', (tester) async {
      // Kuru bir "sonuç yok" kullanıcının yazım hatasını fark etmesini
      // sağlamıyor.
      await pumpPeople(tester, hasPeople: true);

      await typeSearch(tester, 'zzz');

      expect(find.byType(PersonRow), findsNothing);
      expect(find.text('Aradığın kişiyi bulamadım'), findsOneWidget);
      expect(find.textContaining('"zzz"'), findsOneWidget);
    });

    testWidgets('temizleme düğmesi listeyi geri getiriyor', (tester) async {
      await pumpPeople(tester, hasPeople: true);
      final all = find.byType(PersonRow).evaluate().length;

      await typeSearch(tester, 'elif');
      expect(find.byType(PersonRow), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.clear));
      await settle(tester);

      expect(find.byType(PersonRow), findsNWidgets(all));
    });

    testWidgets('metin yokken temizleme düğmesi GÖRÜNMÜYOR', (tester) async {
      await pumpPeople(tester, hasPeople: true);

      expect(find.byIcon(AppIcons.clear), findsNothing);
    });

    testWidgets('BOŞ durumda arama alanı yok', (tester) async {
      // Aranacak bir şey yok.
      await pumpPeople(tester);

      expect(find.byType(TextField), findsNothing);
    });
  });
}
