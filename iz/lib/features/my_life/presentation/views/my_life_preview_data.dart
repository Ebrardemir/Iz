/// TASARIM ÖNİZLEMESİ İÇİN SAHTE VERİ.
///
/// ⚠️ ÜRETİM VERİSİ DEĞİL. "Hayatım" ekranı henüz hiçbir veri kaynağına
/// bağlı değil; takvimin ve altındaki panelin dolu hâlini görebilmek için
/// birkaç güne anı koyuyoruz.
///
/// Ana sayfadaki `HomePreviewData` ile aynı gerekçe ve aynı kader: veri
/// bağlandığında bu dosya SİLİNECEK.
///
/// İçindeki "Kahve Molası", "Aile" gibi metinler KULLANICI VERİSİ taklidi —
/// çeviriden geçmezler, geçmemeleri de gerekir. Çeviri koruma testi
/// (`test/unit/l10n_test.dart`) sabit Türkçe metin arıyor; istisnayı ekranın
/// tamamına açmak yerine yalnızca bu dosyaya açtık.
library;

import 'package:iz/core/extensions/date_x.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/my_life/presentation/widgets/collection_card.dart';
import 'package:iz/features/my_life/presentation/widgets/day_memory_card.dart';
import 'package:iz/features/my_life/presentation/widgets/series_card.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/features/rituals/presentation/ritual_l10n.dart';

/// Görünen ayda anısı olan günler.
///
/// Ay değişince de dolu görünsün diye gün NUMARASINA göre veriyoruz;
/// gerçek veride bu elbette tarihe bağlı olacak.
///
/// Gün sayıları BİLEREK farklı doluluklarda: 6 → tek anı, 18 → iki anı
/// (tasarımın tam dolu hâli), 29 → üç anı (panelin büyüyüp sayfanın
/// kaydığı hâl). Öteki günler boş durumu gösteriyor.
abstract final class MyLifePreviewData {
  static const Map<
    int,
    List<({String id, String imageAsset, String title, String category})>
  >
  _byDayOfMonth = {
    6: [
      (
        id: 'preview-kahve',
        imageAsset: 'assets/images/home/memory_coffee.jpg',
        title: 'Kahve Molası',
        category: 'Günlük',
      ),
    ],
    18: [
      (
        id: 'preview-izmir',
        imageAsset: 'assets/images/home/hero_today.jpg',
        title: 'İlk İzmir Tatilimiz',
        category: 'Seyahat',
      ),
      (
        id: 'preview-sahil',
        imageAsset: 'assets/images/home/memory_coffee.jpg',
        title: 'Sahilde Sabah',
        category: 'Seyahat',
      ),
    ],
    29: [
      (
        id: 'preview-venedik',
        imageAsset: 'assets/images/auth/hero_light.jpg',
        title: 'Venedik Balayımız',
        category: 'İlişkiler',
      ),
      (
        id: 'preview-gondol',
        imageAsset: 'assets/images/home/hero_today.jpg',
        title: 'Gondol Turu',
        category: 'İlişkiler',
      ),
      (
        id: 'preview-meydan',
        imageAsset: 'assets/images/home/memory_coffee.jpg',
        title: 'Meydandaki Kahve',
        category: 'İlişkiler',
      ),
    ],
  };

  /// Takvim hücrelerindeki küçük kapaklar: gün → kapak görseli.
  ///
  /// LİSTEDEN TÜRETİLİYOR — elle ikinci bir harita tutmuyoruz. Önce öyleydi
  /// ve iki kaynağın ayrışması an meselesiydi: takvimde kapak görünen bir
  /// güne dokunulduğunda panel "anı yok" diyebilirdi.
  static Map<DateTime, String> coversFor(DateTime month) => {
    for (final entry in _byDayOfMonth.entries)
      if (entry.value.isNotEmpty)
        DateTime(month.year, month.month, entry.key):
            entry.value.first.imageAsset,
  };

  /// [day] gününe ait anılar. Anısı olmayan günde boş liste döner —
  /// panel o zaman boş durumu çizer.
  ///
  /// [dateLabel] burada üretiliyor çünkü karttaki "15 Ağustos 2026 • Aile"
  /// satırı seçili günün tarihini gösteriyor; kart onu hazır metin olarak
  /// bekliyor (bkz. [DayMemoryData]).
  static List<DayMemoryData> memoriesFor(DateTime day, {String? locale}) {
    final entries = _byDayOfMonth[day.day];
    if (entries == null) return const [];

    final label = AppDateFormats.long(day, locale: locale);
    return [
      for (final entry in entries)
        (
          id: entry.id,
          imageAsset: entry.imageAsset,
          title: entry.title,
          dateLabel: label,
          categoryLabel: entry.category,
        ),
    ];
  }

  // --- KOLEKSİYONLAR sekmesi -----------------------------------------------

  /// Koleksiyonların HAM hâli — tarihler, henüz metne çevrilmemiş.
  ///
  /// `const` DEĞİL çünkü `DateTime` sabit ifade olamaz; `final` yeterli.
  ///
  /// Özet satırı ("18 anı • 10-14 Mayıs 2026") burada YAZILI DEĞİL:
  /// [collections] onu çeviriden ve aktif dilden üretiyor. Hazır yazsaydık
  /// metin bu dosyada Türkçe donar ve İngilizce arayüzde de öyle görünürdü.
  static final List<_RawCollection> _collections = [
    (
      id: 'col-kapadokya',
      coverAsset: 'assets/images/home/hero_today.jpg',
      title: 'Kapadokya 2026',
      start: DateTime(2026, 5, 10),
      end: DateTime(2026, 5, 14),
      memories: [
        (
          id: 'mem-balon',
          imageAsset: 'assets/images/home/hero_today.jpg',
          title: 'Balonlar havalanırken',
          date: DateTime(2026, 5, 10),
        ),
        (
          id: 'mem-vadi',
          imageAsset: 'assets/images/home/memory_coffee.jpg',
          title: 'Güvercinlik Vadisi',
          date: DateTime(2026, 5, 12),
        ),
        (
          id: 'mem-gunbatimi',
          imageAsset: 'assets/images/auth/hero_light.jpg',
          title: 'Kızılçukur\'da gün batımı',
          date: DateTime(2026, 5, 14),
        ),
      ],
    ),
    (
      id: 'col-universite',
      coverAsset: 'assets/images/auth/hero_light.jpg',
      title: 'Üniversite Yıllarım',
      start: DateTime(2021, 9, 20),
      end: DateTime(2025, 6, 14),
      memories: [
        (
          id: 'mem-ilk-gun',
          imageAsset: 'assets/images/auth/hero_light.jpg',
          title: 'Kampüste ilk gün',
          date: DateTime(2021, 9, 20),
        ),
        (
          id: 'mem-mezuniyet',
          imageAsset: 'assets/images/home/hero_today.jpg',
          title: 'Mezuniyet',
          date: DateTime(2025, 6, 14),
        ),
      ],
    ),
    (
      id: 'col-kahvaltilar',
      coverAsset: 'assets/images/home/memory_coffee.jpg',
      title: 'Pazar Kahvaltıları',
      start: DateTime(2026, 3, 1),
      end: null,
      memories: [
        (
          id: 'mem-kahve',
          imageAsset: 'assets/images/home/memory_coffee.jpg',
          title: 'Kahve Molası',
          date: DateTime(2026, 3, 1),
        ),
      ],
    ),
  ];

  /// Kartların beklediği hâle çevirir: sayaç çoğullanır, tarih aralığı
  /// biçimlenir, ikisi "•" ile birleşir.
  static List<CollectionCardData> collections(AppL10n l10n, {String? locale}) {
    return [
      for (final raw in _collections)
        (
          id: raw.id,
          coverAsset: raw.coverAsset,
          title: raw.title,
          // "18 anı • 10-14 Mayıs 2026"
          //
          // AYIRICI ÇEVİRİDEN GELMİYOR: "•" bir noktalama işareti, arayüz
          // metni değil — her dilde aynı.
          summary:
              '${l10n.collectionMemoryCount(raw.memories.length)} • '
              '${AppDateFormats.range(raw.start, raw.end, locale: locale)}',
          memories: [
            for (final memory in raw.memories)
              (
                id: memory.id,
                imageAsset: memory.imageAsset,
                title: memory.title,
                dateLabel: AppDateFormats.long(memory.date, locale: locale),
              ),
          ],
        ),
    ];
  }

  // --- SERİLERİM sekmesi ----------------------------------------------------

  /// Sahte ritüeller — GERÇEK `Ritual` entity'si olarak.
  ///
  /// Uydurma bir kayıt tipi yazmıyoruz: kartın altyazısı ("Her yıl 3 Mart'ta")
  /// `recurrenceType` + `anchorMonth` + `anchorDay`dan türetiliyor ve o zincir
  /// veri bağlandığında AYNEN kalacak. Önizleme ile üretim arasındaki tek fark
  /// bu listenin nereden geldiği olacak.
  static final List<Ritual> _rituals = [
    const Ritual(
      id: 'rit-yaz',
      title: 'Yaz Tatillerimiz',
      // Tarihi kayan ritüel: her yıl aynı güne denk gelmiyor.
      recurrenceType: RecurrenceType.seasonal,
      anchorMonth: 7,
      iconKey: 'summer',
    ),
    const Ritual(
      id: 'rit-dogumgunu',
      title: 'Annemin Doğum Günleri',
      recurrenceType: RecurrenceType.yearly,
      anchorMonth: 3,
      anchorDay: 3,
      iconKey: 'birthday',
    ),
    const Ritual(
      id: 'rit-yildonumu',
      title: 'Yıldönümlerimiz',
      recurrenceType: RecurrenceType.yearly,
      anchorMonth: 5,
      anchorDay: 15,
      iconKey: 'anniversary',
    ),
  ];

  /// Ritüel kimliği → yılların anıları. Şerit bunları yeniden ESKİYE doğru
  /// sıralı gösteriyor (tasarımdaki sıra: 2023, 2022, 2021…).
  static const Map<String, List<_RawYear>> _yearsByRitual = {
    'rit-yaz': [
      (year: 2026, asset: 'assets/images/home/hero_today.jpg', place: 'Çeşme'),
      (year: 2025, asset: 'assets/images/home/memory_coffee.jpg', place: 'Kaş'),
      (year: 2024, asset: 'assets/images/auth/hero_light.jpg', place: 'Datça'),
      (year: 2023, asset: 'assets/images/home/hero_today.jpg', place: 'Çeşme'),
      // Beşinci yıl BİLEREK var: şerit kaydırılabilir hâle geliyor ve
      // alttaki gösterge görünüyor.
      (
        year: 2022,
        asset: 'assets/images/home/memory_coffee.jpg',
        place: 'Ayvalık',
      ),
    ],
    'rit-dogumgunu': [
      (
        year: 2026,
        asset: 'assets/images/home/memory_coffee.jpg',
        place: 'Ankara',
      ),
      (year: 2025, asset: 'assets/images/auth/hero_light.jpg', place: 'Ankara'),
      (year: 2024, asset: 'assets/images/home/hero_today.jpg', place: 'İzmir'),
    ],
    'rit-yildonumu': [
      (year: 2026, asset: 'assets/images/auth/hero_light.jpg', place: null),
      (
        year: 2025,
        asset: 'assets/images/home/hero_today.jpg',
        place: 'Venedik',
      ),
    ],
  };

  /// Kartların beklediği hâle çevirir: altyazı tekrar tipinden, yıllar
  /// haritadan.
  static List<SeriesCardData> series(AppL10n l10n) {
    return [
      for (final ritual in _rituals)
        (
          id: ritual.id,
          iconKey: ritual.iconKey,
          title: ritual.title,
          // Dilbilgisi burada değil çeviride çözülüyor: Türkçede ek aya göre
          // değişiyor (Mart'ta / Nisan'da / Eylül'de).
          subtitle: ritual.recurrenceLabel(l10n),
          years: [
            for (final year in _yearsByRitual[ritual.id] ?? const <_RawYear>[])
              (
                memoryId: '${ritual.id}-${year.year}',
                year: year.year,
                imageAsset: year.asset,
                placeLabel: year.place,
              ),
          ],
        ),
    ];
  }

  /// Kimlikten seri kartı — seri detay ekranı başlığı için.
  ///
  /// Başlığı ikinci kez yazmak yerine kartların kaynağından okuyoruz: aynı
  /// seri iki yerde farklı adla görünmemeli.
  static SeriesCardData? seriesCardOf(String id, AppL10n l10n) =>
      series(l10n).where((card) => card.id == id).firstOrNull;

  // --- ÖNİZLEME ANILARININ DETAY HÂLİ --------------------------------------
  //
  // ⚠️ GEÇİCİ, dosyanın geri kalanıyla aynı gerekçe. Kartlara dokunulduğunda
  // anı detayı açılıyor ve o ekran bir `MemoryDetail` istiyor; sahte
  // kimliklerin veritabanında karşılığı olmadığı için kaydı yanımızda
  // götürüyoruz (bkz. `MemoryDetailView.previewDetail`).

  /// Gün panelindeki bir anının detayı.
  ///
  /// Panelde başlık, kapak ve kategori zaten var; detay ekranı için tarihi de
  /// biliyoruz (seçili gün). Not ve konum bu kayıtlarda yok — detay ekranının
  /// eksik alanları nasıl karşıladığını görmek de tasarımın parçası.
  static MemoryDetail dayMemoryDetail(DayMemoryData memory, DateTime day) {
    // Anının koleksiyonunu ve serisini BULMAYA çalışıyoruz: aynı kimlik
    // koleksiyon listesinde de geçiyorsa detayda o satır dolu görünmeli.
    // Panelden ve koleksiyondan açılan aynı anı, aynı kaydı göstermeli.
    final fromCollection = collectionMemoryDetail(memory.id);

    return _detail(
      id: memory.id,
      title: memory.title,
      occurredAt: day,
      photoAssets: [memory.imageAsset],
      collections: fromCollection?.collections ?? const [],
      // Gün panelindeki anılar için seri bilgisi yok; kayıt bunu boş
      // bırakıyor ve detay o satırı hiç göstermiyor. Detay ekranının eksik
      // alanları nasıl karşıladığını görmek de tasarımın parçası.
    );
  }

  /// Koleksiyon kartındaki bir anının detayı.
  ///
  /// Buradaki kayıt KOLEKSİYONUNU da taşıyor: kullanıcı "Kapadokya 2026"
  /// içinden geldiğinde detayda o koleksiyonu görmeli, yoksa nereden geldiğini
  /// kaybediyor.
  static MemoryDetail? collectionMemoryDetail(String memoryId) {
    for (final collection in _collections) {
      for (final memory in collection.memories) {
        if (memory.id != memoryId) continue;

        return _detail(
          id: memory.id,
          title: memory.title,
          occurredAt: memory.date,
          photoAssets: [memory.imageAsset],
          collections: [
            MemoryCollection(
              id: collection.id,
              title: collection.title,
              visibility: CollectionVisibility.private,
              startDate: collection.start,
              endDate: collection.end,
            ),
          ],
        );
      }
    }
    return null;
  }

  /// Seri şeridindeki bir yılın detayı.
  ///
  /// Kimlik `<seriKimliği>-<yıl>` biçiminde üretiliyor (bkz. [series]); buradan
  /// geriye ayrıştırıp hangi serinin hangi yılı olduğunu buluyoruz. Detayda
  /// seri satırı bu yüzden dolu geliyor.
  static MemoryDetail? seriesYearDetail(String memoryId) {
    for (final ritual in _rituals) {
      for (final year in _yearsByRitual[ritual.id] ?? const <_RawYear>[]) {
        if (memoryId != '${ritual.id}-${year.year}') continue;

        return _detail(
          id: memoryId,
          // Seri anısının kendi başlığı yok; serinin adı + yıl en anlamlı
          // karşılık ("Yaz Tatillerimiz 2026").
          title: '${ritual.title} ${year.year}',
          // Ayı seriden alıyoruz (`anchorMonth`), yılı şeritten.
          occurredAt: DateTime(year.year, ritual.anchorMonth ?? 1, 1),
          locationLabel: year.place,
          photoAssets: [year.asset],
          ritual: Ritual(
            id: ritual.id,
            title: ritual.title,
            recurrenceType: ritual.recurrenceType,
            anchorMonth: ritual.anchorMonth,
            anchorDay: ritual.anchorDay,
            iconKey: ritual.iconKey,
          ),
          ritualYear: year.year,
        );
      }
    }
    return null;
  }

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
    List<MemoryCollection> collections = const [],
    Ritual? ritual,
    int? ritualYear,
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
        personCount: 0,
        title: title,
        note: note,
        categoryId: categoryId,
        coverMedia: media.firstOrNull,
        locationLabel: locationLabel,
      ),
      people: const [],
      collections: collections,
      media: media,
      ritual: ritual,
      ritualYear: ritualYear,
    );
  }
}

/// Bir serinin tek yılının ham biçimi — yalnızca bu dosyanın içi.
typedef _RawYear = ({int year, String asset, String? place});

/// Sahte koleksiyonun ham biçimi — yalnızca bu dosyanın içi.
typedef _RawCollection = ({
  String id,
  String coverAsset,
  String title,
  DateTime start,
  DateTime? end,
  List<({String id, String imageAsset, String title, DateTime date})> memories,
});
