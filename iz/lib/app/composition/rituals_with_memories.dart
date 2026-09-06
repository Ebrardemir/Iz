/// Serileri ANILARIYLA birlikte veren birleşik akış.
///
/// NEDEN `features/rituals/` ALTINDA DEĞİL?
/// Gerekçesi `collections_with_memories.dart`ın aynısı: burası iki ayrı
/// feature'ı birleştiriyor — seri `RitualRepository`den, anıları
/// `MemoryRepository`den geliyor. Bir feature başka feature'ın YALNIZ
/// `domain/`ini görebilir (TR-C-03); seri tarafına koysaydık anıların veri
/// katmanına uzanmak zorunda kalırdı.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/features/rituals/domain/repositories/ritual_repository.dart';
import 'package:iz/features/rituals/presentation/view_models/rituals_list_view_model.dart';

/// Seri + o serinin yıl yıl anıları.
///
/// FR-076 — seri görünümü YILLARI KARŞILAŞTIRIYOR; yıl bilgisi anının
/// tarihinden değil, bağ tablosundaki `occurrenceYear`dan geliyor (BR-012).
/// İkisi ayrı olabilir: 31 Aralık'ta çekilen bir fotoğraf bir sonraki yılın
/// kutlamasına ait olabilir.
typedef RitualWithMemories = ({
  Ritual ritual,
  List<({Memory memory, int year})> years,
});

/// Herhangi bir seriye bağlı TÜM anılar.
///
/// Seri başına ayrı sorgu açmıyoruz: 20 seri = 20 abonelik demekti.
final _ritualMemoriesProvider = StreamProvider<List<Memory>>((ref) {
  final links = ref.watch(ritualOccurrencesProvider).value ?? const {};
  if (links.isEmpty) return Stream.value(const []);

  final ids = {
    for (final entry in links.values)
      for (final occurrence in entry) occurrence.memoryId,
  };

  // `MemoryFilter` doğrudan kimlik listesi almıyor; seriye bağlı anıları
  // tümünün içinden süzüyoruz. Liste zaten bellekte ve küçük.
  return ref
      .watch(memoryRepositoryProvider)
      .watchMemories(MemoryFilter.all)
      .unwrap()
      .map(
        (all) => [
          for (final memory in all)
            if (ids.contains(memory.id)) memory,
        ],
      );
});

/// Ekranın gördüğü birleşik liste.
final ritualsWithMemoriesProvider =
    Provider<AsyncValue<List<RitualWithMemories>>>((ref) {
      final rituals = ref.watch(ritualsListProvider);
      final links = ref.watch(ritualOccurrencesProvider);
      final memories = ref.watch(_ritualMemoriesProvider);

      // Seriler yüklenmeden liste kurulamaz. Bağlar ve anılar gecikirse boş
      // kabul ediliyor: anısı olmayan seri de görünmeli, aksi hâlde yeni
      // açılmış bir seri hiç belirmezdi.
      return rituals.whenData((list) {
        final linkMap = links.value ?? const <String, List<RitualOccurrence>>{};
        final byId = {
          for (final memory in memories.value ?? const <Memory>[])
            memory.id: memory,
        };

        return [
          for (final ritual in list)
            (
              ritual: ritual,
              years: [
                for (final occurrence
                    in linkMap[ritual.id] ?? const <RitualOccurrence>[])
                  if (byId[occurrence.memoryId] case final memory?)
                    (memory: memory, year: occurrence.year),
              ],
            ),
        ];
      });
    });
