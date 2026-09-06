/// Bellekte çalışan sahte seri (ritüel) deposu.
///
/// NEDEN GERÇEK DEPO DEĞİL?
/// Gerekçesi `fake_collection_repository.dart` başındaki notta: widget
/// testinde gerçek Drift bekleyen timer bırakır. SQL'in doğruluğu
/// `test/unit/ritual_repository_test.dart`ta gerçek SQLite ile zaten test
/// ediliyor; widget testinin işi ekranın davranışı.
library;

import 'dart:async';

import 'package:iz/core/result/result.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/features/rituals/domain/repositories/ritual_repository.dart';

class FakeRitualRepository implements RitualRepository {
  FakeRitualRepository([List<Ritual>? initial]) : _rituals = [...?initial];

  final List<Ritual> _rituals;
  final _controller = StreamController<void>.broadcast();

  /// Testlerin doğrulayabilmesi için.
  final List<RitualDraft> saved = [];
  final List<String> deleted = [];

  /// Seri kimliği → bağlı anılar ve yılları.
  final Map<String, List<RitualOccurrence>> occurrences = {};

  int _idCounter = 0;

  List<Ritual> get rituals => List.unmodifiable(_rituals);

  @override
  Stream<Result<List<Ritual>>> watchRituals() async* {
    yield Ok(List.unmodifiable(_rituals));
    yield* _controller.stream.map((_) => Ok(List.unmodifiable(_rituals)));
  }

  @override
  Stream<Result<Ritual?>> watchRitual(String id) async* {
    yield Ok(_find(id));
    yield* _controller.stream.map((_) => Ok(_find(id)));
  }

  @override
  Future<Result<Ritual?>> findRitual(String id) async => Ok(_find(id));

  @override
  Stream<Result<Map<String, List<RitualOccurrence>>>>
  watchOccurrences() async* {
    yield Ok(Map.unmodifiable(occurrences));
    yield* _controller.stream.map((_) => Ok(Map.unmodifiable(occurrences)));
  }

  @override
  Future<Result<String>> save(RitualDraft draft) async {
    saved.add(draft);
    final id = draft.id ?? 'sahte-seri-${++_idCounter}';

    final ritual = Ritual(
      id: id,
      title: draft.title,
      recurrenceType: draft.recurrenceType,
      relatedPersonId: draft.relatedPersonId,
      anchorMonth: draft.anchorMonth,
      anchorDay: draft.anchorDay,
      iconKey: draft.iconKey,
    );

    final index = _rituals.indexWhere((r) => r.id == id);
    if (index >= 0) {
      _rituals[index] = ritual;
    } else {
      _rituals.add(ritual);
    }

    // `null` = "bağlara dokunma" — gerçeğindeki ayrımın aynısı.
    if (draft.occurrences case final list?) {
      occurrences[id] = [...list];
    }

    _notify();
    return Ok(id);
  }

  @override
  Future<Result<Unit>> softDelete(String id) async {
    deleted.add(id);
    _rituals.removeWhere((r) => r.id == id);
    _notify();
    return const Ok(Unit.value);
  }

  Ritual? _find(String id) {
    for (final ritual in _rituals) {
      if (ritual.id == id) return ritual;
    }
    return null;
  }

  void _notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => _controller.close();
}
