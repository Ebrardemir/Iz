/// Seri ekranlarının test verisi.
///
/// NEDEN `lib/` ALTINDA DEĞİL?
/// Bu veri bir zamanlar `my_life_preview_data.dart` içindeydi ve ÜRETİM
/// kodundan okunuyordu. Serilerin gerçek veri hattı kurulunca orada kalmasının
/// anlamı kalmadı: sahte veri yalnız testin ihtiyacı. Kişiler ve koleksiyonlar
/// tarafında da aynı taşımayı yaptık.
library;

import 'package:iz/app/composition/rituals_with_memories.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/my_life/presentation/widgets/series_card.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/features/rituals/presentation/ritual_l10n.dart';

abstract final class RitualsFixture {
  /// "Yaz Tatillerimiz" ALTI YIL, DÖRT ŞEHİR taşıyor.
  ///
  /// Bu sayılar keyfi değil: seri detayı "6 anı • 6 yıl • 4 şehir" özetini
  /// ve "Tümünü Gör" katlamasını gösteriyor. Fikstürü küçültmek o davranışları
  /// test edilemez hâle getirirdi.
  static List<RitualWithMemories> withMemories() => [
    (
      ritual: const Ritual(
        id: 'rit-yaz',
        title: 'Yaz Tatillerimiz',
        // Tarihi kayan ritüel: her yıl aynı güne denk gelmiyor.
        recurrenceType: RecurrenceType.seasonal,
        anchorMonth: 7,
        iconKey: 'summer',
      ),
      years: [
        _year('mem-yaz-2021', 'Çeşme’de gün batımı', 'Çeşme', 2021),
        _year('mem-yaz-2022', 'Kekova tekne turu', 'Kaş', 2022),
        _year('mem-yaz-2023', 'Sabah yüzüşü', 'Çeşme', 2023),
        _year('mem-yaz-2024', 'Bodrum’da kahvaltı', 'Bodrum', 2024),
        _year('mem-yaz-2025', 'Datça yolu', 'Datça', 2025),
        _year('mem-yaz-2026', 'Son gece', 'Bodrum', 2026),
      ],
    ),
    (
      ritual: const Ritual(
        id: 'rit-dogumgunu',
        title: 'Annemin Doğum Günleri',
        recurrenceType: RecurrenceType.yearly,
        anchorMonth: 3,
        anchorDay: 3,
        iconKey: 'birthday',
      ),
      years: [_year('mem-dg-2026', 'Pasta ve mumlar', null, 2026, month: 3)],
    ),
  ];

  /// `MyLifeView`i doğrudan kuran widget testleri için hazır kartlar.
  ///
  /// Altyazı ("Her yıl yaz aylarında") burada YAZILI DEĞİL: tekrar tipinden
  /// çeviriyle üretiliyor — üretimdeki yolun aynısı.
  static List<SeriesCardData> cards(AppL10n l10n) => [
    for (final entry in withMemories())
      (
        id: entry.ritual.id,
        iconKey: entry.ritual.iconKey,
        title: entry.ritual.title,
        subtitle: entry.ritual.recurrenceLabel(l10n),
        years: [
          for (final year in entry.years)
            (
              memoryId: year.memory.id,
              year: year.year,
              cover: year.memory.coverMedia,
              placeLabel: year.memory.locationLabel,
            ),
        ],
      ),
  ];

  /// Sahte deponun tohumu.
  static List<Ritual> get rituals => [
    for (final entry in withMemories()) entry.ritual,
  ];

  /// Sahte anı deposunun tohumu.
  static List<Memory> get memories => [
    for (final entry in withMemories())
      for (final year in entry.years) year.memory,
  ];

  /// Seri kimliği → anı kimlikleri ve yılları.
  static Map<String, List<({String memoryId, int year})>> get occurrences => {
    for (final entry in withMemories())
      entry.ritual.id: [
        for (final year in entry.years)
          (memoryId: year.memory.id, year: year.year),
      ],
  };

  static ({Memory memory, int year}) _year(
    String id,
    String title,
    String? place,
    int year, {
    int month = 7,
  }) => (
    memory: Memory(
      id: id,
      occurredAt: DateTime(year, month, 12),
      title: title,
      locationLabel: place,
      isFavorite: false,
      mediaCount: 1,
      personCount: 0,
    ),
    year: year,
  );
}
