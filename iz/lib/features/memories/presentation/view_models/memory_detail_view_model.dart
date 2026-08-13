/// Anı detay ViewModel'i — **family** kullanımının örneği.
///
/// FAMILY NEDİR?
/// Parametreye bağlı provider. Her `memoryId` için ayrı bir ViewModel
/// örneği yaşar; biri güncellenince diğeri etkilenmez.
///
/// DİKKAT (Riverpod 3): family'de argüman `build()` metoduna DEĞİL,
/// notifier'ın **constructor**'ına gelir. Aşağıdaki `MemoryDetailViewModel.new`
/// çağrısı bu yüzden çalışır.
///
/// KULLANIM (View içinde):
/// ```dart
/// final state = ref.watch(memoryDetailProvider(memoryId));
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';

class MemoryDetailViewModel extends StreamNotifier<MemoryDetail?> {
  MemoryDetailViewModel(this.memoryId);

  /// Family argümanı.
  final String memoryId;

  @override
  Stream<MemoryDetail?> build() {
    return ref.watch(memoryRepositoryProvider).watchDetail(memoryId).unwrap();
  }

  Future<Result<Unit>> toggleFavorite() async {
    final current = state.value;
    if (current == null) return okUnit;

    return ref
        .read(memoryRepositoryProvider)
        .setFavorite(memoryId, isFavorite: !current.memory.isFavorite);
  }

  Future<Result<Unit>> moveToTrash() =>
      ref.read(memoryRepositoryProvider).moveToTrash(memoryId);

  Future<Result<Unit>> archive() => ref
      .read(memoryRepositoryProvider)
      .setArchived(memoryId, isArchived: true);
}

final memoryDetailProvider =
    StreamNotifierProvider.family<MemoryDetailViewModel, MemoryDetail?, String>(
      MemoryDetailViewModel.new,
      // Ekran kapanınca ViewModel'i bellekte tutma.
      isAutoDispose: true,
    );
