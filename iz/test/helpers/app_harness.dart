/// GERÇEK uygulamayı test bağımlılıklarıyla kuran ortak yardımcı.
///
/// NEDEN AYRI DOSYA?
/// Bu kurulum (telefon ölçüsü + sahte SharedPreferences + sahte repository +
/// gecikmesiz kimlik doğrulama + giriş yapma) `app_smoke_test.dart` içinde
/// yazılmıştı. `app_shell_test.dart` da aynı zincire ihtiyaç duyunca kopyalamak
/// gerekiyordu; kopya, iki testin zamanla farklı ortamlarda koşması demektir.
///
/// Buradaki hiçbir şey üretim kodunu değiştirmiyor: her şey `overrides`
/// üzerinden veriliyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/app.dart';
import 'package:iz/core/media/media_picker.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/storage/app_preferences.dart';
import 'package:iz/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/domain/repositories/auth_repository.dart';
import 'package:iz/features/collections/data/repositories/collection_repository_impl.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/people/data/repositories/person_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_collection_repository.dart';
import 'fake_media_picker.dart';
import 'fake_memory_repository.dart';
import 'fake_person_repository.dart';

/// Gecikmesiz sahte kimlik doğrulama — her girişi kabul eder.
///
/// Gerçeği ([FirebaseAuthRepository]) ağa çıkıyor ve `Firebase.initializeApp`
/// istiyor; widget testinde ikisi de istenmez. Buradaki amaç kimlik
/// doğrulamayı değil, EKRANIN oturum açılınca ne yaptığını sınamak.
class InstantAuthRepository implements AuthRepository {
  static const _session = AuthSession(userId: 'test-user');

  @override
  Future<Result<AuthSession>> signInWithEmail(AuthCredentials c) async =>
      const Ok(_session);

  @override
  Future<Result<AuthSession>> signUpWithEmail(SignUpDraft d) async =>
      const Ok(_session);

  @override
  Future<Result<AuthSession>> signInWithProvider(AuthProvider p) async =>
      const Ok(_session);

  @override
  Future<Result<Unit>> sendPasswordReset(String email) async => okUnit;

  @override
  Future<Result<Unit>> signOut() async => okUnit;

  @override
  Future<Result<AuthSession?>> currentSession() async => const Ok(null);
}

/// `pumpAndSettle` YERİNE bunu kullan.
///
/// NEDEN? `pumpAndSettle` "hiçbir animasyon kalmayana kadar" bekler.
/// Ekranda bir `CircularProgressIndicator` varsa animasyon ASLA bitmez ve
/// test 10 dakika sonra timeout'a düşer. Bu, Flutter testlerinde en sık
/// karşılaşılan takılma sebebidir.
///
/// Bunun yerine sabit sayıda kare ilerletiyoruz: async veri gelir,
/// sayfa geçiş animasyonu tamamlanır, ama sonsuz animasyon bizi kilitlemez.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(); // ilk kare
  await tester.pump(const Duration(milliseconds: 100)); // stream/async veri
  await tester.pump(const Duration(milliseconds: 400)); // sayfa geçişi
  await tester.pump(const Duration(milliseconds: 100));
}

/// Uygulamayı test bağımlılıklarıyla kurar.
///
/// `overrides` sayesinde gerçek SharedPreferences ve gerçek veritabanı
/// dosyası yerine test sürümleri devreye giriyor — üretim kodunda tek satır
/// değişiklik yapmadan.
Future<void> pumpApp(
  WidgetTester tester, {
  required FakeMemoryRepository repository,
  bool onboardingCompleted = true,
  // Uygulama GİRİŞ EKRANIYLA açılıyor. Sekme/timeline testlerinin oraya
  // ulaşabilmesi için önce giriş yapılması gerekiyor; bu bayrak giriş
  // ekranının kendisini test ederken kapatılır.
  bool signIn = true,
  // Galeri bir platform eklentisi; testte gerçek seçici
  // `MissingPluginException` atar. Varsayılan olarak "kullanıcı vazgeçti"
  // davranışı veriyoruz; akışı sınayan testler kendi seçicisini geçiyor.
  FakeMediaPicker? mediaPicker,
  // Kişi deposu. Varsayılan BOŞ: çoğu test kişilerle ilgilenmiyor ve boş
  // liste gerçek bir yeni kullanıcının durumu. Kişi gerektiren testler
  // kendi deposunu geçiyor.
  FakePersonRepository? people,
  // Koleksiyon deposu. Varsayılan BOŞ: çoğu test koleksiyonla ilgilenmiyor
  // ve boş liste gerçek bir yeni kullanıcının durumu.
  //
  // DEPO seviyesinde sahteliyoruz, hesaplanmış listeyi override etmiyoruz:
  // aksi hâlde formdan kaydedilen koleksiyon listeye hiç ULAŞMAZDI ve
  // "oluştur → listede gör" akışı test edilemezdi.
  FakeCollectionRepository? collections,
}) async {
  // Varsayılan test yüzeyi 800×600'dür — yani YATAY bir masaüstü ölçüsü.
  // İZ bir telefon uygulaması; düzen kararları (görsel yüksekliği, sosyal
  // butonların alt alta geçmesi) o ölçüde farklı çalışıyor ve test gerçeği
  // yansıtmıyordu. Telefon ölçüsüne sabitliyoruz.
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // DİKKAT: shared_preferences tüm anahtarlara 'flutter.' öneki ekler.
  // Mock değerlerini bu önekle vermezsen okuma her zaman varsayılana düşer.
  SharedPreferences.setMockInitialValues({
    'flutter.onboarding_completed': onboardingCompleted,
    // Test ortamının sistem dili İngilizce'dir; metin beklentilerinin
    // sabit kalması için dili açıkça Türkçe'ye sabitliyoruz.
    'flutter.locale': 'tr',
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(AppPreferences(prefs)),
        // Repository'yi override ettiğimiz için appDatabaseProvider hiç
        // okunmaz — gerçek veritabanı bu teste hiç karışmaz.
        memoryRepositoryProvider.overrideWithValue(repository),
        personRepositoryProvider.overrideWithValue(
          people ?? FakePersonRepository(),
        ),
        collectionRepositoryProvider.overrideWithValue(
          collections ?? FakeCollectionRepository(),
        ),
        authRepositoryProvider.overrideWithValue(InstantAuthRepository()),
        mediaPickerProvider.overrideWithValue(mediaPicker ?? FakeMediaPicker()),
      ],
      child: const IzApp(),
    ),
  );
  await settle(tester);

  if (signIn && onboardingCompleted) {
    await tester.enterText(find.byType(TextField).first, 'ebrar@example.com');
    await tester.enterText(find.byType(TextField).last, 'gizli123');
    // Küçük ekranda buton katlanmanın altında kalabilir; önce görünür yap.
    await tester.ensureVisible(find.text('Giriş Yap'));
    await tester.pump();
    await tester.tap(find.text('Giriş Yap'));
    await settle(tester);
  }
}
