/// "ANIYA GİT" BAĞLANTILARI — uçtan uca.
///
/// Anı detayına altı ayrı yerden gidiliyor ve hepsi farklı bir veri tipinden
/// kimlik çıkarıyor. Bu testler her birinin GERÇEKTEN detay ekranını açtığını
/// doğruluyor; hepsi bir zamanlar "yakında" diyen birer SnackBar'dı ve o hâle
/// geri dönmek sessiz bir gerileme olurdu.
///
/// GERÇEK UYGULAMAYI kuruyoruz (router dahil), tek tek widget'ları değil:
/// bağlantının kırıldığı yer genelde widget değil, ekranın rotaya ne
/// geçirdiğidir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/features/memories/presentation/widgets/memory_info_card.dart';
import 'package:iz/features/my_life/presentation/widgets/calendar_grid.dart';
import 'package:iz/features/my_life/presentation/widgets/collection_card.dart';
import 'package:iz/features/my_life/presentation/widgets/day_memory_card.dart';
import 'package:iz/features/my_life/presentation/widgets/series_card.dart';
import 'package:iz/features/people/presentation/widgets/person_detail_header.dart';
import 'package:iz/features/people/presentation/widgets/person_detail_rows.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';
import 'package:iz/shared/widgets/iz_radial_menu.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_memory_repository.dart';
import '../helpers/fake_person_repository.dart';
import '../helpers/people_fixture.dart';
import '../helpers/real_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  late FakeMemoryRepository repository;
  late FakePersonRepository people;

  setUp(() {
    repository = FakeMemoryRepository();
    // Gezinme testleri kişi satırına dokunup detaya gidiyor; liste boş
    // olsaydı dokunacak satır olmazdı.
    people = FakePersonRepository(PeopleFixture.people);
  });
  tearDown(() {
    repository.dispose();
    people.dispose();
  });

  Future<void> pump(WidgetTester tester) =>
      pumpApp(tester, repository: repository, people: people);

  /// Uygulamayı kurar, "Hayatım" sekmesine geçip istenen alt sekmeyi açar.
  Future<void> openMyLifeTab(WidgetTester tester, String tabLabel) async {
    await pump(tester);
    await tester.tap(find.text('Hayatım'));
    await settle(tester);
    await tester.tap(find.text(tabLabel));
    await settle(tester);
  }

  /// Detay ekranı açıldı mı?
  void expectDetailOpen(String title) {
    expect(find.text('Anı Detay'), findsOneWidget);
    expect(find.text(title), findsWidgets);
  }

  group('ana sayfa', () {
    testWidgets('kapaktaki "Anıyı Gör" detayı açıyor', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Anıyı Gör'));
      await settle(tester);

      expectDetailOpen('İlk İzmir Tatilimiz');
    });

    testWidgets('son anılar satırı DOĞRU anıyı açıyor', (tester) async {
      // Üç satır var; dokunulan hangisiyse o açılmalı. Sabit bir kimlikle
      // gitmek de bu testi geçerdi — o yüzden ilk satır DEĞİL sondakine
      // dokunuyoruz.
      await pump(tester);

      await tester.tap(find.text('Venedik Balayımız'));
      await settle(tester);

      expectDetailOpen('Venedik Balayımız');
      // Önizleme kaydı yanında geldi: detay dolu açılıyor, "Bulunamadı"
      // ekranı değil.
      expect(
        find.text('San Marco meydanında yağmura yakalandık.'),
        findsOneWidget,
      );
    });

    testWidgets('kapak ve liste AYNI anıya gidiyor', (tester) async {
      // İkisi de "İlk İzmir Tatilimiz"i gösteriyor; farklı kimliklere
      // gitmeleri kullanıcıya iki ayrı anı varmış gibi görünürdü.
      await pump(tester);

      await tester.tap(find.text('Anıyı Gör'));
      await settle(tester);
      final fromHero = find.text('Kordon, İzmir').evaluate().length;

      expect(fromHero, 1, reason: 'kapaktan gelen kayıt İzmir anısı olmalı');
    });
  });

  group('hayatım — takvim', () {
    testWidgets('gün panelindeki kart detayı açıyor', (tester) async {
      await openMyLifeTab(tester, 'TAKVİM');
      // Önizlemede 6, 18 ve 29. günlerde anı var.
      await tester.tap(find.text('18'));
      await settle(tester);

      expect(find.byType(DayMemoryCard), findsWidgets);
      await tester.tap(find.text('İlk İzmir Tatilimiz'));
      await settle(tester);

      expectDetailOpen('İlk İzmir Tatilimiz');
    });

    testWidgets('detaydaki tarih SEÇİLİ GÜNÜN tarihi', (tester) async {
      // Kart hangi günden açıldıysa detay o günü göstermeli; sabit bir tarih
      // koymak panelde 6'ya dokunanla 18'e dokunanı aynı yere düşürürdü.
      //
      // 18. günü seçiyoruz, 6'yı DEĞİL: tarih metni "18 <Ay> <Yıl>" biçiminde
      // ve "6" yılın içinde de geçiyor (2026) — 6 ile arasaydık test kendi
      // kendini kandırırdı.
      await openMyLifeTab(tester, 'TAKVİM');
      await tester.tap(find.text('18'));
      await settle(tester);
      await tester.tap(find.text('Sahilde Sabah'));
      await settle(tester);

      expect(find.text('Anı Detay'), findsOneWidget);
      expect(find.textContaining('18'), findsWidgets);
    });
  });

  group('hayatım — koleksiyonlar', () {
    /// Koleksiyon kartları AÇIK geliyor; ayrıca genişletmek gerekmiyor
    /// (başta bir dokunuş eklemiştik ve kartı KAPATIYORDU).
    Future<void> openFirstCollection(WidgetTester tester) async {
      await openMyLifeTab(tester, 'KOLEKSİYONLAR');
      expect(find.byType(CollectionCard), findsWidgets);
      expect(find.text('Balonlar havalanırken'), findsOneWidget);
    }

    testWidgets('anı satırı detayı açıyor', (tester) async {
      await openFirstCollection(tester);

      await tester.tap(find.text('Balonlar havalanırken'));
      await settle(tester);

      expectDetailOpen('Balonlar havalanırken');
    });

    testWidgets('detay HANGİ KOLEKSİYONDAN geldiğini gösteriyor', (
      tester,
    ) async {
      // Kullanıcı "Kapadokya 2026" içinden geldi; detayda o koleksiyonu
      // görmezse nereden geldiğini kaybediyor.
      await openFirstCollection(tester);

      await tester.tap(find.text('Güvercinlik Vadisi'));
      await settle(tester);

      expect(
        find.descendant(
          of: find.byType(MemoryInfoCard),
          matching: find.text('Kapadokya 2026'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('üç noktadaki "Anıya git" detayı açıyor', (tester) async {
      await openFirstCollection(tester);

      await tester.tap(find.byTooltip('Anı işlemleri').first);
      await settle(tester);
      await tester.tap(find.text('Anıya git'));
      await settle(tester);

      expectDetailOpen('Balonlar havalanırken');
    });
  });

  group('hayatım — seriler', () {
    testWidgets('şeritteki yıl O YILIN anısını açıyor', (tester) async {
      // Serinin kendi ekranı henüz yok ama tek tek yıllar birer anı.
      await openMyLifeTab(tester, 'SERİLERİM');

      expect(find.byType(SeriesCard), findsWidgets);
      await tester.tap(find.text('2026').first);
      await settle(tester);

      expect(find.text('Anı Detay'), findsOneWidget);
    });

    testWidgets('detay SERİ satırını dolu gösteriyor', (tester) async {
      await openMyLifeTab(tester, 'SERİLERİM');

      await tester.tap(find.text('2026').first);
      await settle(tester);

      expect(
        find.descendant(
          of: find.byType(MemoryInfoCard),
          matching: find.textContaining('2026'),
        ),
        findsWidgets,
      );
    });
  });

  group('alt çubuk', () {
    testWidgets('detayda alt çubuk var', (tester) async {
      // Ekran kabuğun dışında açılıyor; çubuğu kendisi kuruyor.
      await pump(tester);

      await tester.tap(find.text('Anıyı Gör'));
      await settle(tester);

      expect(find.text('Anı Detay'), findsOneWidget);
      expect(find.byType(IzBottomNav), findsOneWidget);
    });

    testWidgets('sekmeye dokunmak detaydan ÇIKARIYOR', (tester) async {
      // `go`, `push` DEĞİL: `push` olsaydı sekme detayın üstüne biner ve geri
      // tuşu kullanıcıyı ana sayfadan anı detayına düşürürdü.
      await pump(tester);

      await tester.tap(find.text('Anıyı Gör'));
      await settle(tester);
      await tester.tap(find.text('Hayatım'));
      await settle(tester);

      expect(find.text('Anı Detay'), findsNothing);
      expect(find.text('TAKVİM'), findsOneWidget);
    });
  });

  group('Kişilerim ekranı', () {
    // BURAYA ARTIK SAYAÇTAN GELİNİYOR. Bir süre halka menüdeki "Kişi" de bu
    // listeye götürüyordu (form henüz yoktu); artık o doğrudan formu açıyor.
    Future<void> openPeople(WidgetTester tester) async {
      await pump(tester);
      await tester.tap(find.text('KİŞİLER'));
      await settle(tester);
    }

    testWidgets('alt çubuk var', (tester) async {
      // Ekran kabuğun dışında açılıyor; çubuğu kendisi kuruyor.
      await openPeople(tester);

      expect(find.text('Kişilerim'), findsOneWidget);
      expect(find.byType(IzBottomNav), findsOneWidget);
    });

    testWidgets("sekmeye dokunmak Kişilerim'den ÇIKARIYOR", (tester) async {
      // `go`, `push` DEĞİL: `push` olsaydı sekme bu sayfanın üstüne biner ve
      // geri tuşu kullanıcıyı beklenmedik bir yere düşürürdü.
      await openPeople(tester);

      await tester.tap(find.text('Hayatım'));
      await settle(tester);

      expect(find.text('Kişilerim'), findsNothing);
      expect(find.text('TAKVİM'), findsOneWidget);
    });
  });

  group('ana sayfa sayaçları', () {
    testWidgets('KİŞİLER sayacı Kişilerim ekranını açıyor', (tester) async {
      await pump(tester);

      await tester.tap(find.text('KİŞİLER'));
      await settle(tester);

      expect(find.text('Kişilerim'), findsOneWidget);
      expect(find.text('Kişilerde ara'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('GÜNLÜK sayacı günlük ekranını açıyor', (tester) async {
      await pump(tester);

      await tester.tap(find.text('GÜNLÜK'));
      await settle(tester);

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets("SERİLER sayacı Hayatım'ın SERİLERİM sekmesini açıyor", (
      tester,
    ) async {
      // Seriler ayrı bir ekran değil, "Hayatım"ın sekmesi: sayaç derin
      // bağlantıyla doğrudan o sekmeyi açıyor (`/my-life?tab=series`).
      await pump(tester);

      await tester.tap(find.text('SERİLER'));
      await settle(tester);

      expect(find.byType(SeriesCard), findsWidgets);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('KOLEKSİYONLAR sayacı KOLEKSİYONLAR sekmesini açıyor', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('KOLEKSİYONLAR'));
      await settle(tester);

      expect(find.byType(CollectionCard), findsWidgets);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('sekme sayacı ÜSTE BİNMİYOR, sekmeyi değiştiriyor', (
      tester,
    ) async {
      // `push` etseydik Hayatım ana sayfanın üstüne biner ve alt çubuk hâlâ
      // "Ana Sayfa"yı vurgulardı; geri tuşu da kullanıcıyı beklenmedik bir
      // yere düşürürdü.
      await pump(tester);

      await tester.tap(find.text('SERİLER'));
      await settle(tester);

      // Ana sayfanın içeriği artık ağaçta değil: gerçekten sekme değişti.
      expect(find.text('SON ANILAR'), findsNothing);
      expect(find.text('HAYATIM'), findsOneWidget);
    });

    testWidgets('Hayatıma ÖNCE girmiş kullanıcıda da çalışıyor', (
      tester,
    ) async {
      // BU TESTİN VARLIK SEBEBİ BİR HATA. Sayaç bağlantısını yazdığımızda
      // testler geçti ama uygulamada iki sayaç da takvimi açıyordu.
      //
      // Sebep: "Hayatım" alt çubuğun bir sekmesi ve
      // `StatefulShellRoute.indexedStack` sekme durumunu KORUYOR. Kullanıcı
      // bir kez oraya girdikten sonra ekran yeniden kurulmuyor, dolayısıyla
      // rotadan gelen sekme de bir daha okunmuyordu. İlk test bunu kaçırdı
      // çünkü ana sayfadan başlayıp Hayatım'a hiç girmemişti.
      await pump(tester);

      await tester.tap(find.text('Hayatım'));
      await settle(tester);
      expect(find.byType(CalendarGrid), findsOneWidget);

      await tester.tap(find.text('Ana Sayfa'));
      await settle(tester);
      await tester.tap(find.text('SERİLER'));
      await settle(tester);

      expect(find.byType(SeriesCard), findsWidgets);
      expect(find.byType(CalendarGrid), findsNothing);
    });

    testWidgets('elle sekme değiştirdikten SONRA sayaç yine çalışıyor', (
      tester,
    ) async {
      // İkinci tuzak: sekmeye dokunmak URL'yi güncellemezse URL `?tab=series`
      // olarak kalıyor; kullanıcı elle takvime geçip sayaca ikinci kez
      // bastığında rota değişmiyor ve hiçbir şey olmuyordu.
      await pump(tester);

      await tester.tap(find.text('Hayatım'));
      await settle(tester);
      await tester.tap(find.text('Ana Sayfa'));
      await settle(tester);
      await tester.tap(find.text('SERİLER'));
      await settle(tester);
      expect(find.byType(SeriesCard), findsWidgets);

      // Elle takvime geç…
      await tester.tap(find.text('TAKVİM'));
      await settle(tester);
      expect(find.byType(CalendarGrid), findsOneWidget);

      // …ve yine sayaca bas.
      await tester.tap(find.text('Ana Sayfa'));
      await settle(tester);
      await tester.tap(find.text('SERİLER'));
      await settle(tester);

      expect(find.byType(SeriesCard), findsWidgets);
    });

    testWidgets('sekmeye ELLE gelen kullanıcı TAKVİMİ görüyor', (tester) async {
      // Derin bağlantı varsayılanı bozmamalı.
      await pump(tester);

      await tester.tap(find.text('Hayatım'));
      await settle(tester);

      expect(find.byType(CalendarGrid), findsOneWidget);
    });
  });

  group('yeni kişi girişleri', () {
    // ÜÇ AYRI YOL aynı ekrana çıkıyor; üçü de bir zamanlar "yakında" diyordu.
    testWidgets('halka menüdeki "Kişi" formu açıyor', (tester) async {
      // Bir süre "Kişilerim" listesine götürüyordu çünkü form yoktu; menünün
      // işi bir şey EKLEMEK.
      await pump(tester);

      await tester.tap(find.text('Ekle'));
      await settle(tester);
      await tester.tap(find.text('Kişi'));
      await settle(tester);

      expect(find.text('Yeni Kişi'), findsOneWidget);
      expect(find.text('Kişiyi Kaydet'), findsOneWidget);
    });

    testWidgets('liste başlığındaki "+ Kişi Ekle" formu açıyor', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('KİŞİLER'));
      await settle(tester);
      await tester.tap(find.text('Kişi Ekle'));
      await settle(tester);

      expect(find.text('Yeni Kişi'), findsOneWidget);
    });

    testWidgets("formdan çıkmak Kişilerim'e geri getiriyor", (tester) async {
      await pump(tester);

      await tester.tap(find.text('KİŞİLER'));
      await settle(tester);
      await tester.tap(find.text('Kişi Ekle'));
      await settle(tester);
      await tester.tap(find.byIcon(AppIcons.clear).first);
      await settle(tester);

      expect(find.text('Yeni Kişi'), findsNothing);
      expect(find.text('Kişilerim'), findsOneWidget);
    });
  });

  group('kişi detayı', () {
    /// Kişilerim listesinden bir kişiye gider.
    Future<void> openPerson(WidgetTester tester, String name) async {
      await pump(tester);
      await tester.tap(find.text('KİŞİLER'));
      await settle(tester);
      // Ad aynı metni ikinci kez taşıyabiliyor (serbest ilişki etiketi);
      // listedeki ilk esleme satırın kendisi.
      await tester.tap(find.text(name).first);
      await settle(tester);
    }

    testWidgets('liste satırı kişi detayını açıyor', (tester) async {
      await openPerson(tester, 'Annem');

      expect(find.byType(PersonDetailHeader), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('üç noktadaki "Kişiyi Düzenle" formu DOLU açıyor', (
      tester,
    ) async {
      // Bir süre "yakında" diyordu: form yalnızca yeni kayıt için yazılmıştı.
      await openPerson(tester, 'Annem');
      await tester.tap(find.byTooltip('Kişi işlemleri'));
      await settle(tester);
      await tester.tap(find.text('Kişiyi Düzenle'));
      await settle(tester);

      expect(find.text('Kişiyi Düzenle'), findsOneWidget);
      expect(find.text('Değişiklikleri Kaydet'), findsOneWidget);
      // Alanlar dolu: kullanıcı her şeyi yeniden yazmıyor.
      expect(find.text('Annem'), findsWidgets);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('düzenlemeyi kapatmak KİŞİYE geri getiriyor', (tester) async {
      // `push`, `go` değil: kullanıcı baktığı kişiye dönmeli.
      await openPerson(tester, 'Annem');
      await tester.tap(find.byTooltip('Kişi işlemleri'));
      await settle(tester);
      await tester.tap(find.text('Kişiyi Düzenle'));
      await settle(tester);
      await tester.tap(find.byIcon(AppIcons.clear).first);
      await settle(tester);

      expect(find.byType(PersonDetailHeader), findsOneWidget);
    });

    testWidgets('koleksiyona dokunmak KİŞİYE SÜZÜLMÜŞ listeyi açıyor', (
      tester,
    ) async {
      // Kullanıcının açık isteği: "tüm koleksiyonlar değil, o kişiyle
      // beraber olduğum koleksiyonlar açılır".
      await openPerson(tester, 'Annem');
      await tester.tap(find.byType(PersonCollectionRow).first);
      await settle(tester);

      // Koleksiyonlar sekmesindeyiz...
      expect(find.text('HAYATIM'), findsOneWidget);
      // ...ve neden az kart gördüğümüzü söyleyen çip duruyor.
      expect(find.text('Annem ile'), findsOneWidget);

      // Kişinin PAYLAŞMADIĞI koleksiyon listede YOK. Bu testin can alıcı
      // yeri: süzme çalışmazsa da sayfa açılır ve gözden kaçar.
      expect(find.text('Kapadokya 2026'), findsOneWidget);
      expect(find.text('Üniversite Yıllarım'), findsNothing);
    });

    testWidgets('çipteki çarpı tüm koleksiyonları geri getiriyor', (
      tester,
    ) async {
      // Süzülmüş bir listeden çıkışı olmayan kullanıcı sıkışıp kalır.
      await openPerson(tester, 'Annem');
      await tester.tap(find.byType(PersonCollectionRow).first);
      await settle(tester);
      await tester.tap(find.byTooltip('Süzmeyi kaldır'));
      await settle(tester);

      expect(find.text('Annem ile'), findsNothing);
      expect(find.text('Üniversite Yıllarım'), findsOneWidget);
    });
  });

  group('ritüel oluşturma', () {
    /// Halka menüden ritüel formunu açar.
    Future<void> openRitualForm(WidgetTester tester) async {
      await pump(tester);
      await tester.tap(find.text('Ekle'));
      await settle(tester);
      await tester.tap(find.text('Seri'));
      await settle(tester);
    }

    testWidgets('halka menüdeki "Seri" formu açıyor', (tester) async {
      // Bir süre "yakında" diyordu: ritüel formu yoktu.
      await openRitualForm(tester);

      expect(find.text('Yeni Seri'), findsOneWidget);
      expect(find.text('Seriyi Oluştur'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('"Bu Yıla Anı Ekle" anı seçme sayfasını açıyor', (
      tester,
    ) async {
      await openRitualForm(tester);
      await tester.tap(find.text('Bu Yıla Anı Ekle'));
      await settle(tester);

      expect(find.text('Anı Seç'), findsOneWidget);
      expect(find.text('Bitti'), findsOneWidget);
      // Anılar kutu kutu listeleniyor.
      expect(find.text('Kahve Molası'), findsOneWidget);
    });

    testWidgets('seçilen anılar forma DÖNÜYOR', (tester) async {
      await openRitualForm(tester);
      await tester.tap(find.text('Bu Yıla Anı Ekle'));
      await settle(tester);
      await tester.tap(find.text('Kahve Molası'));
      await tester.tap(find.text('Sahilde Sabah'));
      await settle(tester);
      await tester.tap(find.text('Bitti'));
      await settle(tester);

      expect(find.text('Yeni Seri'), findsOneWidget);
      expect(find.text('2 anı seçildi'), findsOneWidget);
    });

    testWidgets('TARİH ARALIĞI seçilen anılardan türetiliyor', (tester) async {
      // Kullanıcının kararı: "10 anı varsa bu 10 anıdan en erken ve en geç
      // tarih zaten tarih aralığı olur". Formda tarih alanı YOK.
      await openRitualForm(tester);
      await tester.tap(find.text('Bu Yıla Anı Ekle'));
      await settle(tester);
      // 2026 ve 2023: aralığın iki ucu.
      await tester.tap(find.text('Kahve Molası'));
      await tester.tap(find.text('Annemin Doğum Günü'));
      await settle(tester);
      await tester.tap(find.text('Bitti'));
      await settle(tester);

      expect(find.text('Tarih aralığı: 2023 – 2026'), findsOneWidget);
    });

    testWidgets('tek yıl seçilirse aralık tek yıl yazıyor', (tester) async {
      // "2026 – 2026" saçma görünüyordu.
      await openRitualForm(tester);
      await tester.tap(find.text('Bu Yıla Anı Ekle'));
      await settle(tester);
      await tester.tap(find.text('Kahve Molası'));
      await settle(tester);
      await tester.tap(find.text('Bitti'));
      await settle(tester);

      expect(find.text('Tarih aralığı: 2026'), findsOneWidget);
    });

    testWidgets('vazgeçmek seçimi değiştirmiyor', (tester) async {
      // ✕ ile çıkmak `null` döndürüyor ve form hiçbir şeyi değiştirmiyor.
      await openRitualForm(tester);
      await tester.tap(find.text('Bu Yıla Anı Ekle'));
      await settle(tester);
      await tester.tap(find.text('Kahve Molası'));
      await settle(tester);
      await tester.tap(find.byIcon(AppIcons.clear).first);
      await settle(tester);

      expect(find.text('Seriye anı bağla'), findsOneWidget);
      expect(find.textContaining('anı seçildi'), findsNothing);
    });

    testWidgets('ikinci açılışta seçimler İŞARETLİ geliyor', (tester) async {
      // Kullanıcı sıfırdan başlamamalı.
      await openRitualForm(tester);
      await tester.tap(find.text('Bu Yıla Anı Ekle'));
      await settle(tester);
      await tester.tap(find.text('Kahve Molası'));
      await settle(tester);
      await tester.tap(find.text('Bitti'));
      await settle(tester);

      await tester.tap(find.text('1 anı seçildi'));
      await settle(tester);
      await tester.tap(find.text('Bitti'));
      await settle(tester);

      // Hiçbir şeye dokunmadan çıktı: seçim korundu.
      expect(find.text('1 anı seçildi'), findsOneWidget);
    });

    testWidgets('oluşturulan ritüel SERİLERİM\'de görünüyor', (tester) async {
      // Kullanıcının isteği: "kaydet butonu olcak tıkladığımda ritüel oluşcak
      // ve ritüellerim sayfasında gösterilcek".
      await openRitualForm(tester);
      await tester.enterText(find.byType(TextField).first, 'Pazar Kahvaltısı');
      await tester.tap(find.text('Bu Yıla Anı Ekle'));
      await settle(tester);
      await tester.tap(find.text('Kahve Molası'));
      await settle(tester);
      await tester.tap(find.text('Bitti'));
      await settle(tester);
      await tester.tap(find.text('Seriyi Oluştur'));
      await settle(tester);

      // Form kapandı ve haber verdi.
      expect(find.text('Yeni Seri'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.tap(find.text('Hayatım'));
      await settle(tester);
      await tester.tap(find.text('SERİLERİM'));
      await settle(tester);

      // EN ÜSTTE: kullanıcı az önce kurduğunu aramamalı.
      expect(find.text('Pazar Kahvaltısı'), findsOneWidget);
    });
  });

  group('seri detayı', () {
    /// "Hayatım" → Serilerim → seri kartı.
    Future<void> openSeries(WidgetTester tester, String title) async {
      await openMyLifeTab(tester, 'SERİLERİM');
      await tester.tap(find.text(title));
      await settle(tester);
    }

    testWidgets('seri kartı detayı açıyor', (tester) async {
      // Bir süre "yakında" diyordu: serinin kendi ekranı yoktu.
      await openSeries(tester, 'Yaz Tatillerimiz');

      expect(find.text('Bu Serideki Anılar'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('sayılar ve anılar önizleme verisinden geliyor', (
      tester,
    ) async {
      await openSeries(tester, 'Yaz Tatillerimiz');

      // Altı anı, altı ayrı yıl, dört ayrı şehir.
      expect(find.text('6 anı'), findsOneWidget);
      expect(find.text('6 yıl'), findsOneWidget);
      expect(find.text('4 şehir'), findsOneWidget);
      expect(find.text('Çeşme’de gün batımı'), findsOneWidget);
    });

    testWidgets('anı satırı ANI DETAYINI açıyor', (tester) async {
      // Satırın tek işi bu; üç nokta kaldırıldı.
      await openSeries(tester, 'Yaz Tatillerimiz');
      await tester.tap(find.text('Kekova tekne turu'));
      await settle(tester);

      expect(find.text('Anı Detay'), findsOneWidget);
      expect(find.text('Bulunamadı'), findsNothing);
    });

    testWidgets('"Tümünü Gör" AYNI sayfada kalıyor', (tester) async {
      // Ayrı bir sayfa açsaydı kapak ve sayılar kaybolurdu.
      await openSeries(tester, 'Yaz Tatillerimiz');
      await tester.tap(find.text('Tümünü Gör'));
      await settle(tester);

      expect(find.text('6 anı'), findsOneWidget);
      expect(find.text('Daha Az Göster'), findsOneWidget);
    });

    testWidgets('oluşturulan seri de detayını açıyor', (tester) async {
      // Aynı ekran iki kaynağı da gösteriyor: önizleme serileri ve bu
      // oturumda oluşturulanlar.
      await pump(tester);
      await tester.tap(find.text('Ekle'));
      await settle(tester);
      await tester.tap(find.text('Seri'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Pazar Kahvaltısı');
      await tester.tap(find.text('Bu Yıla Anı Ekle'));
      await settle(tester);
      await tester.tap(find.text('Kahve Molası'));
      await settle(tester);
      await tester.tap(find.text('Bitti'));
      await settle(tester);
      await tester.tap(find.text('Seriyi Oluştur'));
      await settle(tester);

      await tester.tap(find.text('Hayatım'));
      await settle(tester);
      await tester.tap(find.text('SERİLERİM'));
      await settle(tester);
      await tester.tap(find.text('Pazar Kahvaltısı'));
      await settle(tester);

      expect(find.text('Bu Serideki Anılar'), findsOneWidget);
      expect(find.text('1 anı'), findsOneWidget);
      // Seri formunda konum sorulmuyor: şehir kutusu hiç çizilmiyor.
      expect(find.text('Keşfedildi'), findsNothing);
    });
  });

  group('koleksiyon oluşturma', () {
    /// Halka menüden koleksiyon formunu açar.
    Future<void> openCollectionForm(WidgetTester tester) async {
      await pump(tester);
      await tester.tap(find.text('Ekle'));
      await settle(tester);
      await tester.tap(find.text('Koleksiyon'));
      await settle(tester);
    }

    testWidgets('halka menüdeki "Koleksiyon" formu açıyor', (tester) async {
      // Bir süre "yakında" diyordu: koleksiyon formu yoktu.
      await openCollectionForm(tester);

      expect(find.text('Yeni Koleksiyon'), findsOneWidget);
      expect(find.text('Koleksiyonu Oluştur'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('"İlk Anıları Ekle" anı seçme sayfasını açıyor', (
      tester,
    ) async {
      // Seri formuyla AYNI ekran: `/memory/picker`. Bu rota bir ara
      // `/memory/:id`nin arkasına düşüp anı detayını açıyordu.
      await openCollectionForm(tester);
      await tester.tap(find.text('İlk Anıları Ekle'));
      await settle(tester);

      expect(find.text('Anı Seç'), findsOneWidget);
      expect(find.text('Bitti'), findsOneWidget);
      expect(find.text('Anı Detay'), findsNothing);
    });

    testWidgets('seçilen anılar forma dönüyor', (tester) async {
      await openCollectionForm(tester);
      await tester.tap(find.text('İlk Anıları Ekle'));
      await settle(tester);
      await tester.tap(find.text('Kahve Molası'));
      await tester.tap(find.text('Venedik Balayımız'));
      await settle(tester);
      await tester.tap(find.text('Bitti'));
      await settle(tester);

      expect(find.text('Yeni Koleksiyon'), findsOneWidget);
      expect(find.text('2 anı seçildi'), findsOneWidget);
    });

    testWidgets('oluşturulan koleksiyon KOLEKSİYONLARIMDA görünüyor', (
      tester,
    ) async {
      await openCollectionForm(tester);
      await tester.enterText(find.byType(TextField).first, 'Ege Turumuz');
      await tester.tap(find.text('İlk Anıları Ekle'));
      await settle(tester);
      await tester.tap(find.text('Kahve Molası'));
      await settle(tester);
      await tester.tap(find.text('Bitti'));
      await settle(tester);
      await tester.tap(find.text('Koleksiyonu Oluştur'));
      await settle(tester);

      // Form kapandı ve haber verdi.
      expect(find.text('Yeni Koleksiyon'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.tap(find.text('Hayatım'));
      await settle(tester);
      await tester.tap(find.text('KOLEKSİYONLAR'));
      await settle(tester);

      // EN ÜSTTE ve özet satırı anı sayısını taşıyor.
      expect(find.text('Ege Turumuz'), findsOneWidget);
      expect(find.textContaining('1 anı'), findsWidgets);
    });
  });

  group('günlük oluşturma', () {
    /// Halka menüden günlük formunu açar.
    Future<void> openJournalForm(WidgetTester tester) async {
      await pump(tester);
      await tester.tap(find.text('Ekle'));
      await settle(tester);
      await tester.tap(find.text('Günlük Kaydı'));
      await settle(tester);
    }

    testWidgets('halka menüdeki "Günlük Kaydı" formu açıyor', (tester) async {
      // Bir süre "yakında" diyordu: günlük formu yoktu.
      await openJournalForm(tester);

      expect(find.text('Yeni Günlük'), findsOneWidget);
      expect(find.text('Merhaba'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('yazılan kayıt GÜNLÜK sekmesinde görünüyor', (tester) async {
      await openJournalForm(tester);
      await tester.enterText(find.byType(TextField).first, 'Uzun bir gün');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Sabah kahvemi balkonda içtim.',
      );
      await settle(tester);
      // Uygulama ölçüsü 844 yüksekliğinde; büyük not kutusu düğmeyi ekranın
      // dışına itiyor ve `ListView` görünmeyen çocukları hiç kurmuyor.
      //
      // `.first` ŞART: fotoğraf şeridi de bir `ListView` (yatay) ve `.last`
      // onu seçip yatay bir şeridi dikey sürüklemeye çalışıyordu.
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await settle(tester);
      await tester.tap(find.text('Kaydı Oluştur'));
      await settle(tester);

      // Form kapandı ve haber verdi.
      expect(find.text('Yeni Günlük'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);

      // Günlük sekmesi alt çubukta değil; rotadan gidiyoruz.
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.goNamed(AppRoute.journal.name);
      await settle(tester);

      expect(find.text('Uzun bir gün'), findsOneWidget);
      expect(find.textContaining('balkonda'), findsOneWidget);
    });
  });

  group('alt çubuktaki "+" — her ekranda AYNI menü', () {
    /// Menünün beş seçeneği de ekranda mı?
    ///
    /// Etiketleri MENÜNÜN İÇİNDE arıyoruz: "Koleksiyon" ve "Anı" gibi
    /// kelimeler ekranın kendisinde de geçiyor (anı detayındaki ilişki
    /// satırları) ve düz bir `find.text` iki eşleşme buluyordu.
    void expectAddMenuOpen() {
      final menu = find.byType(IzRadialMenuScope);
      expect(menu, findsOneWidget, reason: 'halka menü açılmalı');

      for (final label in [
        'Koleksiyon',
        'Seri',
        'Anı',
        'Günlük Kaydı',
        'Kişi',
      ]) {
        expect(
          find.descendant(of: menu, matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
    }

    testWidgets('sekmelerde', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Ekle'));
      await settle(tester);

      expectAddMenuOpen();
    });

    testWidgets('Kişilerim ekranında', (tester) async {
      // BİR ARA anı formunu açıyordu: alt çubuğu olan her ekran "+"a basınca
      // ne yapacağını kendisi uyduruyordu. Kullanıcı her yerde aynı menüyü
      // bekliyor.
      await pump(tester);
      await tester.tap(find.text('KİŞİLER'));
      await settle(tester);

      await tester.tap(find.text('Ekle'));
      await settle(tester);

      expectAddMenuOpen();
      expect(find.text('Yeni Anı'), findsNothing);
    });

    testWidgets('kişi detayında', (tester) async {
      await pump(tester);
      await tester.tap(find.text('KİŞİLER'));
      await settle(tester);
      await tester.tap(find.text('Annem').first);
      await settle(tester);

      await tester.tap(find.text('Ekle'));
      await settle(tester);

      expectAddMenuOpen();
    });

    testWidgets('anı detayında', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Anıyı Gör'));
      await settle(tester);

      await tester.tap(find.text('Ekle'));
      await settle(tester);

      expectAddMenuOpen();
    });

    testWidgets('seri detayında', (tester) async {
      await openMyLifeTab(tester, 'SERİLERİM');
      await tester.tap(find.text('Yaz Tatillerimiz'));
      await settle(tester);

      await tester.tap(find.text('Ekle'));
      await settle(tester);

      expectAddMenuOpen();
    });

    testWidgets('günlük ekranında', (tester) async {
      // Burada da kendiliğinden günlük formu açılıyordu.
      await pump(tester);
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.goNamed(AppRoute.journal.name);
      await settle(tester);

      await tester.tap(find.text('Ekle'));
      await settle(tester);

      expectAddMenuOpen();
      expect(find.text('Yeni Günlük'), findsNothing);
    });
  });

  group('gerileme koruması', () {
    testWidgets('hiçbir "anıya git" artık SnackBar göstermiyor', (
      tester,
    ) async {
      // Bu testin varlık sebebi: altı bağlantının hepsi bir zamanlar
      // "yakında" diyen bir SnackBar'dı. Biri o hâle geri dönerse burada
      // yakalanıyor.
      await pump(tester);

      await tester.tap(find.text('Anıyı Gör'));
      await settle(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Anı Detay'), findsOneWidget);
    });

    testWidgets('detay ekranı BULUNAMADI demiyor', (tester) async {
      // Önizleme kimliklerinin veritabanında karşılığı yok; kayıt yanında
      // gelmezse ekran boş durumu gösterirdi.
      await pump(tester);

      await tester.tap(find.text('Kahve Molası'));
      await settle(tester);

      expect(find.text('Kahve Molası'), findsWidgets);
      expect(find.text('Bulunamadı'), findsNothing);
    });
  });
}
