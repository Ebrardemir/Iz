/// Günlük listesi ViewModel'i.
///
/// MVVM sınırı `memory_list_view_model.dart` başındaki notta anlatılıyor:
/// state üretir, komut alır, repository çağırır — widget bilmez,
/// `BuildContext` tutmaz, SQL bilmez (TR-C-04).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/journal/journal_providers.dart';

class JournalListViewModel extends StreamNotifier<List<JournalEntry>> {
  static final _log = appLogger('journal.list_vm');

  @override
  Stream<List<JournalEntry>> build() {
    return ref.watch(journalRepositoryProvider).watchEntries().unwrap();
  }

  // --- Komutlar -----------------------------------------------------------
  //
  // Komutlar `Result` döner, exception fırlatmaz: View hatayı görüp
  // SnackBar gösterebilsin diye. Liste Drift stream'i sayesinde kendiliğinden
  // tazelenir.

  Future<Result<Unit>> toggleFavorite(JournalEntry entry) {
    _log.fine('toggleFavorite ${entry.id}');
    return ref
        .read(journalRepositoryProvider)
        .setFavorite(entry.id, isFavorite: !entry.isFavorite);
  }

  Future<Result<Unit>> delete(String entryId) {
    _log.fine('delete $entryId');
    return ref.read(journalRepositoryProvider).softDelete(entryId);
  }
}

final journalListProvider =
    StreamNotifierProvider<JournalListViewModel, List<JournalEntry>>(
      JournalListViewModel.new,
    );
