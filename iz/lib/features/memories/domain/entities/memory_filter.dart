/// FR-091: "Arama sonuçları kişi, kategori, koleksiyon, ritüel ve tarih
/// aralığına göre filtrelenebilmelidir."
///
/// Filtre bir DEĞER nesnesidir: ViewModel'de tutulur, DAO'ya geçirilir,
/// URL'e serileştirilebilir. Değişmez olması sayesinde Riverpod
/// gereksiz yeniden sorgu çalıştırmaz (aynı filtre == aynı sonuç).
library;

import 'package:equatable/equatable.dart';

enum MemorySortOrder {
  /// Timeline varsayılanı: en yeni YAŞANAN anı üstte.
  occurredAtDesc,

  /// En eski yaşanan anı üstte — ritüelin yıllarını sırayla karşılaştırmak
  /// için (FR-076; bkz. MemoryDao.watchByRitual).
  occurredAtAsc,

  /// Anının yaşandığı tarihe değil, KAYDEDİLDİĞİ tarihe göre sıralar
  /// (`createdAt`). "Son eklediklerim" görünümü için: kullanıcı 1998'e ait
  /// bir fotoğrafı bugün eklediyse onu listenin başında görmek ister.
  recentlyAdded,
}

final class MemoryFilter extends Equatable {
  const MemoryFilter({
    this.query,
    this.personIds = const {},
    this.collectionIds = const {},
    this.categoryIds = const {},
    this.ritualId,
    this.from,
    this.to,
    this.onlyFavorites = false,
    this.includeArchived = false,
    this.sortOrder = MemorySortOrder.occurredAtDesc,
    this.limit,
  });

  /// Boş filtre — "hepsini göster".
  static const MemoryFilter all = MemoryFilter();

  /// Serbest metin (FTS5'e gider).
  final String? query;

  final Set<String> personIds;
  final Set<String> collectionIds;
  final Set<String> categoryIds;
  final String? ritualId;

  final DateTime? from;
  final DateTime? to;

  final bool onlyFavorites;
  final bool includeArchived;
  final MemorySortOrder sortOrder;

  /// Ana ekrandaki "son anılar" bölümü gibi sınırlı listeler için.
  final int? limit;

  bool get hasTextQuery => (query?.trim().length ?? 0) >= 2;

  bool get isEmpty =>
      !hasTextQuery &&
      personIds.isEmpty &&
      collectionIds.isEmpty &&
      categoryIds.isEmpty &&
      ritualId == null &&
      from == null &&
      to == null &&
      !onlyFavorites;

  /// Kullanıcıya "3 filtre aktif" göstermek için.
  int get activeFilterCount => [
    if (hasTextQuery) 1,
    if (personIds.isNotEmpty) 1,
    if (collectionIds.isNotEmpty) 1,
    if (categoryIds.isNotEmpty) 1,
    if (ritualId != null) 1,
    if (from != null || to != null) 1,
    if (onlyFavorites) 1,
  ].length;

  MemoryFilter copyWith({
    String? query,
    Set<String>? personIds,
    Set<String>? collectionIds,
    Set<String>? categoryIds,
    String? ritualId,
    DateTime? from,
    DateTime? to,
    bool? onlyFavorites,
    bool? includeArchived,
    MemorySortOrder? sortOrder,
    int? limit,
  }) => MemoryFilter(
    query: query ?? this.query,
    personIds: personIds ?? this.personIds,
    collectionIds: collectionIds ?? this.collectionIds,
    categoryIds: categoryIds ?? this.categoryIds,
    ritualId: ritualId ?? this.ritualId,
    from: from ?? this.from,
    to: to ?? this.to,
    onlyFavorites: onlyFavorites ?? this.onlyFavorites,
    includeArchived: includeArchived ?? this.includeArchived,
    sortOrder: sortOrder ?? this.sortOrder,
    limit: limit ?? this.limit,
  );

  /// `copyWith` null geçerek alan temizleyemez; bunun için ayrı metot.
  MemoryFilter cleared({
    bool query = false,
    bool ritual = false,
    bool dateRange = false,
  }) => MemoryFilter(
    query: query ? null : this.query,
    personIds: personIds,
    collectionIds: collectionIds,
    categoryIds: categoryIds,
    ritualId: ritual ? null : ritualId,
    from: dateRange ? null : from,
    to: dateRange ? null : to,
    onlyFavorites: onlyFavorites,
    includeArchived: includeArchived,
    sortOrder: sortOrder,
    limit: limit,
  );

  @override
  List<Object?> get props => [
    query,
    personIds,
    collectionIds,
    categoryIds,
    ritualId,
    from,
    to,
    onlyFavorites,
    includeArchived,
    sortOrder,
    limit,
  ];
}
