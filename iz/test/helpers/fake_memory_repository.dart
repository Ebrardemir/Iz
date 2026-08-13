/// Bellekte çalışan sahte anı deposu.
///
/// NEDEN GERÇEK VERİTABANI DEĞİL?
/// Widget testlerinde gerçek Drift kullanmak bekleyen timer'lar bırakır ve
/// `!timersPending` hatası verir. Ayrıca her test bir şeyi doğrulamalı:
/// SQL'in doğruluğu `test/unit/memory_repository_test.dart`ta gerçek
/// SQLite ile zaten test ediliyor. Widget testinin işi navigasyon,
/// bağımlılık kurulumu ve ekran davranışı.
library;

import 'dart:async';

import 'package:iz/core/result/result.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';
import 'package:iz/features/memories/domain/repositories/memory_repository.dart';

class FakeMemoryRepository implements MemoryRepository {
  FakeMemoryRepository([List<Memory>? initial]) : _memories = [...?initial];

  final List<Memory> _memories;
  final List<MemoryFilter> receivedFilters = [];
  int _idCounter = 0;

  /// Hazır `MemoryDetail` kayıtları.
  ///
  /// NEDEN GEREKLİ? Sahte depo, ilişkileri (kişi, koleksiyon, ritüel, medya)
  /// TUTMUYOR — `Memory` listesinden türetilen detay hep boş gelir. Anı detay
  /// ekranının tasarımı ise tam olarak o ilişkileri gösteriyor. Buraya
  /// konulan kayıt, türetilenin yerine geçiyor.
  final Map<String, MemoryDetail> details = {};

  /// Tek kayıtlı testler için kısayol: `repository.detail = …`.
  set detail(MemoryDetail value) => details[value.id] = value;

  /// Liste değişimlerini abonelere bildirmek için.
  final _controller = StreamController<void>.broadcast();

  List<Memory> get memories => List.unmodifiable(_memories);

  void dispose() => _controller.close();

  List<Memory> _apply(MemoryFilter filter) {
    var result = _memories.where((m) => !m.isArchived).toList();

    if (filter.onlyFavorites) {
      result = result.where((m) => m.isFavorite).toList();
    }
    if (filter.personIds.isNotEmpty) {
      // Sahte kayıtlarda kişi ilişkisi tutmuyoruz; filtre uygulanınca boş döner.
      result = const [];
    }
    if (filter.hasTextQuery) {
      final q = filter.query!.toLowerCase();
      result = result
          .where(
            (m) =>
                (m.title ?? '').toLowerCase().contains(q) ||
                (m.note ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    return result;
  }

  @override
  Stream<Result<List<Memory>>> watchMemories(MemoryFilter filter) async* {
    receivedFilters.add(filter);

    // İlk değeri hemen ver, sonra her değişimde yeniden yayınla —
    // gerçek Drift `watch()` davranışını taklit ediyoruz.
    yield Ok(_apply(filter));
    await for (final _ in _controller.stream) {
      yield Ok(_apply(filter));
    }
  }

  @override
  Stream<Result<MemoryDetail?>> watchDetail(String id) async* {
    // İlk değer + her değişimde yenisi. `Stream.value` KULLANMIYORUZ:
    // favoriye basıldığında ekranın güncellendiğini görebilmek için akışın
    // ikinci bir olay yayması gerekiyor (gerçek Drift `watch()` de öyle).
    yield Ok(_detailOf(id));
    await for (final _ in _controller.stream) {
      yield Ok(_detailOf(id));
    }
  }

  @override
  Future<Result<MemoryDetail?>> findDetail(String id) async =>
      Ok(_detailOf(id));

  MemoryDetail? _detailOf(String id) {
    final memory = _memories.where((m) => m.id == id).firstOrNull;

    // Hazır kayıt varsa o kazanıyor — ama `memory` alanı listeden geliyor.
    // Böylece favori/arşiv gibi değişiklikler hazır kayıtta da görünüyor;
    // yoksa kalbe basmak hiçbir şeyi değiştirmezdi.
    final prepared = details[id];
    if (prepared != null) {
      if (memory == null) return prepared;
      return MemoryDetail(
        memory: memory,
        people: prepared.people,
        collections: prepared.collections,
        media: prepared.media,
        ritual: prepared.ritual,
        ritualYear: prepared.ritualYear,
        location: prepared.location,
      );
    }

    if (memory == null) return null;
    return MemoryDetail(
      memory: memory,
      people: const [],
      collections: const [],
      media: const [],
    );
  }

  @override
  Future<Result<String>> saveDraft(MemoryDraft draft) async {
    final id = draft.id ?? 'fake-${++_idCounter}';

    final memory = Memory(
      id: id,
      occurredAt: draft.occurredAt,
      title: draft.title,
      note: draft.note,
      categoryId: draft.categoryId,
      isFavorite: draft.isFavorite,
      mediaCount: draft.mediaIds.length,
      personCount: draft.personIds.length,
    );

    final index = _memories.indexWhere((m) => m.id == id);
    if (index >= 0) {
      _memories[index] = memory;
    } else {
      _memories.add(memory);
    }
    _notify();
    return Ok(id);
  }

  @override
  Future<Result<Unit>> setFavorite(
    String id, {
    required bool isFavorite,
  }) async {
    _replace(id, (m) => m.copyWith(isFavorite: isFavorite));
    _notify();
    return okUnit;
  }

  @override
  Future<Result<Unit>> setArchived(
    String id, {
    required bool isArchived,
  }) async {
    _replace(id, (m) => m.copyWith(isArchived: isArchived));
    return okUnit;
  }

  @override
  Future<Result<Unit>> moveToTrash(String id) async {
    _memories.removeWhere((m) => m.id == id);
    _notify();
    return okUnit;
  }

  @override
  Future<Result<Unit>> restoreFromTrash(String id) async => okUnit;

  @override
  Future<Result<int>> purgeExpiredTrash() async => const Ok(0);

  @override
  Future<Result<List<Memory>>> findOnThisDay(DateTime day) async => Ok(
    _memories
        .where(
          (m) =>
              m.occurredAt.month == day.month &&
              m.occurredAt.day == day.day &&
              m.occurredAt.year < day.year,
        )
        .toList(),
  );

  @override
  Future<Result<int>> countAll() async => Ok(_memories.length);

  void _replace(String id, Memory Function(Memory memory) transform) {
    final index = _memories.indexWhere((m) => m.id == id);
    if (index >= 0) {
      _memories[index] = transform(_memories[index]);
      _notify();
    }
  }

  void _notify() {
    if (!_controller.isClosed) _controller.add(null);
  }
}

/// Test verisi üretmek için kısayol.
Memory buildTestMemory({
  required String id,
  String? title,
  String? note,
  DateTime? occurredAt,
  bool isFavorite = false,
  int mediaCount = 0,
  int personCount = 0,
}) => Memory(
  id: id,
  occurredAt: occurredAt ?? DateTime(2026, 3, 12),
  title: title,
  note: note,
  isFavorite: isFavorite,
  mediaCount: mediaCount,
  personCount: personCount,
);
