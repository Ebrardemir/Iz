/// ViewModel testi — Riverpod'u `ProviderContainer` ile test etme örneği.
///
/// ANAHTAR TEKNİK: `overrides` ile gerçek repository'yi sahte olanla
/// değiştiriyoruz. ViewModel'in kodunda hiçbir değişiklik yok — çünkü
/// bağımlılığı provider üzerinden alıyor. Bağımlılık enjeksiyonunun
/// getirisi tam olarak budur.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';
import 'package:iz/features/memories/domain/repositories/memory_repository.dart';
import 'package:iz/features/memories/presentation/view_models/memory_filter_view_model.dart';
import 'package:iz/features/memories/presentation/view_models/memory_list_view_model.dart';

/// Elle yazılmış sahte repository.
///
/// mocktail yerine elle yazmak burada daha okunaklı: hangi filtrenin
/// geldiğini yakalayıp doğrulayabiliyoruz.
class _FakeMemoryRepository implements MemoryRepository {
  _FakeMemoryRepository(this.memories);

  final List<Memory> memories;
  final List<MemoryFilter> receivedFilters = [];

  @override
  Stream<Result<List<Memory>>> watchMemories(MemoryFilter filter) {
    receivedFilters.add(filter);

    var result = memories;
    if (filter.onlyFavorites) {
      result = result.where((m) => m.isFavorite).toList();
    }
    if (filter.hasTextQuery) {
      final q = filter.query!.toLowerCase();
      result = result
          .where((m) => (m.title ?? '').toLowerCase().contains(q))
          .toList();
    }
    return Stream.value(Ok(result));
  }

  // --- Testte kullanılmayan üyeler ---------------------------------------
  @override
  Stream<Result<MemoryDetail?>> watchDetail(String id) => const Stream.empty();

  @override
  Future<Result<MemoryDetail?>> findDetail(String id) async => const Ok(null);

  @override
  Future<Result<String>> saveDraft(MemoryDraft draft) async => const Ok('id');

  @override
  Future<Result<Unit>> setFavorite(
    String id, {
    required bool isFavorite,
  }) async => okUnit;

  @override
  Future<Result<Unit>> setArchived(
    String id, {
    required bool isArchived,
  }) async => okUnit;

  @override
  Future<Result<Unit>> moveToTrash(String id) async => okUnit;

  @override
  Future<Result<Unit>> restoreFromTrash(String id) async => okUnit;

  @override
  Future<Result<int>> purgeExpiredTrash() async => const Ok(0);

  @override
  Future<Result<List<Memory>>> findOnThisDay(DateTime day) async =>
      const Ok([]);

  @override
  Future<Result<int>> countAll() async => Ok(memories.length);
}

/// Hata döndüren sahte — hata yolunu test etmek için.
class _FailingRepository extends _FakeMemoryRepository {
  _FailingRepository() : super(const []);

  @override
  Stream<Result<List<Memory>>> watchMemories(MemoryFilter filter) =>
      Stream.value(const Err(DatabaseFailure()));
}

Memory buildMemory({
  required String id,
  String? title,
  bool isFavorite = false,
}) => Memory(
  id: id,
  occurredAt: DateTime(2026, 3, 12),
  title: title,
  isFavorite: isFavorite,
  mediaCount: 0,
  personCount: 0,
);

void main() {
  ProviderContainer makeContainer(MemoryRepository repository) {
    final container = ProviderContainer(
      overrides: [memoryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// ÖNEMLİ RIVERPOD DETAYI:
  /// `container.read(provider.future)` tek başına provider'a ABONE OLMAZ.
  /// Abone yoksa provider ilk değerini yayınlamadan atılabilir ve
  /// "disposed during loading state" hatası alırsın.
  /// Testlerde bu yüzden önce `listen` ile canlı tutuyoruz.
  void keepAlive(ProviderContainer container) {
    final subscription = container.listen(
      memoryListProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
  }

  test('anıları yükler ve AsyncData olarak yayınlar', () async {
    final container = makeContainer(
      _FakeMemoryRepository([
        buildMemory(id: '1', title: 'Kapadokya'),
        buildMemory(id: '2', title: 'İzmir'),
      ]),
    );
    keepAlive(container);

    final memories = await container.read(memoryListProvider.future);

    expect(memories, hasLength(2));
  });

  test('filtre değişince liste yeniden sorgulanır', () async {
    final repository = _FakeMemoryRepository([
      buildMemory(id: '1', title: 'Kapadokya', isFavorite: true),
      buildMemory(id: '2', title: 'İzmir'),
    ]);
    final container = makeContainer(repository);

    // Provider'ı canlı tut, yoksa autoDispose olmasa da ilk okumadan
    // sonra yeniden hesaplanmaz.
    final subscription = container.listen(
      memoryListProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(await container.read(memoryListProvider.future), hasLength(2));

    // Favori filtresini aç.
    container.read(memoryFilterProvider.notifier).toggleFavoritesOnly();

    expect(await container.read(memoryListProvider.future), hasLength(1));

    // ViewModel gerçekten güncel filtreyi iletmiş olmalı.
    expect(repository.receivedFilters.last.onlyFavorites, isTrue);
  });

  test('arama sorgusu ViewModel üzerinden repository\'ye ulaşır', () async {
    final repository = _FakeMemoryRepository([
      buildMemory(id: '1', title: 'Kapadokya balon'),
      buildMemory(id: '2', title: 'İzmir sahil'),
    ]);
    final container = makeContainer(repository);

    final subscription = container.listen(
      memoryListProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    container.read(memoryFilterProvider.notifier).setQuery('kapadokya');

    final results = await container.read(memoryListProvider.future);
    expect(results, hasLength(1));
    expect(results.first.title, 'Kapadokya balon');
  });

  test('2 karakterden kısa sorgu arama sayılmaz', () {
    final container = makeContainer(_FakeMemoryRepository(const []));

    container.read(memoryFilterProvider.notifier).setQuery('k');

    expect(container.read(memoryFilterProvider).hasTextQuery, isFalse);
  });

  test('repository hata dönerse AsyncError olur ve Failure taşır', () async {
    final container = makeContainer(_FailingRepository());
    keepAlive(container);

    // Stream hatası bir mikrotask sonra ulaşır.
    await Future<void>.delayed(Duration.zero);

    final state = container.read(memoryListProvider);

    expect(state.hasError, isTrue);
    // Ham exception değil, domain'in Failure tipi taşınmalı —
    // UI bu sayede doğru mesajı ve "tekrar dene" butonunu seçebiliyor.
    expect(state.error, isA<DatabaseFailure>());
  });

  test('clearAll tüm filtreleri sıfırlar', () {
    final container = makeContainer(_FakeMemoryRepository(const []));
    final notifier = container.read(memoryFilterProvider.notifier)
      ..toggleFavoritesOnly()
      ..togglePerson('p1')
      ..setQuery('test');

    expect(container.read(memoryFilterProvider).activeFilterCount, 3);

    notifier.clearAll();

    expect(container.read(memoryFilterProvider).isEmpty, isTrue);
  });
}
