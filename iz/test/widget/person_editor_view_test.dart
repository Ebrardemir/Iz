/// Kişi formu — iki kip: yeni kişi ve kişiyi düzenle.
///
/// DÜZENLEME KİPİNİN sözü: alanlar DOLU gelir, fotoğraf tek karedir ve
/// yanındaki "+" onu DEĞİŞTİRİR, altta silme yolu vardır. Boş bir formla açmak
/// kullanıcıya her şeyi yeniden yazdırırdı.
///
/// Ekranın belirleyici kararı: İLİŞKİ SERBEST METİN. Referansta açılır liste
/// vardı; kullanıcı kendi yazmayı istedi ("Annem", "Babam"). Testler o metnin
/// gerçekten yazılabildiğini ve türün ondan türetildiğini sabitliyor.
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
import 'package:iz/features/people/data/repositories/person_repository_impl.dart';
import 'package:iz/features/people/presentation/views/person_editor_view.dart';
import 'package:iz/features/people/presentation/widgets/person_photo_picker.dart';
import 'package:iz/shared/widgets/iz_labeled_field.dart';
import 'package:iz/shared/widgets/iz_photo_strip.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_media_picker.dart';
import '../helpers/fake_person_repository.dart';
import '../helpers/people_fixture.dart';
import '../helpers/real_fonts.dart';

final _today = DateTime(2026, 8, 12);

late FakeMediaPicker picker;
late FakePersonRepository repository;

Future<void> pumpEditor(
  WidgetTester tester, {
  List<String> pickerReturns = const [],
  bool dark = false,

  /// null → yeni kişi; dolu → o kişiyi düzenle.
  String? personId,
}) async {
  tester.view
    ..physicalSize = const Size(390, 900)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  picker = FakeMediaPicker(paths: pickerReturns);
  // Düzenleme kipi kişiyi DEPODAN okuyor; kaydetme de oraya yazıyor.
  repository = FakePersonRepository(PeopleFixture.people);
  addTearDown(repository.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_today)),
        personRepositoryProvider.overrideWithValue(repository),
        mediaPickerProvider.overrideWithValue(picker),
      ],
      child: MaterialApp.router(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        // ROUTER'LI KURULUM: ekran kaydettikten ya da vazgeçtikten sonra
        // kendini kapatıyor (`context.pop`) ve o çağrı bir `GoRouter` arıyor.
        // İki rota var çünkü tek rotada kapatılacak bir şey olmuyor.
        routerConfig: GoRouter(
          initialLocation: '/new',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, _) => PersonEditorView(personId: personId),
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

/// Etiketiyle bir alanın girdisini bulur.
Finder fieldOf(String label) => find.descendant(
  of: find.ancestor(
    of: find.textContaining(label),
    matching: find.byType(IzLabeledField),
  ),
  matching: find.byType(TextField),
);

void main() {
  setUpAll(loadRealFonts);

  group('yerleşim', () {
    testWidgets('dört alan, fotoğraf ve kaydet duruyor', (tester) async {
      await pumpEditor(tester);

      expect(find.text('Yeni Kişi'), findsOneWidget);
      expect(find.byType(PersonPhotoPicker), findsOneWidget);
      expect(find.text('Fotoğraf Ekle'), findsOneWidget);

      for (final label in ['Ad', 'İlişkiniz', 'Doğum Tarihi', 'Kısa Not']) {
        expect(find.textContaining(label), findsWidgets, reason: label);
      }
      expect(find.text('Kişiyi Kaydet'), findsOneWidget);
    });

    testWidgets('geri oku DEĞİL çarpı, sağda tik var', (tester) async {
      // Bu bir akışın adımı değil, üste açılan tam ekran bir görev.
      await pumpEditor(tester);

      expect(find.byIcon(AppIcons.clear), findsOneWidget);
      expect(find.byIcon(AppIcons.back), findsNothing);
      expect(find.byIcon(AppIcons.check), findsOneWidget);
    });

    testWidgets('OPSİYONEL alanlar işaretli, zorunlular değil', (tester) async {
      // "(Opsiyonel)" ETİKETİN parçası, ipucu değil: ipucuna yazsaydık
      // kullanıcı yazmaya başladığı an kaybolurdu.
      await pumpEditor(tester);

      expect(find.textContaining('Doğum Tarihi (Opsiyonel)'), findsOneWidget);
      expect(find.textContaining('Kısa Not (Opsiyonel)'), findsOneWidget);
      expect(find.text('Ad'), findsOneWidget);
      expect(find.text('İlişkiniz'), findsOneWidget);
    });

    testWidgets('karanlık temada da çiziliyor', (tester) async {
      await pumpEditor(tester, dark: true);

      expect(tester.takeException(), isNull);
      expect(find.text('Yeni Kişi'), findsOneWidget);
    });
  });

  group('ilişki alanı', () {
    testWidgets('SERBEST METİN — açılır liste yok', (tester) async {
      // Referansta "Seçiniz" yazan bir açılır liste vardı; kullanıcı kendi
      // yazmayı istedi.
      await pumpEditor(tester);

      expect(find.byType(DropdownButton<Object?>), findsNothing);
      expect(find.text('Seçiniz'), findsNothing);
      expect(find.text('Örn. Annem'), findsOneWidget);
    });

    testWidgets('kullanıcının yazdığı metin alana giriyor', (tester) async {
      await pumpEditor(tester);

      await tester.enterText(fieldOf('İlişkiniz'), 'Annem');
      await settle(tester);

      expect(find.text('Annem'), findsOneWidget);
    });
  });

  group('doğum tarihi', () {
    testWidgets('alan SALT OKUNUR — elle yazılamıyor', (tester) async {
      // Doğum tarihi yıllar öncesi: elle yazmak uzun, takvimden yıl seçmek
      // kısa. Kullanıcı da "takvime tıklayınca takvim açılsın" dedi.
      await pumpEditor(tester);

      final field = tester.widget<TextField>(fieldOf('Doğum Tarihi'));
      expect(field.readOnly, isTrue);
    });

    testWidgets('alana dokunmak takvimi açıyor', (tester) async {
      await pumpEditor(tester);

      await tester.tap(find.text('Tarih seç'));
      await settle(tester);

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('takvim YIL seçimiyle açılıyor', (tester) async {
      // Gün takvimiyle açılsaydı kullanıcı 30 yıl geriye sayfa sayfa
      // gidecekti.
      await pumpEditor(tester);

      await tester.tap(find.text('Tarih seç'));
      await settle(tester);

      // 1996 = bugünün yılı − 30 (varsayılan başlangıç).
      expect(find.text('1996'), findsWidgets);
    });

    testWidgets('seçilen tarih alana yazılıyor', (tester) async {
      await pumpEditor(tester);

      await tester.tap(find.text('Tarih seç'));
      await settle(tester);

      // Yıla dokunmak GÜN ızgarasını açıyor; tarih ancak bir gün seçilince
      // tamamlanıyor.
      //
      // `pumpAndSettle`: takvimin mod geçişi animasyonlu ve sabit sayıda kare
      // pompalamak (`settle`) bazen yetmiyordu. Burada sonsuz animasyon yok,
      // yani takılma riski de yok.
      await tester.tap(find.text('1996'));
      await tester.pumpAndSettle();
      expect(find.text('15'), findsWidgets, reason: 'gün ızgarası açılmadı');

      await tester.tap(find.text('15').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();

      // İPUCU METNİNİN YOKLUĞUNA BAKMIYORUZ.
      //
      // `InputDecorator` ipucunu dolu alanda GİZLİYOR ama widget'ı ağaçta
      // bırakıyor (saydamlıkla animasyon yapabilmek için); `find.text('Tarih
      // seç')` onu bulmaya devam ediyor ve testi yanlış yere bakmaya
      // sürüklüyor — bir kez tam bunu yaşadık. Alanın İÇERİĞİNE bakıyoruz.
      expect(find.text('15 Ağustos 1996'), findsOneWidget);
    });

    testWidgets('GELECEK tarih seçilemiyor', (tester) async {
      // Doğum tarihi geçmişte olmak zorunda; sınırı takvim uyguluyor.
      await pumpEditor(tester);

      await tester.tap(find.text('Tarih seç'));
      await settle(tester);

      expect(find.text('2027'), findsNothing);
    });
  });

  group('fotoğraf', () {
    testWidgets('dokunmak galeriyi TEK fotoğrafla açıyor', (tester) async {
      // Bir kişinin bir avatarı var: plana bağlı bir kota değil, kavramsal
      // bir sınır.
      await pumpEditor(tester, pickerReturns: const ['a.jpg']);

      await tester.tap(find.text('Fotoğraf Ekle'));
      await settle(tester);

      expect(picker.receivedLimits, [1]);
    });

    testWidgets('seçildikten sonra KALDIRMA düğmesi çıkıyor', (tester) async {
      await pumpEditor(tester, pickerReturns: const ['a.jpg']);
      // Başta yalnızca AppBar'daki çarpı var.
      expect(find.byIcon(AppIcons.clear), findsOneWidget);

      await tester.tap(find.byType(PersonPhotoPicker));
      await settle(tester);

      // Şimdi biri de fotoğrafın köşesinde.
      expect(find.byIcon(AppIcons.clear), findsNWidgets(2));
      expect(find.text('Fotoğrafı değiştir'), findsOneWidget);
    });

    testWidgets('kaldırmak boş hâle döndürüyor', (tester) async {
      await pumpEditor(tester, pickerReturns: const ['a.jpg']);

      await tester.tap(find.byType(PersonPhotoPicker));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(PersonPhotoPicker),
          matching: find.byIcon(AppIcons.clear),
        ),
      );
      await settle(tester);

      expect(find.text('Fotoğraf Ekle'), findsOneWidget);
      expect(find.byIcon(AppIcons.clear), findsOneWidget);
    });

    testWidgets('galeriden vazgeçmek bir şey değiştirmiyor', (tester) async {
      await pumpEditor(tester);

      await tester.tap(find.text('Fotoğraf Ekle'));
      await settle(tester);

      expect(find.text('Fotoğraf Ekle'), findsOneWidget);
    });
  });

  group('kaydetme', () {
    testWidgets('AD BOŞKEN kaydedilmiyor, hata alanın altında', (tester) async {
      // FR-061 — ad zorunlu.
      await pumpEditor(tester);

      await tester.tap(find.text('Kişiyi Kaydet'));
      await settle(tester);

      expect(find.text('Bir ad yazmadan kaydedemeyiz.'), findsOneWidget);
      expect(find.byType(PersonEditorView), findsOneWidget, reason: 'kapandı');
    });

    testWidgets('yazmaya başlayınca hata KALKIYOR', (tester) async {
      // Kullanıcı sorunu çözüyor; uyarının orada kalması onu takip etmek olur.
      await pumpEditor(tester);

      await tester.tap(find.text('Kişiyi Kaydet'));
      await settle(tester);
      expect(find.text('Bir ad yazmadan kaydedemeyiz.'), findsOneWidget);

      await tester.enterText(fieldOf('Ad'), 'E');
      await settle(tester);

      expect(find.text('Bir ad yazmadan kaydedemeyiz.'), findsNothing);
    });

    testWidgets('SADECE BOŞLUK da ad sayılmıyor', (tester) async {
      await pumpEditor(tester);

      await tester.enterText(fieldOf('Ad'), '   ');
      await tester.tap(find.text('Kişiyi Kaydet'));
      await settle(tester);

      expect(find.text('Bir ad yazmadan kaydedemeyiz.'), findsOneWidget);
    });

    testWidgets('ad varsa ekran kapanıyor', (tester) async {
      // ⚠️ Kayıt hattı yok (`PersonDao` yazılmadı); doğrulama geçtiğinde ekran
      // kapanıp durumu bildiriyor. Hat kurulduğunda yalnızca o çağrı değişecek.
      await pumpEditor(tester);

      await tester.enterText(fieldOf('Ad'), 'Elif');
      await tester.tap(find.text('Kişiyi Kaydet'));
      await settle(tester);

      expect(find.byType(PersonEditorView), findsNothing);
    });

    testWidgets('AppBar\'daki tik de aynı işi yapıyor', (tester) async {
      // İki kaydet yolu bilinçli: uzun bir formda kullanıcı ya sona iner ya
      // üstteki tikle kapatır.
      await pumpEditor(tester);

      await tester.tap(find.byIcon(AppIcons.check));
      await settle(tester);

      expect(find.text('Bir ad yazmadan kaydedemeyiz.'), findsOneWidget);
    });

    testWidgets('çarpı vazgeçip kapatıyor', (tester) async {
      await pumpEditor(tester);

      await tester.enterText(fieldOf('Ad'), 'Elif');
      await tester.tap(find.byIcon(AppIcons.clear).first);
      await settle(tester);

      expect(find.byType(PersonEditorView), findsNothing);
    });
  });

  group('düzenleme kipi', () {
    // Önizleme verisindeki "Annem": adı, ilişkisi ve doğum tarihi var.
    const annem = 'person-annem';

    testWidgets('başlık "Kişiyi Düzenle"', (tester) async {
      await pumpEditor(tester, personId: annem);

      expect(find.text('Kişiyi Düzenle'), findsOneWidget);
      expect(find.text('Yeni Kişi'), findsNothing);
    });

    testWidgets('alanlar DOLU geliyor', (tester) async {
      // Kullanıcının isteği: "kişi adı ilişki doğum tarihi ve not yazılı gelir
      // kişi isterse düzenler".
      await pumpEditor(tester, personId: annem);

      expect(tester.widget<TextField>(fieldOf('Ad')).controller!.text, 'Annem');
      expect(
        tester.widget<TextField>(fieldOf('İlişkiniz')).controller!.text,
        isNotEmpty,
      );
      // Tarih alanında YIL DA var: düzenlenebilir bir alanda yılı saklamak
      // kullanıcıya doğru tarihi seçip seçmediğini gizlemek olurdu.
      expect(
        tester.widget<TextField>(fieldOf('Doğum Tarihi')).controller!.text,
        '18 Nisan 1968',
      );
    });

    testWidgets('dolu alanlar DÜZENLENEBİLİR', (tester) async {
      await pumpEditor(tester, personId: annem);

      await tester.enterText(fieldOf('Ad'), 'Anneciğim');
      await settle(tester);

      expect(find.text('Anneciğim'), findsOneWidget);
    });

    testWidgets('fotoğraf şeridi ve kesikli "+" kutusu var', (tester) async {
      // Referanstaki yapı: kare fotoğraf + yanında kesikli ekleme kutusu.
      // Yuvarlak seçici yalnızca yeni kişide.
      await pumpEditor(tester, personId: annem);

      expect(find.byType(IzPhotoStrip), findsOneWidget);
      expect(find.byType(PersonPhotoPicker), findsNothing);
      expect(find.byIcon(AppIcons.add), findsOneWidget);
    });

    testWidgets('şerit TEK fotoğrafla sınırlı', (tester) async {
      // Bir kişinin bir avatarı var: plana bağlı bir kota değil, kavramsal
      // bir sınır.
      await pumpEditor(tester, personId: annem);

      final strip = tester.widget<IzPhotoStrip>(find.byType(IzPhotoStrip));
      expect(strip.limit, 1);
      // Fotoğraf varken de "+" duruyor: orada anlamı DEĞİŞTİRMEK.
      expect(strip.showAddWhenFull, isTrue);
    });

    testWidgets('"+" galeriden fotoğraf getiriyor', (tester) async {
      await pumpEditor(
        tester,
        personId: annem,
        pickerReturns: ['/tmp/anne.jpg'],
      );

      await tester.tap(find.byIcon(AppIcons.add));
      await settle(tester);

      final strip = tester.widget<IzPhotoStrip>(find.byType(IzPhotoStrip));
      expect(strip.photos, hasLength(1));
      expect(strip.photos.single.localPreviewPath, '/tmp/anne.jpg');
    });

    testWidgets('çarpı fotoğrafı siliyor', (tester) async {
      await pumpEditor(
        tester,
        personId: annem,
        pickerReturns: ['/tmp/anne.jpg'],
      );

      await tester.tap(find.byIcon(AppIcons.add));
      await settle(tester);
      // Çarpıyı ŞERİDİN İÇİNDE arıyoruz: AppBar'daki kapatma düğmesi de aynı
      // ikonu kullanıyor ve ikona göre seçmek yanlışlıkla formu kapatıyordu.
      await tester.tap(
        find.descendant(
          of: find.byType(IzPhotoStrip),
          matching: find.byIcon(AppIcons.clear),
        ),
      );
      await settle(tester);

      final strip = tester.widget<IzPhotoStrip>(find.byType(IzPhotoStrip));
      expect(strip.photos, isEmpty);
      // Fotoğraf gitti ama ekleme kutusu duruyor.
      expect(find.byIcon(AppIcons.add), findsOneWidget);
    });

    testWidgets('kaydet düğmesi "Değişiklikleri Kaydet" diyor', (tester) async {
      // Kullanıcı yeni bir şey yaratmıyor, var olanı düzeltiyor.
      await pumpEditor(tester, personId: annem);

      expect(find.text('Değişiklikleri Kaydet'), findsOneWidget);
      expect(find.text('Kişiyi Kaydet'), findsNothing);
    });

    testWidgets('silme yolu var ve kaydetin ALTINDA', (tester) async {
      await pumpEditor(tester, personId: annem);

      final save = tester.getCenter(find.text('Değişiklikleri Kaydet'));
      final delete = tester.getCenter(find.text('Kişiyi Sil'));
      // İkisi eşit ağırlıkta görünmemeli: silme düğme değil metin.
      expect(delete.dy, greaterThan(save.dy));
      expect(find.byIcon(AppIcons.delete), findsOneWidget);
    });

    testWidgets('silme ONAY istiyor', (tester) async {
      // NFR-034. Metinler kişi detayındaki menüyle aynı: iki farklı uyarı
      // hangisinin doğru olduğunu sorgulatırdı.
      await pumpEditor(tester, personId: annem);

      await tester.tap(find.text('Kişiyi Sil'));
      await settle(tester);

      expect(find.text('Kişi silinsin mi?'), findsOneWidget);
      // FR-063 — silmek anıları silmiyor.
      expect(find.textContaining('anılar'), findsOneWidget);
    });

    testWidgets('onayı iptal etmek formda bırakıyor', (tester) async {
      await pumpEditor(tester, personId: annem);

      await tester.tap(find.text('Kişiyi Sil'));
      await settle(tester);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester);

      expect(find.byType(PersonEditorView), findsOneWidget);
      expect(find.text('Kişi silinsin mi?'), findsNothing);
    });

    testWidgets('tanınmayan kimlik boş formla açılıyor', (tester) async {
      // Eski bağlantı ya da elle yazılmış rota: çökmek yerine boş form.
      await pumpEditor(tester, personId: 'person-yok');

      expect(tester.takeException(), isNull);
      expect(tester.widget<TextField>(fieldOf('Ad')).controller!.text, isEmpty);
    });
  });

  group('yeni kişi kipi ayrı duruyor', () {
    testWidgets('yuvarlak seçici ve silme YOK', (tester) async {
      // Silme yolu yalnızca düzenlemede: henüz var olmayan bir kişiyi silmek
      // anlamsız.
      await pumpEditor(tester);

      expect(find.byType(PersonPhotoPicker), findsOneWidget);
      expect(find.byType(IzPhotoStrip), findsNothing);
      expect(find.text('Kişiyi Sil'), findsNothing);
    });
  });
}
