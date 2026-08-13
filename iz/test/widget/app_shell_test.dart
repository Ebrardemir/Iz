/// Alt sekme çubuğu ↔ router branch SIRASI eşleşmesi.
///
/// NEDEN BU TEST VAR?
/// `AppShell`, dokunulan sekmenin INDEKSİNİ `navigationShell.goBranch(index)`
/// çağrısına doğrudan veriyor. Yani alt çubuktaki sekme sırası ile
/// `app_router.dart` içindeki `branches` listesinin sırası BİREBİR aynı
/// olmak zorunda.
///
/// Sıra kayarsa hiçbir şey hata vermez: derleyici susar, uygulama açılır,
/// sadece "Hayatım"a dokunan kullanıcı Mağaza'yı görür. Sessiz bozulmanın
/// ders kitabı örneği — bu yüzden mekanik bir bekçi gerekiyor.
///
/// (`app_shell.dart` bu testin varlığına atıf yapıyordu ama dosya hiç
/// yazılmamıştı. Şimdi gerçekten var.)
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_memory_repository.dart';

/// BEKLENEN SEKMELER — tek kaynak.
///
/// ETİKET DE BURADA, ve bu şart: aşağıdaki davranış testi sekmeye KONUMUNA
/// göre değil ADINA göre dokunuyor.
///
/// İlk sürümde etiket `destinations[i].label`den okunuyordu ve test
/// totolojikti: i. konuma dokun → `goBranch(i)` → i. branch. Sıra kaysa bile
/// geçiyordu. Kasten bozup denedik, yakalamadı. Asıl soru "i. sekme i. branch'e
/// mi gidiyor" değil; **"Hayatım yazan düğme /my-life'ı mı açıyor"**.
///
/// Etiketler Türkçe yazılı: test dili `app_harness.dart` içinde 'tr'ye
/// sabitleniyor. Çeviri değişirse burası da değişir — istenen budur, çünkü
/// kullanıcının gördüğü metin ile gittiği yer arasındaki bağı sınıyoruz.
const _expectedTabs = <({String label, IconData icon, AppRoute route})>[
  (label: 'Ana Sayfa', icon: AppIcons.navHome, route: AppRoute.home),
  (label: 'Hayatım', icon: AppIcons.navMyLife, route: AppRoute.myLife),
  (label: 'Mağaza', icon: AppIcons.navStore, route: AppRoute.store),
  (label: 'Profilim', icon: AppIcons.navProfile, route: AppRoute.profile),
];

void main() {
  late FakeMemoryRepository repository;

  setUp(() {
    repository = FakeMemoryRepository();
  });

  tearDown(() => repository.dispose());

  IzBottomNav navOf(WidgetTester tester) =>
      tester.widget<IzBottomNav>(find.byType(IzBottomNav));

  String locationOf(WidgetTester tester) {
    final context = tester.element(find.byType(IzBottomNav));
    return GoRouter.of(context).state.matchedLocation;
  }

  testWidgets('çubuktaki sekmeler beklenen sırada', (tester) async {
    await pumpApp(tester, repository: repository);

    final destinations = navOf(tester).destinations;

    expect(
      destinations.length,
      _expectedTabs.length,
      reason:
          'Alt çubuğa sekme eklendi/çıkarıldı. app_router.dart içindeki '
          '`branches` listesini ve bu testteki _expectedTabs listesini '
          'birlikte güncelle.',
    );

    for (var i = 0; i < _expectedTabs.length; i++) {
      expect(
        (destinations[i].label, destinations[i].icon),
        (_expectedTabs[i].label, _expectedTabs[i].icon),
        reason: '$i. sekmenin etiketi/ikonu beklenenden farklı',
      );
    }
  });

  testWidgets('her sekme ADIYLA eşleşen branch\'i açıyor', (tester) async {
    await pumpApp(tester, repository: repository);

    // ASIL SINAV BU. Sekmeye KONUMUNA değil ADINA göre dokunuyoruz:
    // "Hayatım" yazan düğme, çubuktaki kaçıncı sırada olursa olsun,
    // /my-life'ı açmak ZORUNDA. Konuma göre dokunsaydık test kendi
    // kuyruğunu ısırırdı (bkz. _expectedTabs açıklaması).
    for (final tab in _expectedTabs) {
      await tester.tap(find.text(tab.label));
      await settle(tester);

      expect(
        locationOf(tester),
        tab.route.path,
        reason:
            '"${tab.label}" sekmesine dokunuldu ama ${tab.route.path} '
            'açılmadı. Alt çubuk sırası ile app_router.dart `branches` '
            'sırası kaymış — AppShell indeksi doğrudan goBranch\'e veriyor.',
      );
    }
  });

  testWidgets('ortadaki Ekle bir sekme DEĞİL — branch değiştirmez', (
    tester,
  ) async {
    await pumpApp(tester, repository: repository);

    final before = navOf(tester).currentIndex;

    // Ekle bir halka menü açıyor; menüden Anı seçilince yeni anı akışı ÜSTE
    // geliyor (`pushNamed`), sekme değişmiyor. Bu yüzden kullanıcı işini
    // bitirdiğinde hangi sekmedeyse oraya döner.
    await tester.tap(find.text('Ekle'));
    await settle(tester);
    await tester.tap(find.text('Anı'));
    await settle(tester);

    expect(find.text('Yeni Anı'), findsWidgets);
    expect(
      find.byType(IzBottomNav),
      findsNothing,
      reason: 'Akış tam ekran açılmalı; alt çubuk görünmemeli',
    );

    // Çarpıyla kapanınca aynı sekmede olmalıyız.
    await tester.tap(find.byIcon(AppIcons.clear));
    await settle(tester);

    expect(navOf(tester).currentIndex, before);
  });

  testWidgets('halka menü kapat düğmesiyle kapanır', (tester) async {
    await pumpApp(tester, repository: repository);

    await tester.tap(find.text('Ekle'));
    await settle(tester);
    expect(find.text('Anı'), findsOneWidget);

    // Alttaki çarpı — menünün çıkış yolu.
    await tester.tap(find.byIcon(AppIcons.clear));
    await settle(tester);

    expect(find.text('Anı'), findsNothing);
    // Kullanıcı bulunduğu sekmede kalmalı.
    expect(find.byType(IzBottomNav), findsOneWidget);
  });

  testWidgets('halka menü boşluğa dokununca kapanır', (tester) async {
    await pumpApp(tester, repository: repository);

    await tester.tap(find.text('Ekle'));
    await settle(tester);

    // Buğulu zemin dokunuşu yakalıyor: yanlışlıkla açan kullanıcı çıkabilmeli.
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);

    expect(find.text('Anı'), findsNothing);
  });
}
