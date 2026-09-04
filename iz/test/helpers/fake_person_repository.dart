/// Bellekte çalışan sahte kişi deposu.
///
/// NEDEN GERÇEK VERİTABANI DEĞİL?
/// Gerekçesi `fake_memory_repository.dart` başındaki notta: widget testinde
/// gerçek Drift bekleyen timer bırakır. Ayrıca SQL'in doğruluğu
/// `test/unit/person_repository_test.dart`ta gerçek SQLite ile zaten test
/// ediliyor; widget testinin işi ekranın davranışı.
library;

import 'dart:async';

import 'package:iz/core/result/result.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/people/domain/repositories/person_repository.dart';

class FakePersonRepository implements PersonRepository {
  FakePersonRepository([List<Person>? initial]) : _people = [...?initial];

  final List<Person> _people;
  final _controller = StreamController<void>.broadcast();

  /// Testlerin doğrulayabilmesi için: hangi kişiler silindi, hangileri
  /// favorilendi.
  final List<String> deleted = [];
  final List<PersonDraft> saved = [];

  int _idCounter = 0;

  List<Person> get people => List.unmodifiable(_people);

  @override
  Stream<Result<List<Person>>> watchPeople() async* {
    yield Ok(List.unmodifiable(_people));
    yield* _controller.stream.map((_) => Ok(List.unmodifiable(_people)));
  }

  @override
  Stream<Result<Person?>> watchPerson(String id) async* {
    yield Ok(_find(id));
    yield* _controller.stream.map((_) => Ok(_find(id)));
  }

  @override
  Future<Result<Person?>> findPerson(String id) async => Ok(_find(id));

  @override
  Future<Result<String>> save(PersonDraft draft) async {
    saved.add(draft);
    final id = draft.id ?? 'sahte-kisi-${++_idCounter}';

    final person = Person(
      id: id,
      name: draft.name,
      kind: draft.kind,
      // Gerçeğinde tür yazılandan türetiliyor; sahtede bu ayrıntıyı
      // taklit etmiyoruz çünkü `person_repository_test.dart` onu zaten
      // gerçek kurallarla sınıyor.
      relationType: RelationType.other,
      relationLabel: draft.relationLabel,
      birthDate: draft.birthDate,
      avatarMediaId: draft.avatarMediaId,
      note: draft.note,
      isFavorite: draft.isFavorite,
    );

    final index = _people.indexWhere((p) => p.id == id);
    if (index >= 0) {
      _people[index] = person;
    } else {
      _people.add(person);
    }

    _notify();
    return Ok(id);
  }

  @override
  Future<Result<Unit>> softDelete(String id) async {
    deleted.add(id);
    _people.removeWhere((p) => p.id == id);
    _notify();
    return const Ok(Unit.value);
  }

  @override
  Future<Result<Unit>> setFavorite(
    String id, {
    required bool isFavorite,
  }) async {
    final index = _people.indexWhere((p) => p.id == id);
    if (index >= 0) {
      _people[index] = _people[index].copyWith(isFavorite: isFavorite);
      _notify();
    }
    return const Ok(Unit.value);
  }

  Person? _find(String id) {
    for (final person in _people) {
      if (person.id == id) return person;
    }
    return null;
  }

  void _notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => _controller.close();
}
