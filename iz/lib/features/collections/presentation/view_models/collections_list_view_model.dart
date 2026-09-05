/// Koleksiyonlar listesi ViewModel'i.
///
/// MVVM sınırı `memory_list_view_model.dart` başındaki notta anlatılıyor:
/// state üretir, komut alır, repository çağırır — widget bilmez,
/// `BuildContext` tutmaz, SQL bilmez (TR-C-04).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/features/collections/data/repositories/collection_repository_impl.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';

/// Koleksiyon + içindeki anılar.
///
/// NEDEN AYRI TİP?
/// [MemoryCollection] domain varlığı ve anıları TAŞIMIYOR — bağ ayrı bir
/// tabloda yaşıyor. Ekranın ihtiyacı ikisinin birleşimi; entity'ye anı
/// listesi eklemek, koleksiyonu her okuduğumuz yerde anıları da yüklemek
/// demekti (NFR-003).
typedef CollectionWithMemories = ({
  MemoryCollection collection,
  List<Memory> memories,
});

class CollectionsListViewModel extends StreamNotifier<List<MemoryCollection>> {
  static final _log = appLogger('collections.list_vm');

  @override
  Stream<List<MemoryCollection>> build() {
    return ref.watch(collectionRepositoryProvider).watchCollections().unwrap();
  }

  // --- Komutlar -----------------------------------------------------------
  //
  // Komutlar `Result` döner, exception fırlatmaz: View hatayı görüp
  // SnackBar gösterebilsin diye. Liste Drift stream'i sayesinde kendiliğinden
  // tazelenir.

  /// TR-M6-11 — koleksiyon silinince ANILAR SİLİNMEZ, yalnız bağ kopar.
  Future<Result<Unit>> delete(String collectionId) {
    _log.fine('delete $collectionId');
    return ref.read(collectionRepositoryProvider).softDelete(collectionId);
  }
}

final collectionsListProvider =
    StreamNotifierProvider<CollectionsListViewModel, List<MemoryCollection>>(
      CollectionsListViewModel.new,
    );

/// Tek bir koleksiyonun canlı akışı — detay/düzenleme ekranı için.
final collectionDetailProvider =
    StreamProvider.family<MemoryCollection?, String>(
      (ref, id) =>
          ref.watch(collectionRepositoryProvider).watchCollection(id).unwrap(),
    );

/// Koleksiyon → anı kimlikleri.
final collectionMemoryLinksProvider = StreamProvider<Map<String, List<String>>>(
  (ref) {
    return ref.watch(collectionRepositoryProvider).watchMemoryLinks().unwrap();
  },
);

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
              memories: [
                for (final id in linkMap[collection.id] ?? const <String>[])
                  ?byId[id],
              ],
            ),
        ];
      });
    });
