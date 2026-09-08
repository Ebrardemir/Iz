/// Kişi detayının TÜRETİLMİŞ bölümleri: paylaşılan koleksiyonlar ve seriler.
///
/// NEDEN `features/people/` ALTINDA DEĞİL?
/// Üç feature'ı birleştiriyor — kişi, koleksiyon/anı ve seri. Bir feature
/// başka feature'ın yalnız `domain/`ini görebilir (TR-C-03); kişi tarafına
/// koysaydık ötekilerin veri katmanına uzanmak zorunda kalırdı.
///
/// NEDEN TÜRETİYORUZ, SAKLAMIYORUZ?
/// "Bu kişiyle hangi koleksiyonları paylaşıyorum?" sorusunun cevabı zaten
/// veride var: kişinin etiketli olduğu anılar ve o anıların koleksiyonları.
/// Ayrıca saklasaydık, koleksiyona sonradan eklenen bir anı listeyi eskitir
/// ve kimse fark etmezdi. Türetilen liste kendiliğinden doğru kalıyor.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/features/collections/presentation/view_models/collections_list_view_model.dart';
import 'package:iz/features/media/media_providers.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';
import 'package:iz/features/people/presentation/widgets/person_detail_rows.dart';
import 'package:iz/features/rituals/presentation/view_models/rituals_list_view_model.dart';

/// Kişinin etiketli olduğu anılar.
final _personMemoriesProvider = StreamProvider.family<List<Memory>, String>((
  ref,
  personId,
) {
  return ref
      .watch(memoryRepositoryProvider)
      .watchMemories(MemoryFilter(personIds: {personId}))
      .unwrap();
});

/// FR-063 — kişiyle paylaşılan koleksiyonlar.
///
/// SAYAÇ, O KİŞİYLE PAYLAŞILAN anı sayısı — koleksiyonun toplam anısı değil.
/// Ekranda kişinin kartında duruyor; oraya koleksiyonun tümünü yazmak
/// "annemle 18 anı paylaşmışım" gibi yanlış bir izlenim verirdi.
final personCollectionsProvider =
    Provider.family<AsyncValue<List<PersonCollection>>, String>((
      ref,
      personId,
    ) {
      final memories = ref.watch(_personMemoriesProvider(personId));
      final links = ref.watch(collectionMemoryLinksProvider).value ?? const {};
      final collections = ref.watch(collectionsListProvider).value ?? const [];
      final covers = ref.watch(_coversProvider).value ?? const {};

      return memories.whenData((list) {
        final personMemoryIds = {for (final memory in list) memory.id};

        return [
          for (final collection in collections)
            if (_sharedCount(links[collection.id], personMemoryIds) case final n
                when n > 0)
              (
                id: collection.id,
                cover: collection.coverMediaId == null
                    ? null
                    : covers[collection.coverMediaId],
                title: collection.title,
                memoryCount: n,
              ),
        ];
      });
    });

int _sharedCount(List<String>? memoryIds, Set<String> personMemoryIds) {
  if (memoryIds == null) return 0;
  var count = 0;
  for (final id in memoryIds) {
    if (personMemoryIds.contains(id)) count++;
  }
  return count;
}

/// FR-064 — kişiye bağlı seriler.
///
/// Bağ şema v7'den beri doğrudan: `RitualPeople`. Türetmeye gerek yok,
/// kullanıcı seriyi kurarken kimlerle paylaştığını kendisi söylüyor.
final personRitualsProvider =
    Provider.family<AsyncValue<List<PersonRitual>>, String>((ref, personId) {
      final rituals = ref.watch(ritualsListProvider);
      final peopleLinks =
          ref.watch(ritualPeopleLinksProvider).value ?? const {};
      final occurrences =
          ref.watch(ritualOccurrencesProvider).value ?? const {};

      return rituals.whenData(
        (list) => [
          for (final ritual in list)
            if (peopleLinks[ritual.id]?.contains(personId) ?? false)
              (
                iconKey: ritual.iconKey,
                title: ritual.title,
                // "Kaç yıl" = kaç ayrı yılda anısı var (BR-012).
                years: occurrences[ritual.id]?.length ?? 0,
              ),
        ],
      );
    });

/// Koleksiyon kapakları — kimlikten görsele.
final _coversProvider = FutureProvider((ref) async {
  final collections = ref.watch(collectionsListProvider).value ?? const [];
  final ids = [for (final collection in collections) ?collection.coverMediaId];
  if (ids.isEmpty) return const {};

  final result = await ref.watch(mediaRepositoryProvider).findMany(ids);
  return {for (final media in result.getOrElse(const [])) media.id: media};
});
