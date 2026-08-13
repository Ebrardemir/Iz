/// Koleksiyon — belirli bir olay/dönem/grup ("Kapadokya 2026").
///
/// FR-078 / BR-002: Koleksiyon **paylaşımın temel birimidir**. Kullanıcının
/// tüm kategorisine veya arşivine erişim asla verilmez. Bu yüzden görünürlük
/// (visibility) kategoride değil, koleksiyonda tutulur.
library;

import 'package:equatable/equatable.dart';

enum CollectionVisibility {
  /// BR-003 — varsayılan. Yalnızca sahibi görür.
  private,

  /// V2 — davetlilerle paylaşılmış ortak koleksiyon (FR-110).
  shared,
}

final class MemoryCollection extends Equatable {
  const MemoryCollection({
    required this.id,
    required this.title,
    required this.visibility,
    this.description,
    this.coverMediaId,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String title;
  final String? description;
  final String? coverMediaId;
  final CollectionVisibility visibility;

  /// Seyahat/dönem koleksiyonları için opsiyonel tarih aralığı —
  /// haritada ve otomatik kitap taslağında kullanılır.
  final DateTime? startDate;
  final DateTime? endDate;

  bool get isShared => visibility == CollectionVisibility.shared;

  MemoryCollection copyWith({
    String? title,
    String? description,
    String? coverMediaId,
    CollectionVisibility? visibility,
    DateTime? startDate,
    DateTime? endDate,
  }) => MemoryCollection(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    coverMediaId: coverMediaId ?? this.coverMediaId,
    visibility: visibility ?? this.visibility,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    coverMediaId,
    visibility,
    startDate,
    endDate,
  ];
}
