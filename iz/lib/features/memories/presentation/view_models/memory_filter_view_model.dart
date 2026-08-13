/// Aktif filtreyi tutan ViewModel.
///
/// NEDEN AYRI BİR ViewModel?
/// Filtre birden fazla ekranı besliyor: timeline, arama, kişi yaşam çizgisi.
/// Ayrı tutunca liste ViewModel'i "filtreyi kim değiştirdi" diye
/// ilgilenmez — sadece `ref.watch(memoryFilterProvider)` der ve Riverpod
/// filtre değişince listeyi otomatik yeniden kurar.
///
/// Bu, MVVM'de "ViewModel'ler birbirini çağırmaz, ortak state'i gözler"
/// ilkesinin uygulanışıdır.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';

class MemoryFilterViewModel extends Notifier<MemoryFilter> {
  @override
  MemoryFilter build() => MemoryFilter.all;

  /// Arama kutusundan gelir. 2 karakterden kısa sorgular yok sayılır
  /// (FTS5'e her harfte gitmenin anlamı yok).
  void setQuery(String? query) {
    final trimmed = query?.trim();
    state = (trimmed == null || trimmed.isEmpty)
        ? state.cleared(query: true)
        : state.copyWith(query: trimmed);
  }

  void togglePerson(String personId) {
    final next = {...state.personIds};
    if (!next.remove(personId)) next.add(personId);
    state = state.copyWith(personIds: next);
  }

  void toggleCollection(String collectionId) {
    final next = {...state.collectionIds};
    if (!next.remove(collectionId)) next.add(collectionId);
    state = state.copyWith(collectionIds: next);
  }

  void toggleCategory(String categoryId) {
    final next = {...state.categoryIds};
    if (!next.remove(categoryId)) next.add(categoryId);
    state = state.copyWith(categoryIds: next);
  }

  void setRitual(String? ritualId) {
    state = ritualId == null
        ? state.cleared(ritual: true)
        : state.copyWith(ritualId: ritualId);
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = (from == null && to == null)
        ? state.cleared(dateRange: true)
        : state.copyWith(from: from, to: to);
  }

  void toggleFavoritesOnly() {
    state = state.copyWith(onlyFavorites: !state.onlyFavorites);
  }

  void setSortOrder(MemorySortOrder order) {
    state = state.copyWith(sortOrder: order);
  }

  void clearAll() {
    state = MemoryFilter.all;
  }
}

final memoryFilterProvider =
    NotifierProvider<MemoryFilterViewModel, MemoryFilter>(
      MemoryFilterViewModel.new,
    );
