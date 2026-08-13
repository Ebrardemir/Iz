/// TASARIM ÖNİZLEMESİ İÇİN SAHTE VERİ.
///
/// ⚠️ BU DOSYA ÜRETİM VERİSİ DEĞİL. Ana sayfa henüz hiçbir veri kaynağına
/// bağlı değil; ekranın dolu hâlini görebilmek için referans tasarımdaki
/// kayıtları burada elle yazıyoruz.
///
/// NEDEN AYRI DOSYA?
/// İçindeki "Kahve Molası", "3 gün önce" gibi metinler KULLANICI VERİSİ
/// taklidi — çeviriden geçmezler, geçmemeleri de gerekir. Çeviri koruma
/// testi (`test/unit/l10n_test.dart`) sabit Türkçe metin arıyor ve haklı
/// olarak bunları yakalıyordu. İstisnayı ekranın tamamına açmak yerine
/// yalnızca bu dosyaya açtık; adı da ne olduğunu söylüyor.
///
/// Veri bağlandığında bu dosya SİLİNECEK.
library;

import 'package:flutter/widgets.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/home/presentation/widgets/home_hero_overlay.dart';
import 'package:iz/features/home/presentation/widgets/home_stats_grid.dart';
import 'package:iz/features/home/presentation/widgets/memory_row_card.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/my_life/presentation/widgets/my_life_tab_bar.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';

abstract final class HomePreviewData {
  /// ÖRNEK DEĞERLER — ekran hiçbir veri kaynağına bağlı değil (bkz. dosya
  /// başındaki not). Sayılar referans tasarımdakilerle aynı; veri
  /// bağlandığında bu metodun yerini ViewModel'den gelen state alacak.
  ///
  /// Birimler ÇOĞUL yapısıyla geliyor: Türkçede sayıdan sonra çoğul eki
  /// gelmez ("128 kayıt") ama İngilizcede gelir ("128 records").
  /// [onOpen] sayacın açtığı bölüme götürüyor.
  ///
  /// NAVİGASYONU BU DOSYA BİLMİYOR: geri çağırma dışarıdan geliyor. Sayıların
  /// sahte olması bir şeyi değiştirmiyor — hangi sayacın nereye gittiği bir
  /// EKRAN kararı ve veri bağlandığında da öyle kalacak.
  ///
  /// [query] "Hayatım"ın hangi sekmesinin açılacağını taşıyor: seriler ve
  /// koleksiyonlar ayrı ekranlar değil, o ekranın sekmeleri.
  static List<HomeStat> stats(
    BuildContext context, {
    required void Function(AppRoute route, {Map<String, String> query}) onOpen,
  }) {
    final l10n = context.l10n;
    return [
      (
        icon: AppIcons.navJournal,
        label: l10n.homeStatJournal,
        value: '128',
        unit: l10n.homeStatJournalUnit(128),
        onTap: () => onOpen(AppRoute.journal),
      ),
      (
        icon: AppIcons.people,
        label: l10n.homeStatPeople,
        value: '7',
        unit: l10n.homeStatPeopleUnit(7),
        onTap: () => onOpen(AppRoute.people),
      ),
      // SERİLER ve KOLEKSİYONLAR ayrı ekran DEĞİL, "Hayatım"ın sekmeleri:
      // sayaç doğrudan o sekmeye götürüyor (bkz. `MyLifeTab.fromQuery`).
      (
        icon: AppIcons.series,
        label: l10n.homeStatSeries,
        value: '3',
        unit: l10n.homeStatSeriesUnit(3),
        onTap: () =>
            onOpen(AppRoute.myLife, query: {'tab': MyLifeTab.series.name}),
      ),
      (
        icon: AppIcons.collection,
        label: l10n.homeStatCollections,
        value: '5',
        unit: l10n.homeStatCollectionsUnit(5),
        onTap: () =>
            onOpen(AppRoute.myLife, query: {'tab': MyLifeTab.collections.name}),
      ),
    ];
  }

  /// Fotoğrafın üzerindeki "bugünün izi" — örnek.
  ///
  /// Kimlik, aşağıdaki listedeki aynı anıyla EŞLEŞİYOR: kapaktaki "Anıyı Gör"
  /// ile listedeki "İlk İzmir Tatilimiz" satırı aynı yere gitmeli.
  static const HeroMemory today = (
    id: 'preview-izmir',
    title: 'İlk İzmir Tatilimiz',
    dateLabel: '1 hafta önce',
  );

  /// ÖRNEK ANILAR — ekran hiçbir veri kaynağına bağlı değil.
  ///
  /// Referans tasarımdaki üç kayıtla aynı. Kapak fotoğrafları yer tutucu:
  /// yalnızca "Kahve Molası" gerçek bir kapak, ötekiler projede zaten
  /// bulunan görsellerden ödünç. Veri bağlandığında bu liste ViewModel'den
  /// gelecek ve kapaklar `Memory.coverMedia`den okunacak.
  static const List<MemoryRowData> memories = [
    (
      id: 'preview-kahve',
      imageAsset: 'assets/images/home/memory_coffee.jpg',
      title: 'Kahve Molası',
      dateLabel: '3 gün önce',
    ),
    (
      id: 'preview-izmir',
      imageAsset: 'assets/images/home/hero_today.jpg',
      title: 'İlk İzmir Tatilimiz',
      dateLabel: '1 hafta önce',
    ),
    (
      id: 'preview-venedik',
      imageAsset: 'assets/images/auth/hero_light.jpg',
      title: 'Venedik Balayımız',
      dateLabel: '2 yıl önce bugün',
    ),
  ];

  /// Önizleme anılarının DETAY hâli — kimlik → kayıt.
  ///
  /// ⚠️ GEÇİCİ, dosyanın geri kalanıyla aynı gerekçe. Kartlara dokunulduğunda
  /// anı detayı açılıyor ve o ekran bir `MemoryDetail` istiyor; sahte
  /// kimliklerin veritabanında karşılığı olmadığı için kaydı yanımızda
  /// götürüyoruz (bkz. `MemoryDetailView.previewDetail`).
  ///
  /// Kayıtlar BİLEREK farklı doluluklarda: biri notsuz, biri kişisiz, biri
  /// tek fotoğraflı. Detay ekranının boş alanları nasıl karşıladığını
  /// tasarım aşamasında görmek istiyoruz.
  static final Map<String, MemoryDetail> _details = {
    'preview-kahve': _detail(
      id: 'preview-kahve',
      title: 'Kahve Molası',
      occurredAt: DateTime(2026, 8, 9),
      categoryId: 'cat_daily',
      collectionTitle: 'Pazar Kahvaltıları',
      photoAssets: const ['assets/images/home/memory_coffee.jpg'],
    ),
    'preview-izmir': _detail(
      id: 'preview-izmir',
      title: 'İlk İzmir Tatilimiz',
      occurredAt: DateTime(2026, 8, 5),
      note:
          "Kordon'da gün batımını izledik, sonra midye dolma ve boyoz aldık. "
          'Saat kulesinin oradaki güvercinler Elif\'in elinden yem yedi; '
          'annem bütün gün "bir daha gelelim" dedi. Akşam vapurla '
          "Karşıyaka'ya geçtik, deniz kokusu eve kadar peşimizden geldi.",
      locationLabel: 'Kordon, İzmir',
      categoryId: 'cat_travel',
      personNames: const ['Annem', 'Babam', 'Elif'],
      collectionTitle: 'Ege Gezileri',
      seriesTitle: 'Yaz Tatillerimiz',
      seriesIconKey: 'summer',
      photoAssets: const [
        'assets/images/home/hero_today.jpg',
        'assets/images/home/memory_coffee.jpg',
        'assets/images/auth/hero_light.jpg',
      ],
    ),
    'preview-venedik': _detail(
      id: 'preview-venedik',
      title: 'Venedik Balayımız',
      occurredAt: DateTime(2024, 8, 12),
      note: 'San Marco meydanında yağmura yakalandık.',
      locationLabel: 'Venedik, İtalya',
      categoryId: 'cat_relationships',
      personNames: const ['Deniz'],
      collectionTitle: 'Venedik 2024',
      seriesTitle: 'Evlilik Yıldönümü',
      seriesIconKey: 'anniversary',
      photoAssets: const [
        'assets/images/auth/hero_light.jpg',
        'assets/images/home/hero_today.jpg',
      ],
    ),
  };

  /// Verilen kimliğin detayı; tanımadığı kimlikte null.
  ///
  /// `null` dönmesi bir hata değil: ekran o zaman düz bir geçiş yapar ve
  /// detay ekranı depodan okur — yani gerçek bir anıysa doğru davranır.
  static MemoryDetail? detailFor(String id) => _details[id];

  /// Sahte bir `MemoryDetail` kurar.
  ///
  /// Fotoğraflar ASSET olarak `localPreviewPath`e yazılıyor; `MediaThumbnail`
  /// bu yolu tanıyıp `Image.asset`e düşüyor (orada da geçici olduğu not
  /// edilmiş). Gerçek medya hattında bu alan sandbox içinde bir dosya olacak.
  static MemoryDetail _detail({
    required String id,
    required String title,
    required DateTime occurredAt,
    required List<String> photoAssets,
    String? note,
    String? locationLabel,
    String? categoryId,
    List<String> personNames = const [],
    String? collectionTitle,
    String? seriesTitle,
    String? seriesIconKey,
    int? seriesYear,
  }) {
    final media = [
      for (var i = 0; i < photoAssets.length; i++)
        MediaItem(
          id: '$id-media-$i',
          type: MediaType.photo,
          originalStatus: MediaOriginalStatus.available,
          localPreviewPath: photoAssets[i],
        ),
    ];

    return MemoryDetail(
      memory: Memory(
        id: id,
        occurredAt: occurredAt,
        isFavorite: false,
        mediaCount: media.length,
        personCount: personNames.length,
        title: title,
        note: note,
        categoryId: categoryId,
        coverMedia: media.firstOrNull,
        locationLabel: locationLabel,
      ),
      people: [
        for (var i = 0; i < personNames.length; i++)
          Person(
            id: '$id-person-$i',
            name: personNames[i],
            kind: PersonKind.human,
            relationType: RelationType.relative,
          ),
      ],
      collections: [
        if (collectionTitle != null)
          MemoryCollection(
            id: '$id-collection',
            title: collectionTitle,
            visibility: CollectionVisibility.private,
          ),
      ],
      media: media,
      ritual: seriesTitle == null
          ? null
          : Ritual(
              id: '$id-series',
              title: seriesTitle,
              recurrenceType: RecurrenceType.yearly,
              iconKey: seriesIconKey ?? 'ritual',
            ),
      ritualYear: seriesTitle == null ? null : (seriesYear ?? occurredAt.year),
    );
  }
}
