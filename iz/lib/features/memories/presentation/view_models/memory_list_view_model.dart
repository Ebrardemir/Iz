/// Timeline / anı listesi ViewModel'i.
///
/// MVVM'DE ViewModel NE YAPAR?
///   ✔ View'ın ihtiyacı olan state'i üretir (`AsyncValue<List<Memory>>`)
///   ✔ View'dan gelen komutları alır (favori, sil, geri al)
///   ✔ Repository/UseCase çağırır
///   ✘ Widget bilmez, BuildContext tutmaz, Navigator çağırmaz
///   ✘ SQL bilmez
///
/// Bu sınıfı test etmek için Flutter'a hiç ihtiyaç yok — saf Dart testi
/// yazılabilir (bkz. test/unit/memory_list_view_model_test.dart).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/presentation/view_models/memory_filter_view_model.dart';

class MemoryListViewModel extends StreamNotifier<List<Memory>> {
  static final _log = appLogger('memories.list_vm');

  @override
  Stream<List<Memory>> build() {
    // `watch` kullanıyoruz: filtre değişince Riverpod bu build'i yeniden
    // çalıştırır, eski stream'e aboneliği otomatik iptal eder.
    // `read` kullansaydık filtre değişimi listeyi güncellemezdi.
    final filter = ref.watch(memoryFilterProvider);
    final repository = ref.watch(memoryRepositoryProvider);

    return repository.watchMemories(filter).unwrap();
  }

  // --- Komutlar -----------------------------------------------------------
  //
  // Komutlar `Result` döner, exception fırlatmaz: View hatayı görüp
  // SnackBar gösterebilsin diye. Liste kendisi Drift stream'i sayesinde
  // otomatik tazelenir — elle `ref.invalidateSelf()` çağırmaya gerek yok.

  /// FR-019
  Future<Result<Unit>> toggleFavorite(Memory memory) {
    _log.fine('toggleFavorite ${memory.id}');
    return ref
        .read(memoryRepositoryProvider)
        .setFavorite(memory.id, isFavorite: !memory.isFavorite);
  }

  /// FR-015 — çöp kutusuna taşır. Geri alma için [restore] kullanılır.
  Future<Result<Unit>> moveToTrash(String memoryId) {
    return ref.read(memoryRepositoryProvider).moveToTrash(memoryId);
  }

  /// SnackBar'daki "Geri al" eylemi.
  Future<Result<Unit>> restore(String memoryId) {
    return ref.read(memoryRepositoryProvider).restoreFromTrash(memoryId);
  }

  /// FR-014
  Future<Result<Unit>> archive(String memoryId) {
    return ref
        .read(memoryRepositoryProvider)
        .setArchived(memoryId, isArchived: true);
  }
}

final memoryListProvider =
    StreamNotifierProvider<MemoryListViewModel, List<Memory>>(
      MemoryListViewModel.new,
    );

/// Ana ekranın "hiç anı var mı?" kontrolü — boş durum ekranı için (NFR-035).
final memoryCountProvider = FutureProvider<int>((ref) async {
  // Liste değiştiğinde sayım da tazelensin.
  ref.watch(memoryListProvider);
  final result = await ref.watch(memoryRepositoryProvider).countAll();
  return result.getOrElse(0);
});
