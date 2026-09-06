/// Seriler listesi ViewModel'i.
///
/// MVVM sınırı `memory_list_view_model.dart` başındaki notta anlatılıyor:
/// state üretir, komut alır, repository çağırır — widget bilmez,
/// `BuildContext` tutmaz, SQL bilmez (TR-C-04).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/features/rituals/domain/repositories/ritual_repository.dart';
import 'package:iz/features/rituals/rituals_providers.dart';

class RitualsListViewModel extends StreamNotifier<List<Ritual>> {
  static final _log = appLogger('rituals.list_vm');

  @override
  Stream<List<Ritual>> build() {
    return ref.watch(ritualRepositoryProvider).watchRituals().unwrap();
  }

  // --- Komutlar -----------------------------------------------------------
  //
  // Komutlar `Result` döner, exception fırlatmaz: View hatayı görüp
  // SnackBar gösterebilsin diye. Liste Drift stream'i sayesinde kendiliğinden
  // tazelenir.

  /// Seri silinince ANILAR SİLİNMEZ, yalnız bağ kopar.
  Future<Result<Unit>> delete(String ritualId) {
    _log.fine('delete $ritualId');
    return ref.read(ritualRepositoryProvider).softDelete(ritualId);
  }
}

final ritualsListProvider =
    StreamNotifierProvider<RitualsListViewModel, List<Ritual>>(
      RitualsListViewModel.new,
    );

/// Tek bir serinin canlı akışı — detay ekranı için.
final ritualDetailProvider = StreamProvider.family<Ritual?, String>(
  (ref, id) => ref.watch(ritualRepositoryProvider).watchRitual(id).unwrap(),
);

/// Seri kimliği → bağlı anılar ve yılları.
final ritualOccurrencesProvider =
    StreamProvider<Map<String, List<RitualOccurrence>>>((ref) {
      return ref.watch(ritualRepositoryProvider).watchOccurrences().unwrap();
    });
