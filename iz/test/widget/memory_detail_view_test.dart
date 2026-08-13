/// Anı detay ekranı.
///
/// Testlerin dayandığı iki iddia:
///   • Ekran bir FORM DEĞİL, bir KAYIT: boş ilişki satırı göstermez.
///   • İlişki kartı formla AYNI bileşendir; kullanıcı forma girdiğini
///     detayda aynı yerde, aynı hizada görür.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/core/theme/app_typography.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/presentation/views/memory_detail_view.dart';
import 'package:iz/features/memories/presentation/widgets/expandable_note.dart';
import 'package:iz/features/memories/presentation/widgets/memory_info_card.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';
import 'package:iz/shared/widgets/media_thumbnail.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_memory_repository.dart';
import '../helpers/real_fonts.dart';

/// İki satıra sığmayan bir not.
const _longNote =
    "Kordon'da gün batımını izledik, sonra midye dolma ve boyoz aldık. "
    "Saat kulesinin oradaki güvercinler Elif'in elinden yem yedi; annem "
    'bütün gün bir daha gelelim dedi. Akşam vapurla karşıya geçtik.';

MediaItem _media(int i) => MediaItem(
  id: 'media_$i',
  type: MediaType.photo,
  originalStatus: MediaOriginalStatus.available,
);

Person _person(String id, String name) => Person(
  id: id,
  name: name,
  kind: PersonKind.human,
  relationType: RelationType.relative,
);

MemoryDetail buildDetail({
  String? note,
  String? title = 'İlk İzmir Tatilimiz',
  String? location = 'Kordon, İzmir',
  String? categoryId = 'cat_travel',
  int mediaCount = 3,
  int personCount = 3,
  bool withCollection = true,
  bool withRitual = true,
  bool isFavorite = false,
}) {
  const names = ['Annem', 'Babam', 'Elif', 'Deniz', 'Kerem'];

  return MemoryDetail(
    memory: Memory(
      id: 'm1',
      occurredAt: DateTime(2024, 5, 12),
      isFavorite: isFavorite,
      mediaCount: mediaCount,
      personCount: personCount,
      title: title,
      note: note,
      categoryId: categoryId,
      locationLabel: location,
    ),
    people: [for (var i = 0; i < personCount; i++) _person('p$i', names[i])],
    collections: withCollection
        ? const [
            MemoryCollection(
              id: 'c1',
              title: 'Ege Gezileri',
              visibility: CollectionVisibility.private,
            ),
          ]
        : const [],
    ritual: withRitual
        ? const Ritual(
            id: 'r1',
            title: 'Yaz Tatilleri',
            recurrenceType: RecurrenceType.seasonal,
            iconKey: 'summer',
          )
        : null,
    ritualYear: withRitual ? 2024 : null,
    media: [for (var i = 0; i < mediaCount; i++) _media(i)],
  );
}

late FakeMemoryRepository repository;

Future<void> pumpDetail(
  WidgetTester tester, {
  MemoryDetail? data,
  Size size = const Size(390, 1000),
  bool dark = false,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final detail = data ?? buildDetail();

  // Hazır detay + listede karşılığı olan `Memory`: ikisi birlikte gerekiyor,
  // yoksa favori gibi değişiklikler akışa yansımaz
  // (bkz. `FakeMemoryRepository.details`).
  repository = FakeMemoryRepository([detail.memory])..detail = detail;
  addTearDown(repository.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [memoryRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const MemoryDetailView(memoryId: 'm1'),
      ),
    ),
  );
  await settle(tester);
}

/// Belirli etiketli ilişki satırını bulur.
Finder rowOf(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(MemoryInfoRow));

void main() {
  setUpAll(loadRealFonts);

  group('üst blok', () {
    testWidgets('başlık, ortalı ekran adı ve favori duruyor', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Anı Detay'), findsOneWidget);
      expect(tester.getCenter(find.text('Anı Detay')).dx, closeTo(195, 1));
      expect(find.text('İlk İzmir Tatilimiz'), findsOneWidget);
      expect(find.byIcon(AppIcons.favorite), findsOneWidget);
    });

    testWidgets('AppBar\'da hiçbir eylem yok', (tester) async {
      // Referansta bir "…" duruyordu; silmeyi bir ara oradan çıkarıp açık bir
      // çöp ikonuna almıştık. İkisi de gitti: bu ekranın işi anıyı GÖSTERMEK
      // ve eylemlerin adresi alttaki şerit.
      await pumpDetail(tester);

      expect(find.byIcon(AppIcons.more), findsNothing);
      expect(find.byType(PopupMenuButton<Object?>), findsNothing);
      expect(find.byIcon(AppIcons.delete), findsNothing);
    });

    testWidgets('başlık POPPINS ve nottan büyük', (tester) async {
      // Cormorant (serif) markanın duygusal sesi ama buradaki metin
      // kullanıcının kendi yazdığı bir başlık — veri. Altındaki notla aynı
      // aileden olmalı, yoksa sayfa iki sesli okunuyor.
      await pumpDetail(tester, data: buildDetail(note: _longNote));

      final title = tester.widget<Text>(find.text('İlk İzmir Tatilimiz'));
      final note = tester.widget<Text>(find.text(_longNote));

      expect(title.style?.fontFamily, note.style?.fontFamily);
      expect(title.style?.fontSize, greaterThan(note.style!.fontSize!));
      expect(title.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('başlık ekran adlarından KÜÇÜK ve hafif yeşil', (tester) async {
      // Kullanıcının isteği. "Hayatım"/"Kişilerim" ölçüsü buraya fazla
      // geliyordu: orada başlık sayfanın ADI, burada hemen altındaki kapak
      // fotoğrafıyla yer paylaşıyor.
      await pumpDetail(tester);

      final title = tester.widget<Text>(find.text('İlk İzmir Tatilimiz'));
      final theme = AppTheme.light();
      final screenTitle = theme.extension<AppTextStyles>()!.screenTitle;

      expect(title.style!.fontSize, lessThan(screenTitle.fontSize!));

      // HAFİF yeşil: ne düz mürekkep ne de ekran başlıklarındaki tam marka
      // rengi — ikisinin arası. Renk tek başına bilgi taşımıyor (NFR-031),
      // bu yalnızca bir ton.
      final color = title.style!.color!;
      final scheme = theme.colorScheme;
      expect(color, isNot(scheme.onSurface));
      expect(color, isNot(scheme.primary));
      // Yeşile DOĞRU: yeşil kanal kırmızıdan yüksek olmalı.
      expect(color.g, greaterThan(color.r));
    });

    testWidgets('favori kalbi taslağı çeviriyor', (tester) async {
      await pumpDetail(tester);

      await tester.tap(find.byIcon(AppIcons.favorite));
      await settle(tester);

      expect(repository.memories.single.isFavorite, isTrue);
    });

    testWidgets('kapak 16:9 ve satırı dolduruyor', (tester) async {
      // Oran, sabit yükseklik DEĞİL: aynı ekran farklı genişliklerde de aynı
      // görünmeli.
      await pumpDetail(tester);

      final cover = tester.getSize(find.byType(MediaThumbnail).first);
      expect(cover.width, closeTo(390 - 32, 0.5));
      expect(
        cover.width / cover.height,
        closeTo(MemoryDetailView.kCoverAspectRatio, 0.01),
      );
    });

    testWidgets('kapak başlığın HEMEN altında', (tester) async {
      // Favori düğmesi (dokunma hedefi 48) başlık satırını kendisi şişiriyor;
      // üstüne bir de boşluk konunca arada kocaman bir delik açılıyordu.
      await pumpDetail(tester);

      final titleBottom = tester
          .getBottomLeft(find.text('İlk İzmir Tatilimiz'))
          .dy;
      final coverTop = tester.getTopLeft(find.byType(MediaThumbnail).first).dy;

      expect(coverTop - titleBottom, lessThan(24), reason: 'boşluk büyümüş');
      expect(
        coverTop,
        greaterThan(titleBottom),
        reason: 'kapak başlığa binmiş',
      );
    });

    testWidgets('kapak ŞERİTTEKİ ilk kareden daha büyük', (tester) async {
      // Hiyerarşi: kapak "bu anı böyle görünüyor", şerit "şu kareler var".
      await pumpDetail(tester);

      final thumbs = find.byType(MediaThumbnail);
      expect(
        tester.getSize(thumbs.first).width,
        greaterThan(tester.getSize(thumbs.at(1)).width),
      );
    });
  });

  group('tarih ve konum', () {
    testWidgets('tarih TÜRKÇE uzun biçimde', (tester) async {
      // `Intl.defaultLocale`e düşen bir çağrı burada "May 12, 2024" üretirdi.
      await pumpDetail(tester);

      expect(find.text('12 Mayıs 2024'), findsOneWidget);
    });

    testWidgets('konum aynı blokta gösteriliyor', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Kordon, İzmir'), findsOneWidget);
      expect(find.byIcon(AppIcons.location), findsOneWidget);
    });

    testWidgets('konum yoksa hiç çizilmiyor', (tester) async {
      await pumpDetail(tester, data: buildDetail(location: null));

      expect(find.byIcon(AppIcons.location), findsNothing);
      expect(find.text('12 Mayıs 2024'), findsOneWidget);
    });
  });

  group('not', () {
    testWidgets('not yoksa hiç çizilmiyor', (tester) async {
      // Not ZORUNLU DEĞİL.
      await pumpDetail(tester);

      expect(find.byType(ExpandableNote), findsNothing);
    });

    testWidgets('KISA notta aç/kapa oku yok', (tester) async {
      // Ok, iki satıra sığan bir notta yanlış söz verirdi.
      await pumpDetail(tester, data: buildDetail(note: 'Güzeldi.'));

      expect(find.text('Güzeldi.'), findsOneWidget);
      expect(find.byIcon(AppIcons.expand), findsNothing);
    });

    testWidgets('UZUN not iki satırda kalıyor, ok çıkıyor', (tester) async {
      await pumpDetail(tester, data: buildDetail(note: _longNote));

      expect(find.byIcon(AppIcons.expand), findsOneWidget);

      final text = tester.widget<Text>(find.text(_longNote));
      expect(text.maxLines, ExpandableNote.kCollapsedLines);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('dokununca açılıyor, tekrar dokununca kapanıyor', (
      tester,
    ) async {
      await pumpDetail(tester, data: buildDetail(note: _longNote));

      final collapsed = tester.getSize(find.byType(ExpandableNote)).height;

      await tester.tap(find.byType(ExpandableNote));
      await settle(tester);

      expect(find.byIcon(AppIcons.collapse), findsOneWidget);
      expect(tester.widget<Text>(find.text(_longNote)).maxLines, isNull);
      expect(
        tester.getSize(find.byType(ExpandableNote)).height,
        greaterThan(collapsed),
      );

      await tester.tap(find.byType(ExpandableNote));
      await settle(tester);

      expect(find.byIcon(AppIcons.expand), findsOneWidget);
      expect(
        tester.getSize(find.byType(ExpandableNote)).height,
        closeTo(collapsed, 0.5),
      );
    });
  });

  group('fotoğraf şeridi', () {
    testWidgets('kareler satırı dolduruyor', (tester) async {
      await pumpDetail(tester);

      // İlki kapak; şerit kalanları.
      final strip = [
        for (var i = 1; i <= 3; i++)
          tester.getSize(find.byType(MediaThumbnail).at(i)),
      ];

      expect(strip.every((s) => s.width == s.height), isTrue);
      expect(
        strip.fold<double>(0, (a, s) => a + s.width) + 8 * 2,
        closeTo(390 - 32, 0.5),
      );
    });

    testWidgets('tek fotoğrafta şerit hiç çizilmiyor', (tester) async {
      // Kapak zaten o kareyi gösteriyor; altına tek kutu koymak tekrar olurdu.
      await pumpDetail(tester, data: buildDetail(mediaCount: 1));

      expect(find.byType(MediaThumbnail), findsOneWidget);
    });
  });

  group('ilişki kartı', () {
    testWidgets('sıra: Kişiler, Kategori, Koleksiyon, Seri', (tester) async {
      // Sıra formdakiyle AYNI olmalı: kullanıcı forma hangi sırayla girdiyse
      // detayda o sırayla görüyor.
      await pumpDetail(tester);

      final labels = [
        for (final e in find.byType(MemoryInfoRow).evaluate())
          (e.widget as MemoryInfoRow).label,
      ];

      expect(labels, ['Kişiler', 'Kategori', 'Koleksiyon', 'Seri']);
    });

    testWidgets('dört satır da değeriyle duruyor', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Annem, Babam, Elif'), findsOneWidget);
      expect(find.text('Seyahat'), findsOneWidget);
      expect(find.text('Ege Gezileri'), findsOneWidget);
      // Aynı serinin birçok yılı olabilir (BR-012); hangisi olduğu bilgi.
      expect(find.text('Yaz Tatilleri · 2024'), findsOneWidget);
    });

    testWidgets('kişiler satırı TEK satırda kalıyor', (tester) async {
      // Avatarlar da aynı satırda; isim listesi ikinci satıra düşerse kart
      // ritmi bozulur. Etiket sütunu bu yüzden dar tutuldu.
      await pumpDetail(tester);

      expect(tester.getSize(rowOf('Kişiler')).height, MemoryInfoRow.kMinHeight);
    });

    testWidgets('BOŞ ilişki satırı gösterilmiyor', (tester) async {
      // Detay bir form değil: "Koleksiyon —" bilgi taşımaz, eksiklik duyurur.
      await pumpDetail(
        tester,
        data: buildDetail(
          personCount: 0,
          withCollection: false,
          withRitual: false,
        ),
      );

      expect(find.text('Kişiler'), findsNothing);
      expect(find.text('Koleksiyon'), findsNothing);
      expect(find.text('Seri'), findsNothing);
      expect(find.text('Kategori'), findsOneWidget);
    });

    testWidgets('hiçbir ilişki yoksa kart hiç çıkmıyor', (tester) async {
      await pumpDetail(
        tester,
        data: buildDetail(
          personCount: 0,
          categoryId: null,
          withCollection: false,
          withRitual: false,
        ),
      );

      expect(find.byType(MemoryInfoCard), findsNothing);
    });

    testWidgets('üçten fazla kişide fazlası "+N" olarak toplanıyor', (
      tester,
    ) async {
      await pumpDetail(tester, data: buildDetail(personCount: 5));

      expect(find.text('+2'), findsOneWidget);
      // Baş harfler dile duyarlı büyütülüyor.
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('formla AYNI bileşeni kullanıyor', (tester) async {
      // İki ekranın aynı kartı paylaşması tasarımın kararı: kullanıcı forma
      // girdiğini detayda aynı yerde görüyor.
      await pumpDetail(tester);

      expect(find.byType(MemoryInfoCard), findsOneWidget);
      expect(find.byType(MemoryInfoRow), findsNWidgets(4));
    });
  });

  group('alt eylemler', () {
    testWidgets('üç eylem eşit genişlikte', (tester) async {
      await pumpDetail(tester);

      final widths = [
        for (final label in ['Paylaş', 'Kolaj Oluştur', 'Düzenle'])
          tester
              .getSize(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(InkWell),
                ),
              )
              .width,
      ];

      expect(
        widths.every((w) => (w - widths.first).abs() < 0.5),
        isTrue,
        reason: 'eylemler eşit değil: $widths',
      );
    });

    testWidgets('ikonlarıyla duruyor', (tester) async {
      await pumpDetail(tester);

      expect(find.byIcon(AppIcons.share), findsOneWidget);
      expect(find.byIcon(AppIcons.collage), findsOneWidget);
      expect(find.byIcon(AppIcons.edit), findsOneWidget);
    });

    testWidgets('hazır olmayan eylem "yakında" diyor', (tester) async {
      // Sessiz bir düğme, dokunulup hiçbir şey olmayan bir düğmedir.
      await pumpDetail(tester);

      await tester.tap(find.text('Kolaj Oluştur'));
      await settle(tester);

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('alt çubuk', () {
    testWidgets('ekranın altında duruyor', (tester) async {
      // Bu ekran kabuğun DIŞINDA açılıyor; çubuğu kendisi kuruyor.
      await pumpDetail(tester);

      expect(find.byType(IzBottomNav), findsOneWidget);
      for (final label in ['Ana Sayfa', 'Hayatım', 'Mağaza', 'Profilim']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('hiçbir sekme SEÇİLİ değil', (tester) async {
      // Kullanıcı bir sekmede değil, bir anıya bakıyor: birini vurgulamak
      // "buradasın" diye yanlış bir şey söylerdi.
      await pumpDetail(tester);

      final nav = tester.widget<IzBottomNav>(find.byType(IzBottomNav));
      expect(nav.currentIndex, IzBottomNav.noSelection);
    });

    testWidgets('sekme listesi KABUKLA aynı kaynaktan', (tester) async {
      // İki liste ayrışırsa sekme sırası kayar ve derleyici susar.
      await pumpDetail(tester);

      final nav = tester.widget<IzBottomNav>(find.byType(IzBottomNav));
      expect(nav.destinations.length, AppRoute.tabs.length);
    });
  });

  testWidgets('karanlık temada da çiziliyor', (tester) async {
    await pumpDetail(tester, data: buildDetail(note: _longNote), dark: true);

    expect(tester.takeException(), isNull);
    expect(find.text('İlk İzmir Tatilimiz'), findsOneWidget);
  });
}
