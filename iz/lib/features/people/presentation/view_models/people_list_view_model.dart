/// Kişiler listesi ViewModel'i.
///
/// MVVM sınırı `memory_list_view_model.dart` başındaki notta anlatılıyor:
/// state üretir, komut alır, repository çağırır — widget bilmez,
/// `BuildContext` tutmaz, SQL bilmez (TR-C-04).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/features/people/data/repositories/person_repository_impl.dart';
import 'package:iz/features/people/domain/entities/person.dart';

class PeopleListViewModel extends StreamNotifier<List<Person>> {
  static final _log = appLogger('people.list_vm');

  @override
  Stream<List<Person>> build() {
    // `watch`: repository değişirse (testte override edilirse) yeniden kurulur.
    return ref.watch(personRepositoryProvider).watchPeople().unwrap();
  }

  // --- Komutlar -----------------------------------------------------------
  //
  // Komutlar `Result` döner, exception fırlatmaz: View hatayı görüp
  // SnackBar gösterebilsin diye. Liste Drift stream'i sayesinde kendiliğinden
  // tazelenir; elle `ref.invalidateSelf()` çağırmaya gerek yok.

  Future<Result<Unit>> toggleFavorite(Person person) {
    _log.fine('toggleFavorite ${person.id}');
    return ref
        .read(personRepositoryProvider)
        .setFavorite(person.id, isFavorite: !person.isFavorite);
  }

  /// TR-M5-12 — kişi silinince ANILAR SİLİNMEZ, yalnız bağ kopar.
  /// Bir insanla ilişkin bitse bile onunla yaşadığın an senin.
  Future<Result<Unit>> delete(String personId) {
    _log.fine('delete $personId');
    return ref.read(personRepositoryProvider).softDelete(personId);
  }
}

final peopleListProvider =
    StreamNotifierProvider<PeopleListViewModel, List<Person>>(
      PeopleListViewModel.new,
    );

/// Tek bir kişinin canlı akışı — detay ekranı için.
///
/// `family` kullanıyoruz: her kimlik için ayrı bir abonelik. Tüm listeyi
/// izleyip içinden aramak da olurdu ama o zaman listedeki HERHANGİ bir
/// değişiklik detay ekranını yeniden çizerdi.
final personDetailProvider = StreamProvider.family<Person?, String>((ref, id) {
  return ref.watch(personRepositoryProvider).watchPerson(id).unwrap();
});
