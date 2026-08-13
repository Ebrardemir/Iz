/// Uygulama smoke testi — "açılıyor mu?" sorusunun cevabı.
///
/// Bu test tüm zinciri gerçekten kurar: ProviderScope → IzApp → GoRouter →
/// AppShell → MemoryListView → ViewModel → repository → Drift.
/// Bir yerde import/DI/route hatası varsa burada patlar.
///
/// CI'da en değerli testlerden biridir: hızlı çalışır ama çok şey kanıtlar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/features/home/presentation/views/home_view.dart';
import 'package:iz/features/memories/presentation/widgets/memory_info_card.dart';
import 'package:iz/shared/widgets/curved_top_panel.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_media_picker.dart';
import '../helpers/fake_memory_repository.dart';

void main() {
  late FakeMemoryRepository repository;

  setUp(() {
    repository = FakeMemoryRepository();
  });

  tearDown(() => repository.dispose());

  /// Kurulum ortak yardımcıda: `test/helpers/app_harness.dart`.
  /// (`app_shell_test.dart` de aynı zinciri kullanıyor.)
  Future<void> pump(
    WidgetTester tester, {
    bool onboardingCompleted = true,
    bool signIn = true,
  }) => pumpApp(
    tester,
    repository: repository,
    onboardingCompleted: onboardingCompleted,
    signIn: signIn,
  );

  /// Rotayı doğrudan çağırır.
  ///
  /// Bazı bağlantılar (ana sayfadaki "Tümünü Gör", akışın ikinci adımı) henüz
  /// tasarlanmadığı için testler o ekranlara rotayla gidiyor.
  ///
  /// `IzBottomNav`ı çapa olarak KULLANMIYORUZ: ilk `pushRoute`tan sonra üste
  /// tam ekran bir sayfa geliyor ve alt çubuk ağaçtan kalkıyor, ikinci çağrı
  /// çapayı bulamıyor. `GoRouter` uygulama genelinde tek olduğu için hangi
  /// ekranın context'iyle çağrıldığı fark etmiyor — her ekranda bir
  /// `Scaffold` var.
  Future<void> pushRoute(WidgetTester tester, AppRoute route) async {
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).pushNamed(route.name);
    await settle(tester);
  }

  /// Anı listesi. Ana sayfadaki "Tümünü Gör" bağlantısı henüz tasarlanmadı.
  Future<void> openMemories(WidgetTester tester) =>
      pushRoute(tester, AppRoute.memories);

  /// Akışın DETAY adımı (editör).
  ///
  /// Yeni anı akışı iki adım: önce fotoğraf seçimi, sonra detaylar. İki adım
  /// arasındaki geçiş GALERİ ENTEGRASYONUNU bekliyor (platform paketi kararı
  /// ertelendi), bu yüzden testler detay adımına rotayı doğrudan çağırıyor.
  Future<void> openMemoryEditor(WidgetTester tester) =>
      pushRoute(tester, AppRoute.memoryNewDetails);

  testWidgets('uygulama giriş ekranıyla açılır', (tester) async {
    await pump(tester, signIn: false);

    expect(find.text('Tekrar hoş geldin'), findsOneWidget);
    // Giriş ekranında alt sekme çubuğu OLMAMALI.
    expect(find.byType(IzBottomNav), findsNothing);
  });

  testWidgets('giriş yapınca ana sayfaya geçilir', (tester) async {
    await pump(tester);

    expect(find.text('Tekrar hoş geldin'), findsNothing);
    expect(find.byType(IzBottomNav), findsOneWidget);
  });

  testWidgets('ana sayfa görsel + kavisli paneli gösterir', (tester) async {
    await pump(tester);

    expect(find.byType(HomeView), findsOneWidget);
    expect(find.byType(CurvedTopPanel), findsOneWidget);
    // Ana sayfa artık anı LİSTESİ değil.
    expect(find.text('Henüz bir iz yok'), findsNothing);
  });

  testWidgets('alt çubuktaki Ekle halka menüyü açar', (tester) async {
    await pump(tester);

    // Ekle artık DOĞRUDAN editöre gitmiyor: ortada bir menü açıyor.
    await tester.tap(find.text('Ekle'));
    await settle(tester);

    expect(find.text('Anı'), findsOneWidget);
    expect(find.text('Koleksiyon'), findsOneWidget);
    expect(find.text('Kişi'), findsOneWidget);
    // Menü açıkken editöre henüz geçilmedi.
    expect(find.text('Yeni Anı'), findsNothing);
  });

  testWidgets('menüdeki Anı yeni anı ekranını açar', (tester) async {
    await pump(tester);

    // Zincirin tamamı kuruluyor: alt çubuk → halka menü → GoRouter → editör.
    await tester.tap(find.text('Ekle'));
    await settle(tester);
    await tester.tap(find.text('Anı'));
    await settle(tester);

    expect(find.text('Yeni Anı'), findsWidgets);
  });

  testWidgets('anı listesi boş durumu gösterir', (tester) async {
    await pump(tester);
    await openMemories(tester);

    // Boş durum ekranı görünmeli (NFR-035) — henüz anı yok.
    expect(find.text('Henüz bir iz yok'), findsOneWidget);
    expect(find.text('İlk izini bırak'), findsOneWidget);
  });

  testWidgets('alt çubuk 4 sekme + Ekle eylemi gösterir', (tester) async {
    await pump(tester);

    expect(find.byType(IzBottomNav), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.text('Hayatım'), findsOneWidget);
    expect(find.text('Mağaza'), findsOneWidget);
    expect(find.text('Profilim'), findsOneWidget);
    // Ortadaki daire bir sekme DEĞİL, eylem.
    expect(find.text('Ekle'), findsOneWidget);
  });

  testWidgets('sekme değiştirince ilgili ekran açılır', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Profilim'));
    await settle(tester);

    // R-001 azaltımı: yedekleme uyarısı ayarlarda görünür olmalı.
    expect(find.text('Yalnız bu cihazda'), findsOneWidget);
    expect(find.text('Görünüm'), findsOneWidget);
  });

  testWidgets('FR-001 — onboarding tamamlanmadıysa oraya yönlendirilir', (
    tester,
  ) async {
    await pump(tester, onboardingCompleted: false);

    expect(find.textContaining('izini bırakanları biriktir'), findsOneWidget);
    // Onboarding'de alt sekme çubuğu olmamalı.
    expect(find.byType(IzBottomNav), findsNothing);
  });

  testWidgets('boş liste "İlk izini bırak" ile akışı başlatır', (tester) async {
    await pump(tester);
    await openMemories(tester);

    await tester.tap(find.text('İlk izini bırak'));
    await settle(tester);

    // Akış FOTOĞRAF adımıyla açılıyor, doğrudan formla değil.
    expect(find.text('Bu anıdan geriye hangi kareler kalsın?'), findsOneWidget);
    expect(find.text('Galeriden Fotoğraf Seç'), findsOneWidget);
  });

  testWidgets('fotoğraf seçilince bu adım KAPANIR, detay adımı açılır', (
    tester,
  ) async {
    // AKIŞIN TAMAMI: alt çubuk → halka menü → fotoğraf adımı → galeri →
    // detay adımı. Galeri yerine sahte seçici; gerçek eklenti testte çalışmaz.
    await pumpApp(
      tester,
      repository: repository,
      mediaPicker: FakeMediaPicker(paths: const ['/tmp/a.jpg', '/tmp/b.jpg']),
    );

    await tester.tap(find.text('Ekle'));
    await settle(tester);
    await tester.tap(find.text('Anı'));
    await settle(tester);
    expect(find.text('Galeriden Fotoğraf Seç'), findsOneWidget);

    await tester.tap(find.text('Galeriden Fotoğraf Seç'));
    await settle(tester);

    // Fotoğraf adımı KAPANMIŞ, detay adımı açılmış olmalı.
    expect(find.text('Galeriden Fotoğraf Seç'), findsNothing);
    expect(find.text('Kaydet'), findsOneWidget);

    // Seçilen fotoğraflar kullanıcıya gösteriliyor: "seçtiklerim gitti mi?"
    // sorusu doğmasın.
    //
    // SİLME DÜĞMESİNİ sayıyoruz, `Image`ı değil: dosyalar sahte olduğu için
    // şerit görsel yerine yer tutucu çiziyor ve `Image` hiç kurulmuyor. Her
    // karenin bir silme düğmesi var, o yüzden sayı doğrudan kare sayısı.
    expect(find.byIcon(AppIcons.clear), findsNWidgets(2));
  });

  testWidgets('galeriden vazgeçilirse fotoğraf adımında kalınır', (
    tester,
  ) async {
    await pumpApp(
      tester,
      repository: repository,
      mediaPicker: FakeMediaPicker(),
    );

    await tester.tap(find.text('Ekle'));
    await settle(tester);
    await tester.tap(find.text('Anı'));
    await settle(tester);

    await tester.tap(find.text('Galeriden Fotoğraf Seç'));
    await settle(tester);

    // Boş seçim bir karar; akış ilerlemiyor ama kullanıcı da uyarılmıyor.
    expect(find.text('Galeriden Fotoğraf Seç'), findsOneWidget);
    expect(find.text('Kaydet'), findsNothing);
  });

  testWidgets('detay adımında boş kayıt engellenir', (tester) async {
    await pump(tester);
    await openMemoryEditor(tester);

    expect(find.text('Detayları Gir'), findsOneWidget);

    // FR-012 — içerik yokken Kaydet devre dışı olmalı.
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Kaydet'),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('not yazınca kaydedilebilir ve anı listede görünür', (
    tester,
  ) async {
    await pump(tester);
    await openMemories(tester);
    await openMemoryEditor(tester);

    // Etiket artık `TextField`ın içinde DEĞİL, satırın solunda ayrı bir
    // metin (bkz. `MemoryInfoRow`). Alanı etiketten yola çıkarak buluyoruz.
    await tester.enterText(
      find.descendant(
        of: find.ancestor(
          of: find.text('Başlık'),
          matching: find.byType(MemoryInfoRow),
        ),
        matching: find.byType(TextField),
      ),
      'Kapadokya balon turu',
    );
    await settle(tester);

    await tester.tap(find.text('Kaydet'));
    await settle(tester);

    // Editör kapanmalı ve anı timeline'da görünmeli.
    expect(find.text('Kapadokya balon turu'), findsOneWidget);
  });
}
