/// Bellekte çalışan sahte günlük deposu.
///
/// NEDEN GERÇEK DEPO DEĞİL?
/// Gerekçesi `fake_collection_repository.dart` başındaki notta: widget
/// testinde gerçek Drift bekleyen timer bırakır. SQL'in doğruluğu
/// `test/unit/journal_repository_test.dart`ta gerçek SQLite ile zaten test
/// ediliyor; widget testinin işi ekranın davranışı.
library;

import 'dart:async';

import 'package:iz/core/result/result.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/journal/domain/repositories/journal_repository.dart';

class FakeJournalRepository implements JournalRepository {
  FakeJournalRepository([List<JournalEntry>? initial])
    : _entries = [...?initial];

  final List<JournalEntry> _entries;
  final _controller = StreamController<void>.broadcast();

  /// Testlerin doğrulayabilmesi için.
  final List<JournalDraft> saved = [];
  final List<String> deleted = [];

  int _idCounter = 0;

  List<JournalEntry> get entries => List.unmodifiable(_entries);

  @override
  Stream<Result<List<JournalEntry>>> watchEntries() async* {
    yield Ok(_sorted());
    yield* _controller.stream.map((_) => Ok(_sorted()));
  }

  @override
  Stream<Result<JournalEntry?>> watchEntry(String id) async* {
    yield Ok(_find(id));
    yield* _controller.stream.map((_) => Ok(_find(id)));
  }

  @override
  Future<Result<JournalEntry?>> findEntry(String id) async => Ok(_find(id));

  @override
  Stream<Result<int>> watchCount() async* {
    yield Ok(_entries.length);
    yield* _controller.stream.map((_) => Ok(_entries.length));
  }

  @override
  Future<Result<String>> save(JournalDraft draft) async {
    saved.add(draft);
    final id = draft.id ?? 'sahte-gunluk-${++_idCounter}';

    final entry = JournalEntry(
      id: id,
      entryDate: draft.entryDate,
      text: draft.text,
      title: draft.title,
      moodScore: draft.moodScore,
      moodKey: draft.moodKey,
      promptId: draft.promptId,
      privacyMode: draft.privacyMode,
      isFavorite: draft.isFavorite,
      mediaIds: draft.mediaIds ?? const [],
    );

    final index = _entries.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _entries[index] = entry;
    } else {
      _entries.add(entry);
    }

    _notify();
    return Ok(id);
  }

  @override
  Future<Result<Unit>> setFavorite(
    String id, {
    required bool isFavorite,
  }) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _entries[index] = _entries[index].copyWith(isFavorite: isFavorite);
      _notify();
    }
    return const Ok(Unit.value);
  }

  @override
  Future<Result<Unit>> softDelete(String id) async {
    deleted.add(id);
    _entries.removeWhere((e) => e.id == id);
    _notify();
    return const Ok(Unit.value);
  }

  /// EN YENİ GÜN ÜSTTE — gerçeğindeki sıralamanın aynısı.
  List<JournalEntry> _sorted() {
    final sorted = [..._entries]
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
    return List.unmodifiable(sorted);
  }

  JournalEntry? _find(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  void _notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => _controller.close();
}
