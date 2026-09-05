/// Veritabanı satırı ↔ domain nesnesi çevirisi.
///
/// NEDEN AYRI KATMAN?
/// `MemoryRow` Drift'in ürettiği sınıftır; şema değişince o da değişir.
/// ViewModel'ler doğrudan `MemoryRow` kullansaydı, bir sütun adı
/// değiştirdiğinde 20 dosyayı düzeltmen gerekirdi. Mapper bu değişimi
/// tek noktada emer.
///
/// Ayrıca domain nesneleri veritabanının bilmediği şeyler taşır
/// (hesaplanmış `mediaCount`, birleştirilmiş `locationLabel` gibi).
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/collections/data/mappers/collection_mapper.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/data/daos/memory_dao.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';

abstract final class MemoryMapper {
  // --- Satır → Domain ------------------------------------------------------

  static Memory toDomain(MemoryListRow row) => Memory(
    id: row.memory.id,
    occurredAt: row.memory.occurredAt,
    title: row.memory.title,
    note: row.memory.note,
    categoryId: row.memory.categoryId,
    coverMedia: row.cover == null ? null : MediaMapper.toDomain(row.cover!),
    locationLabel: row.location?.label,
    isFavorite: row.memory.isFavorite,
    isArchived: row.memory.isArchived,
    mediaCount: row.mediaCount,
    personCount: row.personCount,
  );

  static MemoryDetail toDetailDomain(MemoryDetailRow row) => MemoryDetail(
    memory: Memory(
      id: row.memory.id,
      occurredAt: row.memory.occurredAt,
      title: row.memory.title,
      note: row.memory.note,
      categoryId: row.memory.categoryId,
      coverMedia: _findCover(row),
      locationLabel: row.location?.label,
      isFavorite: row.memory.isFavorite,
      isArchived: row.memory.isArchived,
      mediaCount: row.media.length,
      personCount: row.people.length,
    ),
    people: row.people.map(PersonMapper.toDomain).toList(),
    collections: row.collections.map(CollectionMapper.toDomain).toList(),
    media: row.media.map(MediaMapper.toDomain).toList(),
    ritual: row.ritual == null ? null : RitualMapper.toDomain(row.ritual!),
    ritualYear: row.ritualYear,
    location: row.location == null
        ? null
        : LocationMapper.toDomain(row.location!),
  );

  static MediaItem? _findCover(MemoryDetailRow row) {
    final coverId = row.memory.coverMediaId;
    for (final m in row.media) {
      if (m.id == coverId) return MediaMapper.toDomain(m);
    }
    // Kapak seçilmemişse ilk medyayı kullan (FR-018 varsayılan davranış).
    return row.media.isEmpty ? null : MediaMapper.toDomain(row.media.first);
  }

  // --- Domain → Satır ------------------------------------------------------

  /// [MemoryDraft]'ı veritabanına yazılabilir Companion'a çevirir.
  ///
  /// [id] her zaman dolu gelir: yeni kayıtta repository yeni bir id üretir.
  /// [version] ise mevcut kaydın sürümüdür (yoksa 0).
  static MemoriesCompanion toCompanion(
    MemoryDraft draft, {
    required String id,
    required DateTime now,
    int currentVersion = 0,
  }) {
    return MemoriesCompanion(
      id: Value(id),
      title: Value(_nullIfBlank(draft.title)),
      note: Value(_nullIfBlank(draft.note)),
      occurredAt: Value(draft.occurredAt),
      // Yerel takvim parçaları — bkz. memory_tables.dart'taki gerekçe.
      occurredYear: Value(draft.occurredAt.year),
      occurredMonth: Value(draft.occurredAt.month),
      occurredDay: Value(draft.occurredAt.day),
      categoryId: Value(draft.categoryId),
      locationId: Value(draft.locationId),
      coverMediaId: Value(draft.coverMediaId ?? draft.mediaIds.firstOrNull),
      isFavorite: Value(draft.isFavorite),
      updatedAt: Value(now),
      // `createdAt` BİLEREK yazılmıyor (`Value.absent()` kalıyor):
      //   • ilk yazmada sütunun SQL varsayılanı (currentDateAndTime) devreye girer
      //   • güncellemede `insertOnConflictUpdate`ın SET listesine girmediği için
      //     mevcut değer olduğu gibi korunur
      // Buraya `Value(now)` yazarsan her düzenlemede "oluşturulma tarihi"
      // sıfırlanır. (Davranış test/unit/memory_repository_test.dart'ta doğrulanıyor.)
      version: Value(currentVersion + 1),
    );
  }

  /// Boş/whitespace metni null'a çevirir — veritabanında '' ve null
  /// karışımı sorgu yazarken baş ağrıtır.
  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

abstract final class MediaMapper {
  static MediaItem toDomain(MediaRow row) => MediaItem(
    id: row.id,
    type: row.type,
    galleryAssetId: row.galleryAssetId,
    localPreviewPath: row.localPreviewPath,
    cloudObjectKey: row.cloudObjectKey,
    originalStatus: row.originalStatus,
    mimeType: row.mimeType,
    width: row.width,
    height: row.height,
    durationMs: row.durationMs,
    sizeBytes: row.sizeBytes,
  );
}

abstract final class PersonMapper {
  static Person toDomain(PersonRow row) => Person(
    id: row.id,
    name: row.name,
    kind: row.kind,
    relationType: row.relationType,
    birthDate: row.birthDate,
    avatarMediaId: row.avatarMediaId,
    note: row.note,
    isFavorite: row.isFavorite,
  );
}

abstract final class RitualMapper {
  static Ritual toDomain(RitualRow row) => Ritual(
    id: row.id,
    title: row.title,
    recurrenceType: row.recurrenceType,
    relatedPersonId: row.relatedPersonId,
    anchorMonth: row.anchorMonth,
    anchorDay: row.anchorDay,
    iconKey: row.iconKey,
  );
}

abstract final class LocationMapper {
  static MemoryLocation toDomain(LocationRow row) => MemoryLocation(
    id: row.id,
    label: row.label,
    latitude: row.latitude,
    longitude: row.longitude,
    city: row.city,
    country: row.country,
  );
}
