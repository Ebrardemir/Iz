/// Bellekte çalışan sahte koleksiyon deposu.
///
/// NEDEN GERÇEK VERİTABANI DEĞİL?
/// Gerekçesi `fake_person_repository.dart` başındaki notta: widget testinde
/// gerçek Drift bekleyen timer bırakır. SQL'in doğruluğu
/// `test/unit/collection_repository_test.dart`ta gerçek SQLite ile ayrıca
/// test ediliyor; widget testinin işi ekranın davranışı.
library;

import 'dart:async';

import 'package:iz/core/result/result.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/collections/domain/repositories/collection_repository.dart';

class FakeCollectionRepository implements CollectionRepository {
  FakeCollectionRepository([List<MemoryCollection>? initial])
    : _collections = [...?initial];

  final List<MemoryCollection> _collections;
  final _controller = StreamController<void>.broadcast();

  /// Testlerin doğrulayabilmesi için.
  final List<CollectionDraft> saved = [];
  final List<String> deleted = [];

  /// Koleksiyon kimliği → anı kimlikleri.
  final Map<String, List<String>> links = {};

  int _idCounter = 0;

  List<MemoryCollection> get collections => List.unmodifiable(_collections);

  @override
  Stream<Result<List<MemoryCollection>>> watchCollections() async* {
    yield Ok(List.unmodifiable(_collections));
    yield* _controller.stream.map((_) => Ok(List.unmodifiable(_collections)));
  }

  @override
  Stream<Result<MemoryCollection?>> watchCollection(String id) async* {
    yield Ok(_find(id));
    yield* _controller.stream.map((_) => Ok(_find(id)));
  }

  @override
  Future<Result<MemoryCollection?>> findCollection(String id) async =>
      Ok(_find(id));

  @override
  Stream<Result<Map<String, List<String>>>> watchMemoryLinks() async* {
    yield Ok(Map.unmodifiable(links));
    yield* _controller.stream.map((_) => Ok(Map.unmodifiable(links)));
  }

  @override
  Future<Result<String>> save(CollectionDraft draft) async {
    saved.add(draft);
    final id = draft.id ?? 'sahte-koleksiyon-${++_idCounter}';

    final collection = MemoryCollection(
      id: id,
      title: draft.title,
      description: draft.description,
      coverMediaId: draft.coverMediaId,
      visibility: draft.visibility,
      startDate: draft.startDate,
      endDate: draft.endDate,
    );

    final index = _collections.indexWhere((c) => c.id == id);
    if (index >= 0) {
      _collections[index] = collection;
    } else {
      _collections.add(collection);
    }

    // `null` = "bağlara dokunma" — gerçeğindeki ayrımın aynısı.
    if (draft.memoryIds case final ids?) {
      links[id] = [...ids];
    }

    _notify();
    return Ok(id);
  }

  @override
  Future<Result<Unit>> softDelete(String id) async {
    deleted.add(id);
    _collections.removeWhere((c) => c.id == id);
    _notify();
    return const Ok(Unit.value);
  }

  MemoryCollection? _find(String id) {
    for (final collection in _collections) {
      if (collection.id == id) return collection;
    }
    return null;
  }

  void _notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => _controller.close();
}
