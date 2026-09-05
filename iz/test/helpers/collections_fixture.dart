/// Koleksiyon ekranlarının test verisi.
///
/// NEDEN `lib/` ALTINDA DEĞİL?
/// Bu veri bir zamanlar `my_life_preview_data.dart` içindeydi ve ÜRETİM
/// kodundan okunuyordu. Koleksiyonların gerçek veri hattı kurulunca orada
/// kalmasının anlamı kalmadı: sahte veri yalnız testin ihtiyacı. Kişiler
/// tarafında `people_fixture.dart` ile aynı gerekçe.
library;

import 'package:iz/core/extensions/date_x.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/collections/presentation/view_models/collections_list_view_model.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/my_life/presentation/widgets/collection_card.dart';

abstract final class CollectionsFixture {
  /// Kimlikler `MyLifePreviewData` ile AYNI: anı detayı hâlâ oradan
  /// çözülüyor, kimlikler ayrışırsa "anıya git" bulunamaz duruma düşer.
  static List<CollectionWithMemories> withMemories() => [
    (
      collection: MemoryCollection(
        id: 'col-kapadokya',
        title: 'Kapadokya 2026',
        visibility: CollectionVisibility.private,
        startDate: DateTime(2026, 5, 10),
        endDate: DateTime(2026, 5, 14),
      ),
      memories: [
        _memory('mem-balon', 'Balonlar havalanırken', DateTime(2026, 5, 10)),
        _memory('mem-vadi', 'Güvercinlik Vadisi', DateTime(2026, 5, 12)),
        _memory(
          'mem-gunbatimi',
          "Kızılçukur'da gün batımı",
          DateTime(2026, 5, 14),
        ),
      ],
    ),
    (
      collection: MemoryCollection(
        id: 'col-universite',
        title: 'Üniversite Yıllarım',
        visibility: CollectionVisibility.private,
        startDate: DateTime(2021, 9, 20),
        endDate: DateTime(2025, 6, 14),
      ),
      memories: [
        _memory('mem-ilk-gun', 'Kampüste ilk gün', DateTime(2021, 9, 20)),
        _memory('mem-mezuniyet', 'Mezuniyet', DateTime(2025, 6, 14)),
      ],
    ),
    (
      collection: MemoryCollection(
        id: 'col-kahvaltilar',
        title: 'Pazar Kahvaltıları',
        visibility: CollectionVisibility.private,
        startDate: DateTime(2026, 3),
      ),
      memories: [_memory('mem-kahve', 'Kahve Molası', DateTime(2026, 3))],
    ),
  ];

  /// Sahte deponun tohumu: koleksiyonlar.
  static List<MemoryCollection> get collections => [
    for (final entry in withMemories()) entry.collection,
  ];

  /// Sahte anı deposunun tohumu.
  static List<Memory> get memories => [
    for (final entry in withMemories()) ...entry.memories,
  ];

  /// Koleksiyon → anı kimlikleri.
  static Map<String, List<String>> get links => {
    for (final entry in withMemories())
      entry.collection.id: [for (final memory in entry.memories) memory.id],
  };

  /// `MyLifeView`i doğrudan kuran widget testleri için hazır kartlar.
  ///
  /// Özet satırı ("3 anı • 10-14 Mayıs 2026") burada YAZILI DEĞİL: sayaç
  /// çeviriden, aralık `AppDateFormats`ten üretiliyor — üretimdeki yolun
  /// aynısı. Hazır yazsaydık test, biçimlendirme bozulsa bile geçerdi.
  static List<CollectionCardData> cards(AppL10n l10n, {String? locale}) {
    const cover = 'assets/images/home/hero_today.jpg';

    return [
      for (final entry in withMemories())
        (
          id: entry.collection.id,
          coverAsset: cover,
          title: entry.collection.title,
          summary: [
            l10n.memoryCount(entry.memories.length),
            if (entry.collection.startDate case final start?)
              AppDateFormats.range(
                start,
                entry.collection.endDate,
                locale: locale,
              ),
          ].join(' • '),
          memories: [
            for (final memory in entry.memories)
              (
                id: memory.id,
                imageAsset: cover,
                title: memory.displayTitle(l10n.memoryNew),
                dateLabel: AppDateFormats.long(
                  memory.occurredAt,
                  locale: locale,
                ),
              ),
          ],
        ),
    ];
  }

  static Memory _memory(String id, String title, DateTime date) => Memory(
    id: id,
    occurredAt: date,
    title: title,
    isFavorite: false,
    mediaCount: 1,
    personCount: 0,
  );
}
