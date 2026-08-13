/// Anı oluşturma formu — akışın ikinci adımı.
///
/// Testlerin dayandığı ana iddia: form, seçimleri EKRANDA tutuyor ve hiçbirini
/// taslağın kimlik alanlarına yazmıyor (bkz. `MemoryFormSelection` notu).
/// Bu, veri hattı gelmeden önce yabancı anahtar ihlali almamamızı sağlayan
/// karar — bir "eksiklik" değil, bilinçli bir kural. Bozulursa kaydetme
/// çalışmaz hâle gelir, o yüzden test ediyoruz.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/core/entitlement/entitlement.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/media/media_picker.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/presentation/view_models/memory_editor_view_model.dart';
import 'package:iz/features/memories/presentation/views/memory_editor_view.dart';
import 'package:iz/features/memories/presentation/widgets/memory_info_card.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/shared/widgets/iz_photo_strip.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_media_picker.dart';
import '../helpers/fake_memory_repository.dart';
import '../helpers/real_fonts.dart';

/// Testin "bugün"ü — tarih alanının başlangıç değeri buna bağlı.
final _today = DateTime(2026, 8, 12);

late FakeMemoryRepository repository;
late FakeMediaPicker picker;

/// Kayıtlı bir anı — düzenleme kipini sınamak için.
///
/// BÜTÜN ALANLAR DOLU: testlerin çoğu "düzenlemede bu alan dolu geliyor mu"
/// sorusunu soruyor ve boş bir alan yanlış nedenle geçen bir test üretirdi.
MemoryDetail existingMemory({int photoCount = 2}) => MemoryDetail(
  memory: Memory(
    id: 'm1',
    occurredAt: DateTime(2024, 5, 12),
    isFavorite: false,
    mediaCount: photoCount,
    personCount: 2,
    title: 'İlk İzmir Tatilimiz',
    note: "Kordon'da gün batımı.",
    categoryId: 'cat_travel',
  ),
  people: const [
    Person(
      id: 'p1',
      name: 'Annem',
      kind: PersonKind.human,
      relationType: RelationType.parent,
    ),
    Person(
      id: 'p2',
      name: 'Elif',
      kind: PersonKind.human,
      relationType: RelationType.sibling,
    ),
  ],
  collections: const [
    MemoryCollection(
      id: 'c1',
      title: 'Ege Gezileri',
      visibility: CollectionVisibility.private,
    ),
  ],
  ritual: const Ritual(
    id: 'r1',
    title: 'Yaz Tatilleri',
    recurrenceType: RecurrenceType.seasonal,
    iconKey: 'summer',
  ),
  ritualYear: 2024,
  media: [
    for (var i = 0; i < photoCount; i++)
      MediaItem(
        id: 'media_$i',
        type: MediaType.photo,
        originalStatus: MediaOriginalStatus.available,
        localPreviewPath: 'assets/images/home/memory_coffee.jpg',
      ),
  ],
  location: const MemoryLocation(id: 'l1', label: 'Kordon, İzmir'),
);

Future<ProviderContainer> pumpForm(
  WidgetTester tester, {
  List<String> photos = const [],
  Size size = const Size(390, 844),
  bool dark = false,
  MemoryDetail? existing,
  List<String> pickerReturns = const [],
  IzPlan plan = IzPlan.free,
  bool withRouter = false,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  repository = existing == null
      ? FakeMemoryRepository()
      : (FakeMemoryRepository([existing.memory])..detail = existing);
  addTearDown(repository.dispose);

  picker = FakeMediaPicker(paths: pickerReturns);
  _editedId = existing?.id;

  final container = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(FixedClock(_today)),
      memoryRepositoryProvider.overrideWithValue(repository),
      mediaPickerProvider.overrideWithValue(picker),
      currentPlanProvider.overrideWithValue(plan),
    ],
  );
  addTearDown(container.dispose);

  final editor = MemoryEditorView(
    memoryId: existing?.id,
    pickedPhotoPaths: photos,
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: withRouter
          // ROUTER'LI KURULUM — yalnızca gerektiğinde.
          //
          // Ekran kaydettikten ya da sildikten sonra kendini KAPATIYOR
          // (`context.pop`) ve o çağrı bir `GoRouter` arıyor. Düz bir
          // `MaterialApp` ile "No GoRouter found in context" düşüyor.
          //
          // İki rota var çünkü tek rotada kapatılacak bir şey olmuyor:
          // önce boş bir sayfa, üstüne editör.
          ? MaterialApp.router(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              locale: const Locale('tr'),
              localizationsDelegates: AppL10n.localizationsDelegates,
              supportedLocales: AppL10n.supportedLocales,
              routerConfig: GoRouter(
                initialLocation: '/editor',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const Scaffold(),
                    routes: [
                      GoRoute(path: 'editor', builder: (_, _) => editor),
                    ],
                  ),
                ],
              ),
            )
          : MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              locale: const Locale('tr'),
              localizationsDelegates: AppL10n.localizationsDelegates,
              supportedLocales: AppL10n.supportedLocales,
              home: editor,
            ),
    ),
  );
  await settle(tester);
  return container;
}

/// Düzenlenen anının kimliği — `pumpForm(existing: …)` ile aynı olmalı.
String? _editedId;

MemoryEditorState readState(ProviderContainer container) =>
    container.read(memoryEditorProvider(_editedId));

/// Bir satırın sağ tarafındaki girdiyi bulur.
///
/// Etiketten yola çıkıyoruz, sıradan değil: satır sırası değişse de test
/// doğru alanı bulmalı (daha önce sekmeleri konuma göre bulan bir test
/// tautolojiye dönüşmüştü — bkz. `app_shell_test.dart`).
Finder fieldOf(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(MemoryInfoRow)),
  matching: find.byType(TextField),
);

Future<void> openPicker(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settle(tester);
}

void main() {
  setUpAll(loadRealFonts);

  group('yerleşim', () {
    testWidgets('sekiz satır da etiketiyle duruyor', (tester) async {
      await pumpForm(tester);

      for (final label in [
        'Başlık',
        'Tarih',
        'Konum',
        'Not',
        'Kişiler',
        'Kategori',
        'Koleksiyon',
        'Seri',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('başlık ortalı ve "Detayları Gir"', (tester) async {
      await pumpForm(tester);

      expect(find.text('Detayları Gir'), findsOneWidget);
      expect(tester.getCenter(find.text('Detayları Gir')).dx, closeTo(195, 1));
    });

    testWidgets('değerler SOLDAN, hepsi tek dikey hatta başlıyor', (
      tester,
    ) async {
      // Türkçe soldan sağa okunur; değer kolonunun sağdan başlaması gözü her
      // satırda geri sardırıyordu. Soldan hizalamanın bedeli sabit etiket
      // sütunu (bkz. memory_info_card.dart dosya notu) — bu test o sütunun
      // gerçekten sabit kaldığını doğruluyor.
      await pumpForm(tester);

      final lefts = [
        for (final label in ['Başlık', 'Tarih', 'Konum', 'Not'])
          tester.getTopLeft(fieldOf(label)).dx,
      ];

      expect(
        lefts.every((x) => (x - lefts.first).abs() < 0.5),
        isTrue,
        reason: 'değerler hizasız: $lefts',
      );
    });

    testWidgets('en uzun etiket ("Koleksiyon") sütuna sığıyor', (tester) async {
      // Sabit sütunun tek riski bu: dar kalırsa etiket üç noktayla kesilir.
      await pumpForm(tester);

      // `size.width` İŞE YARAMAZ: metin sabit sütunu doldurduğu için her
      // durumda 88 döner. Metnin GERÇEKTEN ihtiyaç duyduğu genişliği
      // soruyoruz — kesilme ancak bu, sütundan büyükse olur.
      final label = tester.renderObject<RenderParagraph>(
        find.text('Koleksiyon'),
      );
      expect(
        label.getMaxIntrinsicWidth(double.infinity),
        lessThan(MemoryInfoRow.kLabelWidth),
        reason: 'etiket sütunu dar, kesilme riski var',
      );
    });

    testWidgets('satırların hepsi aynı yükseklikte', (tester) async {
      // Referanstaki düzenli defter hissi buna bağlı. Daha önce metin
      // satırları 64, seçim satırları 48 pikseldi.
      await pumpForm(tester);

      final heights = [
        for (final label in [
          'Başlık',
          'Tarih',
          'Konum',
          'Kişiler',
          'Kategori',
          'Koleksiyon',
          'Seri',
        ])
          tester
              .getSize(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(MemoryInfoRow),
                ),
              )
              .height,
      ];

      expect(
        heights.every((h) => h == MemoryInfoRow.kMinHeight),
        isTrue,
        reason: 'satır yükseklikleri eşit değil: $heights',
      );
    });

    testWidgets('karanlık temada da çiziliyor', (tester) async {
      await pumpForm(tester, dark: true);
      expect(tester.takeException(), isNull);
      expect(find.text('Başlık'), findsOneWidget);
    });
  });

  group('başlık', () {
    testWidgets('30 karakterden sonrası yazılamıyor', (tester) async {
      // FR-011. Sınırı burada durdurmak, kaydete basınca hata görmekten iyi.
      final container = await pumpForm(tester);

      await tester.enterText(fieldOf('Başlık'), 'a' * 45);
      await settle(tester);

      expect(
        readState(container).draft.title?.length,
        MemoryEditorView.kTitleMaxLength,
      );
    });

    testWidgets('sayaç ("12/30") gösterilmiyor', (tester) async {
      // Kartın çizgi düzenini bozuyordu; sınır zaten yazmayı durduruyor.
      await pumpForm(tester);
      await tester.enterText(fieldOf('Başlık'), 'Kapadokya');
      await settle(tester);

      expect(find.textContaining('/30'), findsNothing);
    });
  });

  group('tarih', () {
    testWidgets('bugünün tarihiyle, UZUN biçimde dolu geliyor', (tester) async {
      // Referans tasarımın kararı: bu bir anının tarihi, bir fatura numarası
      // değil. Ay adı yazılınca satır bir cümle gibi okunuyor.
      await pumpForm(tester);
      expect(find.text('12 Ağustos 2026'), findsOneWidget);
    });

    testWidgets('KISA biçimde yazmak kabul ediliyor', (tester) async {
      // Ekranda uzun biçim yazıyor ama kullanıcı tuş tasarrufu yapabilir;
      // yalnızca gösterdiğimiz biçimi kabul etmek onu hataya düşürürdü.
      final container = await pumpForm(tester);

      await tester.enterText(fieldOf('Tarih'), '3.5.2024');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(readState(container).draft.occurredAt, DateTime(2024, 5, 3));
      expect(readState(container).dateError, isNull);
    });

    testWidgets('UZUN biçimde yazmak kabul ediliyor', (tester) async {
      final container = await pumpForm(tester);

      await tester.enterText(fieldOf('Tarih'), '3 Mayıs 2024');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(readState(container).draft.occurredAt, DateTime(2024, 5, 3));
    });

    testWidgets('anlaşılmayan metin hata veriyor, tarihi bozmuyor', (
      tester,
    ) async {
      final container = await pumpForm(tester);

      await tester.enterText(fieldOf('Tarih'), 'dün falan');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(readState(container).dateError, isNotNull);
      expect(
        readState(container).draft.occurredAt,
        _today,
        reason: 'geçersiz girdi eski değeri silmemeli',
      );
      expect(find.textContaining('Tarihi anlayamadım'), findsOneWidget);
    });

    testWidgets('GELECEK tarih reddediliyor', (tester) async {
      // FR-013 — geçmişe izin var, geleceğe yok.
      final container = await pumpForm(tester);

      await tester.enterText(fieldOf('Tarih'), '1.1.2030');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(readState(container).dateError, 'Gelecek bir tarih seçemezsin.');
      expect(readState(container).draft.occurredAt, _today);
    });

    testWidgets('yazarken HER TUŞTA hata basmıyor', (tester) async {
      // "1" yazan kullanıcıya hemen "anlayamadım" demek kaba olurdu.
      final container = await pumpForm(tester);

      await tester.enterText(fieldOf('Tarih'), '1');
      await settle(tester);

      expect(readState(container).dateError, isNull);
    });

    testWidgets('SATIRIN kendisi takvimi açıyor', (tester) async {
      // Sağdaki takvim bir düğme DEĞİL, bir işaret: `IconButton`ın iç dolgusu
      // ikonu öteki satırların okundan 10 piksel içeride bırakıyordu. Satırı
      // tıklanabilir yapmak hem hizayı düzeltti hem dokunma hedefini büyüttü.
      await pumpForm(tester);

      await tester.tap(find.text('Tarih'));
      await settle(tester);

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });

  group('konum', () {
    testWidgets('serbest metin state\'e yazılıyor', (tester) async {
      final container = await pumpForm(tester);

      await tester.enterText(fieldOf('Konum'), 'Çeşme');
      await settle(tester);

      expect(readState(container).locationLabel, 'Çeşme');
    });

    testWidgets('konum taslağın locationId alanına YAZILMIYOR', (tester) async {
      // Serbest metni bir konum KAYDINA çevirecek hat henüz yok; yazsaydık
      // yabancı anahtar ihlali alırdık.
      final container = await pumpForm(tester);

      await tester.enterText(fieldOf('Konum'), 'Çeşme');
      await settle(tester);

      expect(readState(container).draft.locationId, isNull);
    });
  });

  group('not', () {
    testWidgets('yazılan not taslağa geçiyor', (tester) async {
      final container = await pumpForm(tester);

      await tester.enterText(fieldOf('Not'), 'Deniz çok soğuktu.');
      await settle(tester);

      expect(readState(container).draft.note, 'Deniz çok soğuktu.');
    });

    testWidgets('uzun not satırı büyütmüyor: pencere üç satırda kalıyor', (
      tester,
    ) async {
      // Notun bütün ekranı yutmasına izin vermiyoruz; içi kayıyor.
      final container = await pumpForm(tester);

      final before = tester.getSize(find.byType(MemoryInfoCard)).height;
      await tester.enterText(
        fieldOf('Not'),
        List.filled(80, 'kelime').join(' '),
      );
      await settle(tester);
      final after = tester.getSize(find.byType(MemoryInfoCard)).height;

      expect(after - before, lessThan(60), reason: 'kart kontrolsüz büyüdü');
      expect(readState(container).draft.note, isNotNull);
    });
  });

  group('seçim satırları', () {
    testWidgets('KİŞİLER çok seçimli ve etiketleri satırda gösteriyor', (
      tester,
    ) async {
      final container = await pumpForm(tester);

      await openPicker(tester, 'Kişiler');
      await tester.tap(find.text('Annem'));
      await settle(tester);
      await tester.tap(find.text('Elif'));
      await settle(tester);
      await tester.tap(find.text('Tamam'));
      await settle(tester);

      expect(readState(container).people.map((p) => p.label), [
        'Annem',
        'Elif',
      ]);
      expect(find.text('Annem, Elif'), findsOneWidget);
    });

    testWidgets('KATEGORİ tek seçimli ve adı çeviriden geliyor', (
      tester,
    ) async {
      // Sistem kategorilerinin adı `category_l10n.dart`tan gelir —
      // önizleme verisi değil.
      final container = await pumpForm(tester);

      await openPicker(tester, 'Kategori');
      await tester.tap(find.text('Seyahat'));
      await settle(tester);

      expect(readState(container).category?.id, 'cat_travel');
      expect(find.text('Seyahat'), findsOneWidget);
    });

    testWidgets('KOLEKSİYON çok seçimli', (tester) async {
      final container = await pumpForm(tester);

      await openPicker(tester, 'Koleksiyon');
      await tester.tap(find.text('Kapadokya 2026'));
      await settle(tester);
      await tester.tap(find.text('Tamam'));
      await settle(tester);

      expect(readState(container).collections.map((c) => c.id), [
        'collection_1',
      ]);
    });

    testWidgets('SERİ tek seçimli', (tester) async {
      final container = await pumpForm(tester);

      await openPicker(tester, 'Seri');
      await tester.tap(find.text('Yaz Tatillerimiz'));
      await settle(tester);

      expect(readState(container).series?.id, 'series_1');
    });

    testWidgets('seçim yapılmadan önce "Seç" yer tutucusu duruyor', (
      tester,
    ) async {
      await pumpForm(tester);
      expect(find.text('Seç'), findsNWidgets(4));
    });

    testWidgets('vazgeçince seçim değişmiyor', (tester) async {
      final container = await pumpForm(tester);

      await openPicker(tester, 'Seri');
      await tester.tap(find.text('Vazgeç'));
      await settle(tester);

      expect(readState(container).series, isNull);
    });

    // Kullanıcının isteği: liste açıldığında en altta ekleme yolu olsun.
    //
    // Dört ayrı test, tek testte dört kez `pumpForm` DEĞİL: aynı test içinde
    // ağacı yeniden kurmak Riverpod'un autoDispose zamanlayıcısını askıda
    // bırakıyor ve test `!timersPending` ile düşüyor.
    for (final label in ['Kişiler', 'Kategori', 'Koleksiyon', 'Seri']) {
      testWidgets('$label listesinde "+ Yeni ekle" satırı var', (tester) async {
        await pumpForm(tester);
        await openPicker(tester, label);

        expect(find.text('Yeni ekle'), findsOneWidget);
      });
    }

    testWidgets('seçimler taslağın KİMLİK alanlarına yazılmıyor', (
      tester,
    ) async {
      // Bu testin varlık sebebi dosya başındaki nottur: `PRAGMA
      // foreign_keys = ON` ve karşılık gelen tablolar boş. Buraya bir gün
      // "seçimi taslağa da yazayım" diye dokunulursa kaydetme kırılır ve
      // bu test önce uyarır.
      final container = await pumpForm(tester);

      await openPicker(tester, 'Kategori');
      await tester.tap(find.text('Seyahat'));
      await settle(tester);

      await openPicker(tester, 'Kişiler');
      await tester.tap(find.text('Annem'));
      await settle(tester);
      await tester.tap(find.text('Tamam'));
      await settle(tester);

      final draft = readState(container).draft;
      expect(draft.personIds, isEmpty);
      expect(draft.collectionIds, isEmpty);
      expect(draft.ritualId, isNull);

      // KATEGORİ İSTİSNA ve bu bilinçli: sistem kategorileri ilk açılışta
      // veritabanına tohumlanıyor, yani `cat_travel` gerçek bir satır.
      // Yazmamak kullanıcının seçtiği kategoriyi kaydetmemek olurdu.
      expect(draft.categoryId, 'cat_travel');
    });
  });

  group('kaydet', () {
    testWidgets('içerik yokken düğme kapalı', (tester) async {
      // FR-012: tamamen boş kayıt kaydedilemez.
      await pumpForm(tester);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Kaydet'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('başlık yazılınca düğme açılıyor', (tester) async {
      await pumpForm(tester);

      await tester.enterText(fieldOf('Başlık'), 'Çeşme');
      await settle(tester);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Kaydet'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('kaydet ALTTA, AppBar\'da değil', (tester) async {
      await pumpForm(tester);

      final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      expect(
        tester.getTopLeft(find.widgetWithText(FilledButton, 'Kaydet')).dy,
        greaterThan(appBarBottom),
      );
    });
  });

  group('favori', () {
    testWidgets('AppBar\'daki kalp taslağı çeviriyor', (tester) async {
      // FR-019. Favori bir ALAN değil, kaydın tamamına vurulan bir işaret —
      // o yüzden kartın içinde değil AppBar'da.
      final container = await pumpForm(tester);

      expect(readState(container).draft.isFavorite, isFalse);
      await tester.tap(find.byIcon(AppIcons.favorite));
      await settle(tester);
      expect(readState(container).draft.isFavorite, isTrue);
    });

    testWidgets('kartın içinde favori satırı YOK', (tester) async {
      // Referansın tek kart + tek düğme sadeliği: favori satırı formu
      // "başlık, tarih, favori" gibi yanlış bir sıraya sokuyordu.
      await pumpForm(tester);

      expect(find.byType(Switch), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MemoryInfoCard),
          matching: find.text('Favorilere ekle'),
        ),
        findsNothing,
      );
    });
  });

  group('fotoğraf şeridi', () {
    testWidgets('her karenin kendi silme düğmesi var', (tester) async {
      await pumpForm(tester, photos: const ['a.jpg', 'b.jpg']);

      expect(find.byType(IzPhotoStrip), findsOneWidget);
      expect(find.byIcon(AppIcons.clear), findsNWidgets(2));
    });

    testWidgets('X o fotoğrafı kaldırıyor', (tester) async {
      final container = await pumpForm(
        tester,
        photos: const ['a.jpg', 'b.jpg', 'c.jpg'],
      );
      expect(readState(container).photos.length, 3);

      // İLK DEĞİL ORTADAKİNE dokunuyoruz: hep ilkini silen bir hata da
      // "üç oldu iki" testini geçerdi.
      await tester.tap(find.byIcon(AppIcons.clear).at(1));
      await settle(tester);

      expect(readState(container).photos.map((p) => p.localPreviewPath), [
        'a.jpg',
        'c.jpg',
      ]);
    });

    testWidgets('limit dolmadıkça EKLEME kutusu var', (tester) async {
      // Free planda 3; ikisi seçiliyse bir tane daha eklenebilir.
      await pumpForm(tester, photos: const ['a.jpg', 'b.jpg']);

      expect(find.byIcon(AppIcons.add), findsOneWidget);
      expect(find.textContaining('En fazla'), findsNothing);
    });

    testWidgets('limit dolunca kutu gider, SEBEBİ yazar', (tester) async {
      // Kaybolan bir düğme tek başına bilgi değil: kullanıcı "+ nereye
      // gitti?" diye kalıyor.
      await pumpForm(tester, photos: const ['a.jpg', 'b.jpg', 'c.jpg']);

      expect(find.byIcon(AppIcons.add), findsNothing);
      expect(find.text('En fazla 3 fotoğraf seçebilirsin.'), findsOneWidget);
    });

    testWidgets('İZ+ planında limit daha yüksek', (tester) async {
      // Şerit limiti KENDİ İÇİNDE tutmuyor, entitlement matrisinden alıyor.
      // Üç kare + ekleme kutusu ekranı taşıyor; şerit KAYDIRILABİLİR olduğu
      // için kutu ağaçta yok (`ListView` görünmeyeni kurmuyor) — o yüzden
      // ikona değil, şeridin kaç öğe kurduğuna bakıyoruz.
      await pumpForm(
        tester,
        photos: const ['a.jpg', 'b.jpg', 'c.jpg'],
        plan: IzPlan.plus,
      );

      await tester.drag(find.byType(IzPhotoStrip), const Offset(-200, 0));
      await settle(tester);

      expect(find.byIcon(AppIcons.add), findsOneWidget);
    });

    testWidgets('ekleme kutusu galeriyi KALAN KOTA kadar açıyor', (
      tester,
    ) async {
      // Tam limiti geçmek, kullanıcıya üç fotoğraf seçtirip sonra ikisini
      // elinden almak olurdu.
      await pumpForm(
        tester,
        photos: const ['a.jpg', 'b.jpg'],
        pickerReturns: const ['c.jpg'],
      );

      await tester.tap(find.byIcon(AppIcons.add));
      await settle(tester);

      expect(picker.receivedLimits, [1]);
    });

    testWidgets('galeriden seçilen kare şeride ekleniyor', (tester) async {
      final container = await pumpForm(
        tester,
        photos: const ['a.jpg'],
        pickerReturns: const ['b.jpg'],
      );

      await tester.tap(find.byIcon(AppIcons.add));
      await settle(tester);

      expect(readState(container).photos.length, 2);
      expect(find.byIcon(AppIcons.clear), findsNWidgets(2));
    });

    testWidgets('galeriden vazgeçmek şeridi değiştirmiyor', (tester) async {
      final container = await pumpForm(tester, photos: const ['a.jpg']);

      await tester.tap(find.byIcon(AppIcons.add));
      await settle(tester);

      expect(readState(container).photos.length, 1);
    });

    testWidgets('AYNI dosya iki kez eklenmiyor', (tester) async {
      final container = await pumpForm(
        tester,
        photos: const ['a.jpg'],
        pickerReturns: const ['a.jpg'],
      );

      await tester.tap(find.byIcon(AppIcons.add));
      await settle(tester);

      expect(readState(container).photos.length, 1);
    });
  });

  group('düzenleme kipi', () {
    testWidgets('BÜTÜN alanlar dolu açılıyor', (tester) async {
      // Eskiden yalnızca başlık ve not doluydu; konum, kişiler, kategori,
      // koleksiyon ve seri boş geliyordu ve kullanıcı kaydettiğini
      // kaybetmiş sanıyordu.
      await pumpForm(tester, existing: existingMemory());

      expect(find.text('İlk İzmir Tatilimiz'), findsOneWidget);
      expect(find.text('12 Mayıs 2024'), findsOneWidget);
      expect(find.text('Kordon, İzmir'), findsOneWidget);
      expect(find.text("Kordon'da gün batımı."), findsOneWidget);
      expect(find.text('Annem, Elif'), findsOneWidget);
      expect(find.text('Seyahat'), findsOneWidget);
      expect(find.text('Ege Gezileri'), findsOneWidget);
      expect(find.text('Yaz Tatilleri'), findsOneWidget);
      expect(find.text('Seç'), findsNothing, reason: 'boş kalan alan var');
    });

    testWidgets('kayıtlı fotoğraflar şeritte', (tester) async {
      await pumpForm(tester, existing: existingMemory());

      expect(find.byIcon(AppIcons.clear), findsNWidgets(2));
    });

    testWidgets('başlık "Düzenle"', (tester) async {
      await pumpForm(tester, existing: existingMemory());

      expect(find.text('Düzenle'), findsOneWidget);
      expect(find.text('Detayları Gir'), findsNothing);
    });

    testWidgets('düğme "Değişiklikleri Kaydet"', (tester) async {
      // Kullanıcı yeni bir şey yaratmıyor, var olanı değiştiriyor.
      await pumpForm(tester, existing: existingMemory());

      expect(
        find.widgetWithText(FilledButton, 'Değişiklikleri Kaydet'),
        findsOneWidget,
      );
    });

    testWidgets('SİL yalnızca düzenlemede var', (tester) async {
      // Anı detayında sağ üstteki çöp ikonundan kaldırdık; doğru yeri burası.
      await pumpForm(tester, existing: existingMemory());

      expect(find.widgetWithText(TextButton, 'Sil'), findsOneWidget);
    });

    testWidgets('kategori kimliği TASLAĞA da yazılıyor', (tester) async {
      // Öteki üç seçim yalnızca ekranda yaşıyor (karşılığı olan satır yok);
      // kategori farklı — sistem kategorileri veritabanına tohumlanıyor.
      final container = await pumpForm(tester, existing: existingMemory());

      await tester.tap(find.text('Kategori'));
      await settle(tester);
      await tester.tap(find.text('Aile'));
      await settle(tester);

      expect(readState(container).draft.categoryId, 'cat_family');
    });
  });

  group('yeni anı kipi', () {
    testWidgets('SİL yok', (tester) async {
      // Silinecek bir kayıt yok.
      await pumpForm(tester);

      expect(find.widgetWithText(TextButton, 'Sil'), findsNothing);
    });

    testWidgets('düğme "Kaydet"', (tester) async {
      await pumpForm(tester);

      expect(find.widgetWithText(FilledButton, 'Kaydet'), findsOneWidget);
    });

    testWidgets('fotoğraf yoksa şerit yine EKLEME kutusuyla duruyor', (
      tester,
    ) async {
      // Fotoğraf seçmeden forma gelen kullanıcı (rotayla) yine ekleyebilmeli.
      await pumpForm(tester);

      expect(find.byType(IzPhotoStrip), findsOneWidget);
      expect(find.byIcon(AppIcons.add), findsOneWidget);
    });
  });

  group('silme', () {
    testWidgets('ONAY diyaloğundan geçiyor', (tester) async {
      // NFR-034.
      await pumpForm(tester, existing: existingMemory());

      await tester.tap(find.widgetWithText(TextButton, 'Sil'));
      await settle(tester);

      expect(find.text('Anı silinsin mi?'), findsOneWidget);
      expect(repository.memories.single.isArchived, isFalse);
    });

    testWidgets('vazgeçmek hiçbir şey yapmıyor', (tester) async {
      await pumpForm(tester, existing: existingMemory());

      await tester.tap(find.widgetWithText(TextButton, 'Sil'));
      await settle(tester);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester);

      expect(repository.memories, hasLength(1));
    });

    testWidgets('onaylayınca siliniyor, ekran kapanıyor, GERİ AL çıkıyor', (
      tester,
    ) async {
      // FR-014 (çöp kutusu) + FR-015 (geri alınabilir) + NFR-034 (bildirim).
      await pumpForm(tester, existing: existingMemory(), withRouter: true);

      await tester.tap(find.widgetWithText(TextButton, 'Sil'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
      await settle(tester);

      expect(repository.memories, isEmpty);
      expect(find.byType(MemoryEditorView), findsNothing, reason: 'kapanmadı');
      expect(find.text('Anı çöp kutusuna taşındı'), findsOneWidget);
      expect(find.text('Geri al'), findsOneWidget);
    });
  });

  group('KAYDEDİLEN ve KAYDEDİLMEYEN alanlar', () {
    // BU GRUP BİR BELGE.
    //
    // Ekran tarafı bitti: bütün alanlar dolduruluyor, düzenlemede dolu
    // açılıyor. Ama veri katmanı henüz hepsini taşıyamıyor ve hangisinin
    // taşındığı gözle görülmüyor — kullanıcı konumu yazıp kaydediyor, geri
    // dönünce alan boş.
    //
    // Sebep TEK: `Memories` tablosunun kendi kolonları yazılıyor, ilişki
    // tabloları için ise EBEVEYN SATIRLAR yok (`People`, `Collections`,
    // `Rituals`, `Locations`, `MediaItems` tablolarına hiçbir yerde satır
    // yazılmıyor; DAO'ları yazılmadı). `PRAGMA foreign_keys = ON` olduğu
    // için var olmayan bir kimlikle kaydetmek `saveDraft`ı düşürürdü, o
    // yüzden ViewModel o kimlikleri bilerek taslağa koymuyor.
    //
    // Testler bugünkü durumu KİLİTLİYOR. DAO'lar yazıldığında buradaki
    // "kaydedilmiyor" iddiaları kırılacak — kırılması da doğru, o zaman
    // güncellenecekler.

    testWidgets('başlık, not, tarih, kategori ve favori KAYDEDİLİYOR', (
      tester,
    ) async {
      // `withRouter`: kaydetme başarılı olunca ekran kendini kapatıyor
      // (`context.pop`) ve o çağrı bir `GoRouter` arıyor.
      await pumpForm(tester, withRouter: true);

      await tester.enterText(fieldOf('Başlık'), 'Kapadokya');
      await tester.enterText(fieldOf('Not'), 'Balonlar havalandı.');
      await settle(tester);

      await tester.tap(find.text('Kategori'));
      await settle(tester);
      await tester.tap(find.text('Seyahat'));
      await settle(tester);

      await tester.tap(find.byIcon(AppIcons.favorite));
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await settle(tester);

      final saved = repository.memories.single;
      expect(saved.title, 'Kapadokya');
      expect(saved.note, 'Balonlar havalandı.');
      expect(saved.occurredAt, _today);
      expect(saved.categoryId, 'cat_travel');
      expect(saved.isFavorite, isTrue);

      // Kaydettikten sonra ekran kapanıyor. `savedId`ye BAKMIYORUZ: provider
      // autoDispose ve ekran kapanınca atılıyor; sonradan okumak sıfırlanmış
      // yeni bir örnek kurar ve test kendi kendini kandırırdı.
      expect(find.byType(MemoryEditorView), findsNothing);
    });

    testWidgets('KONUM kaydedilmiyor — `Locations` satırı yazan yol yok', (
      tester,
    ) async {
      // Tablo VAR ve okunuyor; eksik olan tek şey serbest metni bir konum
      // satırına çeviren upsert. Kullanıcının gördüğü kayıp bu.
      final container = await pumpForm(tester);

      await tester.enterText(fieldOf('Başlık'), 'Kapadokya');
      await tester.enterText(fieldOf('Konum'), 'Göreme, Nevşehir');
      await settle(tester);

      // Ekranda duruyor…
      expect(readState(container).locationLabel, 'Göreme, Nevşehir');
      // …ama taslakta bir konum KİMLİĞİ yok, dolayısıyla kaydedilmiyor.
      expect(readState(container).draft.locationId, isNull);
    });

    testWidgets(
      'FOTOĞRAFLAR kaydedilmiyor — `MediaItems` satırı yazan yol yok',
      (tester) async {
        // Seçilen kareler geçici kimlik taşıyor (`picked:`) ve `mediaIds`e
        // girmiyor. Medya hattı (FR-042 galeri asset kimliği + FR-043 önizleme
        // üretimi) kurulduğunda burası gerçek kimliklerle dolacak.
        final container = await pumpForm(
          tester,
          photos: const ['a.jpg', 'b.jpg'],
        );

        // Ekranda iki kare var…
        expect(readState(container).photos, hasLength(2));
        // …ama taslak hiç medya taşımıyor.
        expect(readState(container).draft.mediaIds, isEmpty);
        expect(readState(container).draft.coverMediaId, isNull);
      },
    );

    testWidgets('SADECE fotoğraf seçen kullanıcı KAYDEDEMİYOR', (tester) async {
      // FR-012 "boş kayıt olmaz" kuralının bugünkü yan etkisi: fotoğraflar
      // taslağa girmediği için taslak boş sayılıyor ve düğme kapalı kalıyor.
      // Medya hattı kurulunca kendiliğinden düzelecek.
      await pumpForm(tester, photos: const ['a.jpg']);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Kaydet'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('kişiler, koleksiyon ve seri kaydedilmiyor', (tester) async {
      final container = await pumpForm(tester);

      await tester.enterText(fieldOf('Başlık'), 'Kapadokya');
      await settle(tester);

      await tester.tap(find.text('Kişiler'));
      await settle(tester);
      await tester.tap(find.text('Annem'));
      await settle(tester);
      await tester.tap(find.text('Tamam'));
      await settle(tester);

      // Ekranda seçili…
      expect(readState(container).people, hasLength(1));
      // …ama taslakta yok: `People` tablosunda karşılık gelen satır olmadığı
      // için yazmak yabancı anahtar ihlali olurdu.
      expect(readState(container).draft.personIds, isEmpty);
      expect(readState(container).draft.collectionIds, isEmpty);
      expect(readState(container).draft.ritualId, isNull);
    });
  });
}
