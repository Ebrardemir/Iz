/// Anı — ürünün **temel nesnesi**.
///
/// Rapor 3.2 ilkesi: "Fotoğraf temel nesne değil; anı temel nesnedir.
/// Medya, anının bileşenidir."
///
/// ÜÇ FARKLI MODEL VAR, KARIŞTIRMA:
///
///   [Memory]       → liste/timeline kartı için HAFİF model.
///                    İlişkileri yüklemez, sadece sayılarını taşır.
///                    NFR-003: yüzlerce anıyı listelerken tüm medyayı
///                    belleğe almak performansı öldürür.
///
///   [MemoryDetail] → detay ekranı için TAM model. Kişiler, koleksiyonlar,
///                    ritüel, medya ve konum yüklü gelir.
///
///   [MemoryDraft]  → oluşturma/düzenleme formunun girdisi. Henüz
///                    kaydedilmemiş, id'si olmayabilir.
library;

import 'package:equatable/equatable.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';

/// Timeline/liste kartı modeli.
final class Memory extends Equatable {
  const Memory({
    required this.id,
    required this.occurredAt,
    required this.isFavorite,
    required this.mediaCount,
    required this.personCount,
    this.title,
    this.note,
    this.categoryId,
    this.coverMedia,
    this.locationLabel,
    this.isArchived = false,
  });

  final String id;

  /// FR-013: geçmiş bir tarih olabilir — eski anılar sonradan eklenebilir.
  /// Sıralama `createdAt`e göre DEĞİL, buna göre yapılır.
  final DateTime occurredAt;

  final String? title;
  final String? note;
  final String? categoryId;

  /// FR-018 — kapak görseli. Kart için tek medya yeterli.
  final MediaItem? coverMedia;

  final String? locationLabel;
  final bool isFavorite; // FR-019
  final bool isArchived; // FR-014

  final int mediaCount;
  final int personCount;

  /// FR-012 kontrolü: en az metin veya bir medya olmalı.
  bool get hasContent =>
      (title?.trim().isNotEmpty ?? false) ||
      (note?.trim().isNotEmpty ?? false) ||
      mediaCount > 0;

  /// Kartta gösterilecek başlık; başlık yoksa notun ilk satırı.
  String displayTitle(String fallback) {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;

    final n = note?.trim();
    if (n != null && n.isNotEmpty) {
      final firstLine = n.split('\n').first;
      return firstLine.length <= 60
          ? firstLine
          : '${firstLine.substring(0, 57)}...';
    }
    return fallback;
  }

  Memory copyWith({
    DateTime? occurredAt,
    String? title,
    String? note,
    String? categoryId,
    MediaItem? coverMedia,
    String? locationLabel,
    bool? isFavorite,
    bool? isArchived,
    int? mediaCount,
    int? personCount,
  }) => Memory(
    id: id,
    occurredAt: occurredAt ?? this.occurredAt,
    title: title ?? this.title,
    note: note ?? this.note,
    categoryId: categoryId ?? this.categoryId,
    coverMedia: coverMedia ?? this.coverMedia,
    locationLabel: locationLabel ?? this.locationLabel,
    isFavorite: isFavorite ?? this.isFavorite,
    isArchived: isArchived ?? this.isArchived,
    mediaCount: mediaCount ?? this.mediaCount,
    personCount: personCount ?? this.personCount,
  );

  @override
  List<Object?> get props => [
    id,
    occurredAt,
    title,
    note,
    categoryId,
    coverMedia,
    locationLabel,
    isFavorite,
    isArchived,
    mediaCount,
    personCount,
  ];
}

/// Detay ekranı modeli — tüm ilişkiler yüklü.
///
/// FR-020: "Anı detay ekranında ilgili kişi, koleksiyon, ritüel ve konuma
/// geçiş bağlantıları bulunmalıdır." Bu model o bağlantıları besler.
final class MemoryDetail extends Equatable {
  const MemoryDetail({
    required this.memory,
    required this.people,
    required this.collections,
    required this.media,
    this.ritual,
    this.ritualYear,
    this.location,
  });

  final Memory memory;

  /// FR-016 — bir anı birden fazla kişiyle ilişkilendirilebilir.
  /// BR-001: anı kopyalanmaz, aynı anı her kişide görünür.
  final List<Person> people;

  /// FR-074 — bir anı birden fazla koleksiyona bağlanabilir.
  final List<MemoryCollection> collections;

  /// Sıralı medya listesi (MemoryMedia.sortOrder).
  final List<MediaItem> media;

  /// FR-017 — isteğe bağlı TEK ritüel.
  final Ritual? ritual;

  /// BR-012 — ritüelin hangi yılki tekrarı.
  final int? ritualYear;

  final MemoryLocation? location;

  String get id => memory.id;

  /// BR-007 — kaç medyanın orijinali kayıp? Detayda uyarı göstermek için.
  int get missingMediaCount => media.where((m) => m.isMissing).length;

  /// FR-045 / BR-008 — baskı siparişi öncesi kontrol.
  bool get isPrintReady =>
      media.isNotEmpty && media.every((m) => m.isPrintable);

  @override
  List<Object?> get props => [
    memory,
    people,
    collections,
    media,
    ritual,
    ritualYear,
    location,
  ];
}

/// Konum metadata'sı (rapor 12: Location).
///
/// Rapor 20.1: konum "opsiyonel; kullanıcı kaldırabilmeli" sınıfında.
final class MemoryLocation extends Equatable {
  const MemoryLocation({
    required this.id,
    required this.label,
    this.latitude,
    this.longitude,
    this.city,
    this.country,
  });

  final String id;
  final String label;
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? country;

  /// FR-093 harita kümelemesi için koordinat gerekli.
  bool get hasCoordinates => latitude != null && longitude != null;

  @override
  List<Object?> get props => [id, label, latitude, longitude, city, country];
}

/// Anı oluşturma/düzenleme girdisi.
///
/// Entity'den ayrı olmasının sebebi: form doldurulurken model geçersiz
/// durumda olabilir (başlık yok, medya yok). [Memory] ise her zaman
/// geçerli/kaydedilmiş bir kaydı temsil eder.
final class MemoryDraft extends Equatable {
  const MemoryDraft({
    required this.occurredAt,
    this.id,
    this.title,
    this.note,
    this.categoryId,
    this.personIds = const [],
    this.collectionIds = const [],
    this.mediaIds = const [],
    this.coverMediaId,
    this.ritualId,
    this.ritualYear,
    this.locationId,
    this.isFavorite = false,
  });

  /// Yeni anı için null; düzenlemede dolu.
  final String? id;

  final DateTime occurredAt;
  final String? title;
  final String? note;
  final String? categoryId;
  final List<String> personIds;
  final List<String> collectionIds;
  final List<String> mediaIds;
  final String? coverMediaId;
  final String? ritualId;
  final int? ritualYear;
  final String? locationId;
  final bool isFavorite;

  bool get isNew => id == null;

  /// FR-012: "Bir Anı en az metin veya en az bir medya öğesi içerebilmelidir;
  /// tamamen boş kayıt kaydedilmemelidir."
  bool get hasContent =>
      (title?.trim().isNotEmpty ?? false) ||
      (note?.trim().isNotEmpty ?? false) ||
      mediaIds.isNotEmpty;

  MemoryDraft copyWith({
    String? id,
    DateTime? occurredAt,
    String? title,
    String? note,
    String? categoryId,
    List<String>? personIds,
    List<String>? collectionIds,
    List<String>? mediaIds,
    String? coverMediaId,
    String? ritualId,
    int? ritualYear,
    String? locationId,
    bool? isFavorite,
  }) => MemoryDraft(
    id: id ?? this.id,
    occurredAt: occurredAt ?? this.occurredAt,
    title: title ?? this.title,
    note: note ?? this.note,
    categoryId: categoryId ?? this.categoryId,
    personIds: personIds ?? this.personIds,
    collectionIds: collectionIds ?? this.collectionIds,
    mediaIds: mediaIds ?? this.mediaIds,
    coverMediaId: coverMediaId ?? this.coverMediaId,
    ritualId: ritualId ?? this.ritualId,
    ritualYear: ritualYear ?? this.ritualYear,
    locationId: locationId ?? this.locationId,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  @override
  List<Object?> get props => [
    id,
    occurredAt,
    title,
    note,
    categoryId,
    personIds,
    collectionIds,
    mediaIds,
    coverMediaId,
    ritualId,
    ritualYear,
    locationId,
    isFavorite,
  ];
}
