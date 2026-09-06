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
import 'package:iz/features/collections/collections_providers.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';

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
