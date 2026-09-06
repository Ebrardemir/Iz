/// Koleksiyonları ANILARIYLA birlikte veren birleşik akış.
///
/// NEDEN `features/collections/` ALTINDA DEĞİL?
/// Burası iki ayrı feature'ı birleştiriyor: koleksiyonun kendisi
/// `CollectionRepository`den, içindeki anılar `MemoryRepository`den geliyor.
/// Bir feature başka feature'ın YALNIZ `domain/`ini görebilir
/// (ARCHITECTURE.md §2, TR-C-03); koleksiyon tarafına koysaydık anıların veri
/// katmanına uzanmak zorunda kalırdı ve sınır delinirdi.
///
/// `app/` her şeyi bilmeye yetkili tek katman — router da bu yüzden burada.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/collections/presentation/view_models/collections_list_view_model.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/media/media_providers.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';

/// Koleksiyon + içindeki anılar.
///
/// NEDEN AYRI TİP?
/// [MemoryCollection] domain varlığı anıları TAŞIMIYOR — bağ ayrı bir tabloda
/// yaşıyor. Ekranın ihtiyacı ikisinin birleşimi; entity'ye anı listesi
/// eklemek, koleksiyonu her okuduğumuz yerde anıları da yüklemek demekti
/// (NFR-003).
typedef CollectionWithMemories = ({
  MemoryCollection collection,
  List<Memory> memories,

  /// Koleksiyonun kapağı — `coverMediaId` çözülmüş hâli.
  ///
  /// Entity yalnızca KİMLİK taşıyor; görseli burada çözüyoruz çünkü kart
  /// hazır bir [MediaItem] bekliyor ve `MediaThumbnail` kayıp dosyayı kendi
  /// içinde ele alıyor.
  MediaItem? cover,
});

/// Koleksiyonların kapak görselleri — kimlikten `MediaItem`a.
///
/// TEK SORGUDA: koleksiyon başına ayrı çağrı açmak 20 koleksiyonda 20 sorgu
/// demekti.
final _collectionCoversProvider = FutureProvider<Map<String, MediaItem>>((
  ref,
) async {
  final collections = ref.watch(collectionsListProvider).value ?? const [];
  final ids = [for (final collection in collections) ?collection.coverMediaId];
  if (ids.isEmpty) return const {};

  final result = await ref.watch(mediaRepositoryProvider).findMany(ids);
  return switch (result) {
    Ok(:final value) => {for (final media in value) media.id: media},
    // Kapak çözülemezse kart yer tutucu çiziyor; liste yine görünüyor.
    Err() => const {},
  };
});

/// Herhangi bir koleksiyona bağlı TÜM anılar.
///
/// Koleksiyon başına ayrı sorgu açmıyoruz: 20 koleksiyon = 20 abonelik
/// demekti. Tek sorgu, gruplama Dart tarafında.
final _collectionMemoriesProvider = StreamProvider<List<Memory>>((ref) {
  final links = ref.watch(collectionMemoryLinksProvider).value ?? const {};
  if (links.isEmpty) return Stream.value(const []);

  return ref
      .watch(memoryRepositoryProvider)
      .watchMemories(MemoryFilter(collectionIds: links.keys.toSet()))
      .unwrap();
});

/// Ekranın gördüğü birleşik liste.
///
/// NEDEN `Provider` İÇİNDE BİRLEŞTİRME?
/// Üç ayrı akışı (koleksiyonlar, bağlar, anılar) birleştirmek gerekiyor.
/// rxdart eklemek yerine Riverpod'un kendi bağımlılık takibini kullanıyoruz:
/// herhangi biri değişince bu provider yeniden hesaplanıyor.
///
/// Anı sırası kullanıcının formda dizdiği sıra — bağ tablosundaki
/// `sortOrder`. Anıları tarihe göre yeniden sıralasaydık kullanıcının
/// kurduğu anlatı bozulurdu.
final collectionsWithMemoriesProvider =
    Provider<AsyncValue<List<CollectionWithMemories>>>((ref) {
      final collections = ref.watch(collectionsListProvider);
      final links = ref.watch(collectionMemoryLinksProvider);
      final memories = ref.watch(_collectionMemoriesProvider);
      final covers = ref.watch(_collectionCoversProvider).value ?? const {};

      // Koleksiyonlar yüklenmeden liste kurulamaz. Bağlar ve anılar ise
      // gecikirse boş kabul ediliyor: koleksiyon kartı anısız da görünmeli,
      // aksi hâlde yeni açılmış boş bir koleksiyon hiç belirmezdi.
      return collections.whenData((list) {
        final linkMap = links.value ?? const <String, List<String>>{};
        final byId = {
          for (final memory in memories.value ?? const <Memory>[])
            memory.id: memory,
        };

        return [
          for (final collection in list)
            (
              collection: collection,
              cover: collection.coverMediaId == null
                  ? null
                  : covers[collection.coverMediaId],
              memories: [
                for (final id in linkMap[collection.id] ?? const <String>[])
                  ?byId[id],
              ],
            ),
        ];
      });
    });
