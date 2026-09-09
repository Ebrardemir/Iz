/// Sunucudan inen değişikliği YEREL tablolara yazar.
///
/// SORUMLULUĞU: SQL. Sadece SQL — `memory_dao.dart` başındaki kuralın aynısı.
/// Hangi değişikliğin uygulanacağına, hangi sırayla ve ne zaman olacağına
/// motor karar veriyor.
///
/// ⚠️ BU DAO OUTBOX'A YAZMIYOR — ve bu, buradaki en önemli kural.
/// Öteki DAO'lar her yazmada kuyruğa bir satır düşürüyor (TR-M13-01). Burada
/// yazılan şey SUNUCUDAN GELİYOR; kuyruğa düşürseydik onu aynı sunucuya geri
/// gönderirdik. Sonuç sonsuz bir eko döngüsü ve her turda artan bir sürüm
/// olurdu.
///
/// NEDEN BAŞKA FEATURE'LARIN TABLOLARINA DOKUNUYOR?
/// Senkronizasyon on dört tablonun hepsini yazmak zorunda; tek tek her
/// feature'a "senkron yazma" metodu eklemek aynı kodu on dört yere dağıtmak
/// olurdu. Mimari bu geçişe izin veriyor: yasak olan `domain/` ve
/// `presentation/` katmanlarının başka feature'ın `data/`sine bakması
/// (ARCHITECTURE.md §2); `data/` → `data/` tablo referansı zaten
/// `memory_dao.dart`ta da var.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/categories/data/tables/category_tables.dart';
import 'package:iz/features/collections/data/tables/collection_tables.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/journal/data/tables/journal_tables.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/media/data/tables/media_tables.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/data/tables/memory_tables.dart';
import 'package:iz/features/people/data/tables/person_tables.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/rituals/data/tables/ritual_tables.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/features/sync/data/remote_row.dart';

part 'sync_dao.g.dart';

/// Bağların kimliği `"ustId:altId"` — kendi UUID'leri yok.
({String parent, String child})? parseLinkId(String entityId) {
  final ayirac = entityId.indexOf(':');
  if (ayirac <= 0 || ayirac == entityId.length - 1) return null;

  return (
    parent: entityId.substring(0, ayirac),
    child: entityId.substring(ayirac + 1),
  );
}

@DriftAccessor(
  tables: [
    Memories,
    Locations,
    MediaItems,
    Categories,
    Collections,
    Rituals,
    People,
    MemoryPeople,
    MemoryCollections,
    MemoryRituals,
    RitualPeople,
    MemoryMedia,
    JournalEntries,
    JournalMedia,
  ],
)
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  /// Sunucudan inen bir kaydı yazar ya da günceller.
  ///
  /// Tanımadığımız tür `false` döndürüyor — istisna DEĞİL. Sunucudan yeni bir
  /// tablo geldiğinde o satırı atlayıp devam etmek, bütün sayfayı
  /// uygulanamaz yapmaktan iyidir; cursor ilerlemezse kullanıcı bir daha
  /// asla eşitlenemez.
  Future<bool> applyUpsert({
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
    required String ownerId,
  }) async {
    final row = RemoteRow(payload);
    final link = parseLinkId(entityId);

    switch (entityType) {
      case 'memory':
        await into(
          memories,
        ).insertOnConflictUpdate(_memory(entityId, row, ownerId));
      case 'location':
        await into(locations).insertOnConflictUpdate(_location(entityId, row));
      case 'media_item':
        await into(mediaItems).insertOnConflictUpdate(_media(entityId, row));
      case 'category':
        await into(
          categories,
        ).insertOnConflictUpdate(_category(entityId, row, ownerId));
      case 'collection':
        await into(
          collections,
        ).insertOnConflictUpdate(_collection(entityId, row, ownerId));
      case 'ritual':
        await into(
          rituals,
        ).insertOnConflictUpdate(_ritual(entityId, row, ownerId));
      case 'person':
        await into(
          people,
        ).insertOnConflictUpdate(_person(entityId, row, ownerId));
      case 'journal_entry':
        await into(
          journalEntries,
        ).insertOnConflictUpdate(_journal(entityId, row, ownerId));

      case 'memory_people' when link != null:
        await into(memoryPeople).insertOnConflictUpdate(
          MemoryPeopleCompanion.insert(
            memoryId: link.parent,
            personId: link.child,
            role: Value(row.text('role')),
            updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
            deletedAt: Value(row.dateTime('deleted_at')),
            version: Value(row.integerOr('version', 1)),
          ),
        );
      case 'memory_collections' when link != null:
        await into(memoryCollections).insertOnConflictUpdate(
          MemoryCollectionsCompanion.insert(
            memoryId: link.parent,
            collectionId: link.child,
            sortOrder: Value(row.integerOr('sort_order', 0)),
            updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
            deletedAt: Value(row.dateTime('deleted_at')),
            version: Value(row.integerOr('version', 1)),
          ),
        );
      case 'memory_rituals' when link != null:
        await into(memoryRituals).insertOnConflictUpdate(
          MemoryRitualsCompanion.insert(
            memoryId: link.parent,
            ritualId: link.child,
            occurrenceYear: row.integerOr('occurrence_year', 0),
            updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
            deletedAt: Value(row.dateTime('deleted_at')),
            version: Value(row.integerOr('version', 1)),
          ),
        );
      case 'ritual_people' when link != null:
        await into(ritualPeople).insertOnConflictUpdate(
          RitualPeopleCompanion.insert(
            ritualId: link.parent,
            personId: link.child,
            updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
            deletedAt: Value(row.dateTime('deleted_at')),
            version: Value(row.integerOr('version', 1)),
          ),
        );
      case 'memory_media' when link != null:
        await into(memoryMedia).insertOnConflictUpdate(
          MemoryMediaCompanion.insert(
            memoryId: link.parent,
            mediaId: link.child,
            sortOrder: Value(row.integerOr('sort_order', 0)),
            updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
            deletedAt: Value(row.dateTime('deleted_at')),
            version: Value(row.integerOr('version', 1)),
          ),
        );
      case 'journal_media' when link != null:
        await into(journalMedia).insertOnConflictUpdate(
          JournalMediaCompanion.insert(
            journalEntryId: link.parent,
            mediaId: link.child,
            sortOrder: Value(row.integerOr('sort_order', 0)),
            updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
            deletedAt: Value(row.dateTime('deleted_at')),
            version: Value(row.integerOr('version', 1)),
          ),
        );

      default:
        return false;
    }

    return true;
  }

  /// Sunucudaki silmeyi yerele taşır — TOMBSTONE olarak.
  ///
  /// Satırı GERÇEKTEN SİLMİYORUZ. Silseydik, bu cihazın outbox'ında o kayda
  /// ait bekleyen bir satır varsa gövdesi okunamaz hâle gelirdi; ayrıca
  /// FR-015'in çöp kutusu da tombstone'a dayanıyor.
  ///
  /// Kayıt yerelde HİÇ YOKSA hiçbir şey yapılmıyor: olmayan bir kaydı
  /// silinmiş olarak yaratmak, çöp kutusunda hayalet satırlar biriktirirdi.
  Future<bool> applyDelete({
    required String entityType,
    required String entityId,
    required int version,
    required DateTime now,
  }) async {
    final link = parseLinkId(entityId);

    Future<int> tekil<T extends Table, D>(
      TableInfo<T, D> table,
      GeneratedColumn<String> id,
    ) => (update(table)..where((_) => id.equals(entityId))).write(
      RawValuesInsertable({
        'deleted_at': Variable<DateTime>(now),
        'updated_at': Variable<DateTime>(now),
        'version': Variable<int>(version),
      }),
    );

    Future<int> bagli<T extends Table, D>(
      TableInfo<T, D> table,
      GeneratedColumn<String> ust,
      GeneratedColumn<String> alt,
    ) async {
      if (link == null) return 0;
      return (update(
        table,
      )..where((_) => ust.equals(link.parent) & alt.equals(link.child))).write(
        RawValuesInsertable({
          'deleted_at': Variable<DateTime>(now),
          'updated_at': Variable<DateTime>(now),
          'version': Variable<int>(version),
        }),
      );
    }

    switch (entityType) {
      case 'memory':
        await tekil(memories, memories.id);
      case 'location':
        await tekil(locations, locations.id);
      case 'media_item':
        await tekil(mediaItems, mediaItems.id);
      case 'category':
        await tekil(categories, categories.id);
      case 'collection':
        await tekil(collections, collections.id);
      case 'ritual':
        await tekil(rituals, rituals.id);
      case 'person':
        await tekil(people, people.id);
      case 'journal_entry':
        await tekil(journalEntries, journalEntries.id);

      case 'memory_people':
        await bagli(memoryPeople, memoryPeople.memoryId, memoryPeople.personId);
      case 'memory_collections':
        await bagli(
          memoryCollections,
          memoryCollections.memoryId,
          memoryCollections.collectionId,
        );
      case 'memory_rituals':
        await bagli(
          memoryRituals,
          memoryRituals.memoryId,
          memoryRituals.ritualId,
        );
      case 'ritual_people':
        await bagli(ritualPeople, ritualPeople.ritualId, ritualPeople.personId);
      case 'memory_media':
        await bagli(memoryMedia, memoryMedia.memoryId, memoryMedia.mediaId);
      case 'journal_media':
        await bagli(
          journalMedia,
          journalMedia.journalEntryId,
          journalMedia.mediaId,
        );

      default:
        return false;
    }

    return true;
  }

  /// Push'tan dönen SUNUCU SÜRÜMÜNÜ yerel satıra yazar.
  ///
  /// ⚠️ ATLANIRSA SESSİZ ÇAKIŞMA ÜRETİR: bir sonraki push, sunucunun artık
  /// bilmediği eski bir `baseVersion` gönderir ve kullanıcı kendi
  /// değişikliğini "başka bir sürüm" olarak görür.
  ///
  /// `updatedAt`e DOKUNMUYOR: kaydın içeriği değişmedi, yalnız sunucudaki
  /// karşılığının numarası öğrenildi. Tazeleseydik "son düzenleme" tarihi
  /// kullanıcının hiçbir şey yapmadığı bir ana kayardı.
  Future<bool> setServerVersion({
    required String entityType,
    required String entityId,
    required int version,
  }) async {
    final link = parseLinkId(entityId);

    // Insertable HER TABLO İÇİN AYRI kuruluyor: ortak bir değişkende
    // tutsaydık tipi `Object`e sabitlenir ve tablo tipiyle uyuşmazdı.
    Future<int> tekil<T extends Table, D>(
      TableInfo<T, D> table,
      GeneratedColumn<String> id,
    ) => (update(table)..where((_) => id.equals(entityId))).write(
      RawValuesInsertable<D>({'version': Variable<int>(version)}),
    );

    Future<int> bagli<T extends Table, D>(
      TableInfo<T, D> table,
      GeneratedColumn<String> ust,
      GeneratedColumn<String> alt,
    ) async {
      if (link == null) return 0;
      return (update(table)
            ..where((_) => ust.equals(link.parent) & alt.equals(link.child)))
          .write(RawValuesInsertable<D>({'version': Variable<int>(version)}));
    }

    switch (entityType) {
      case 'memory':
        await tekil(memories, memories.id);
      case 'location':
        await tekil(locations, locations.id);
      case 'media_item':
        await tekil(mediaItems, mediaItems.id);
      case 'category':
        await tekil(categories, categories.id);
      case 'collection':
        await tekil(collections, collections.id);
      case 'ritual':
        await tekil(rituals, rituals.id);
      case 'person':
        await tekil(people, people.id);
      case 'journal_entry':
        await tekil(journalEntries, journalEntries.id);
      case 'memory_people':
        await bagli(memoryPeople, memoryPeople.memoryId, memoryPeople.personId);
      case 'memory_collections':
        await bagli(
          memoryCollections,
          memoryCollections.memoryId,
          memoryCollections.collectionId,
        );
      case 'memory_rituals':
        await bagli(
          memoryRituals,
          memoryRituals.memoryId,
          memoryRituals.ritualId,
        );
      case 'ritual_people':
        await bagli(ritualPeople, ritualPeople.ritualId, ritualPeople.personId);
      case 'memory_media':
        await bagli(memoryMedia, memoryMedia.memoryId, memoryMedia.mediaId);
      case 'journal_media':
        await bagli(
          journalMedia,
          journalMedia.journalEntryId,
          journalMedia.mediaId,
        );
      default:
        return false;
    }

    return true;
  }

  // --- Satır kurucular ---------------------------------------------------
  //
  // Sunucudaki `ContentMappers.cs`ın aynası. Elle yazılı: yansımayla
  // kurulsaydı sunucudan gelen HER alan adı bir sütun aramaya başlardı ve
  // `owner_id` gibi İSTEMCİNİN karar verdiği alanlar da gövdeden yazılabilirdi.

  /// Gövdede tarih yoksa düşülen değer.
  ///
  /// `DateTime.now()` kullanmıyoruz: aynı gövde iki kez uygulandığında farklı
  /// sonuç üretir ve idempotentliği bozar. Sabit bir an, "bu tarih bilinmiyor"
  /// demenin en dürüst yolu.
  static final DateTime _epok = DateTime.utc(1970);

  MemoriesCompanion _memory(String id, RemoteRow row, String ownerId) {
    final occurredAt = row.dateTimeOr('occurred_at', _epok);

    return MemoriesCompanion.insert(
      id: id,
      // ⚠️ SAHİPLİK GÖVDEDEN OKUNMUYOR. Sunucu `owner_id`yi kendi
      // kimliğiyle dolduruyor ama yerel tablo `'local'` bekliyor olabilir;
      // doğru değer bu cihazda oturum açmış kullanıcınınki.
      ownerId: Value(ownerId),
      title: Value(row.text('title')),
      note: Value(row.text('note')),
      occurredAt: occurredAt,
      // Tarih parçaları GÖVDEDEN okunuyor, `occurredAt`ten HESAPLANMIYOR:
      // onlar kaydın YEREL gününü taşıyor ve UTC'den türetmek anıyı yanlış
      // güne düşürürdü (bkz. memory_tables.dart'taki denormalizasyon notu).
      occurredYear: row.integerOr('occurred_year', occurredAt.year),
      occurredMonth: row.integerOr('occurred_month', occurredAt.month),
      occurredDay: row.integerOr('occurred_day', occurredAt.day),
      categoryId: Value(row.text('category_id')),
      locationId: Value(row.text('location_id')),
      coverMediaId: Value(row.text('cover_media_id')),
      isFavorite: Value(row.boolean('is_favorite')),
      isArchived: Value(row.boolean('is_archived')),
      sourceJournalEntryId: Value(row.text('source_journal_entry_id')),
      createdAt: Value(row.dateTimeOr('created_at', _epok)),
      updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
      deletedAt: Value(row.dateTime('deleted_at')),
      version: Value(row.integerOr('version', 1)),
    );
  }

  LocationsCompanion _location(String id, RemoteRow row) =>
      LocationsCompanion.insert(
        id: id,
        label: row.textOr('label', ''),
        latitude: Value(row.real('latitude')),
        longitude: Value(row.real('longitude')),
        city: Value(row.text('city')),
        country: Value(row.text('country')),
        createdAt: Value(row.dateTimeOr('created_at', _epok)),
        updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
        deletedAt: Value(row.dateTime('deleted_at')),
        version: Value(row.integerOr('version', 1)),
      );

  MediaItemsCompanion _media(String id, RemoteRow row) =>
      MediaItemsCompanion.insert(
        id: id,
        type: row.enumOr('type', MediaType.values, MediaType.photo),
        // ⚠️ `gallery_asset_id`, `local_preview_path` ve `last_verified_at`
        // OKUNMUYOR — sunucuda sütunları bile yok (yol haritası §4.6).
        // Üçü de CİHAZA ÖZGÜ: başka bir cihazın yolunu buraya yazmak, var
        // olmayan bir dosyayı gerçek sanmak olurdu.
        cloudObjectKey: Value(row.text('cloud_object_key')),
        originalStatus: Value(
          row.enumOr(
            'original_status',
            MediaOriginalStatus.values,
            MediaOriginalStatus.unknown,
          ),
        ),
        mimeType: Value(row.text('mime_type')),
        width: Value(row.integer('width')),
        height: Value(row.integer('height')),
        durationMs: Value(row.integer('duration_ms')),
        sizeBytes: Value(row.integer('size_bytes')),
        createdAt: Value(row.dateTimeOr('created_at', _epok)),
        updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
        deletedAt: Value(row.dateTime('deleted_at')),
        version: Value(row.integerOr('version', 1)),
      );

  CategoriesCompanion _category(String id, RemoteRow row, String ownerId) =>
      CategoriesCompanion.insert(
        id: id,
        ownerId: Value(ownerId),
        name: row.textOr('name', ''),
        iconKey: Value(row.textOr('icon_key', 'daily')),
        sortOrder: Value(row.integerOr('sort_order', 0)),
        isSystem: Value(row.boolean('is_system')),
        createdAt: Value(row.dateTimeOr('created_at', _epok)),
        updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
        deletedAt: Value(row.dateTime('deleted_at')),
        version: Value(row.integerOr('version', 1)),
      );

  CollectionsCompanion _collection(String id, RemoteRow row, String ownerId) =>
      CollectionsCompanion.insert(
        id: id,
        ownerId: Value(ownerId),
        title: row.textOr('title', ''),
        description: Value(row.text('description')),
        coverMediaId: Value(row.text('cover_media_id')),
        visibility: Value(
          row.enumOr(
            'visibility',
            CollectionVisibility.values,
            CollectionVisibility.private,
          ),
        ),
        startDate: Value(row.dateTime('start_date')),
        endDate: Value(row.dateTime('end_date')),
        createdAt: Value(row.dateTimeOr('created_at', _epok)),
        updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
        deletedAt: Value(row.dateTime('deleted_at')),
        version: Value(row.integerOr('version', 1)),
      );

  RitualsCompanion _ritual(String id, RemoteRow row, String ownerId) =>
      RitualsCompanion.insert(
        id: id,
        ownerId: Value(ownerId),
        title: row.textOr('title', ''),
        recurrenceType: Value(
          row.enumOr(
            'recurrence_type',
            RecurrenceType.values,
            RecurrenceType.yearly,
          ),
        ),
        anchorMonth: Value(row.integer('anchor_month')),
        anchorDay: Value(row.integer('anchor_day')),
        iconKey: Value(row.textOr('icon_key', 'ritual')),
        createdAt: Value(row.dateTimeOr('created_at', _epok)),
        updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
        deletedAt: Value(row.dateTime('deleted_at')),
        version: Value(row.integerOr('version', 1)),
      );

  PeopleCompanion _person(String id, RemoteRow row, String ownerId) =>
      PeopleCompanion.insert(
        id: id,
        ownerId: Value(ownerId),
        name: row.textOr('name', ''),
        kind: Value(row.enumOr('kind', PersonKind.values, PersonKind.human)),
        relationType: Value(
          row.enumOr('relation_type', RelationType.values, RelationType.other),
        ),
        relationLabel: Value(row.text('relation_label')),
        birthDate: Value(row.dateTime('birth_date')),
        avatarMediaId: Value(row.text('avatar_media_id')),
        note: Value(row.text('note')),
        isFavorite: Value(row.boolean('is_favorite')),
        createdAt: Value(row.dateTimeOr('created_at', _epok)),
        updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
        deletedAt: Value(row.dateTime('deleted_at')),
        version: Value(row.integerOr('version', 1)),
      );

  JournalEntriesCompanion _journal(String id, RemoteRow row, String ownerId) =>
      JournalEntriesCompanion.insert(
        id: id,
        ownerId: Value(ownerId),
        entryDate: row.dateTimeOr('entry_date', _epok),
        // İstemcide sütun adı `content`, `text` DEĞİL: `text` Drift'in sütun
        // kurucusu ve aynı adı sütuna veremiyor.
        content: Value(row.textOr('content', '')),
        title: Value(row.text('title')),
        moodScore: Value(row.integer('mood_score')),
        moodKey: Value(row.text('mood_key')),
        promptId: Value(row.text('prompt_id')),
        // ⚠️ `deviceOnly` bir kayıt BURAYA GELMEMELİ: o kayıt outbox'a bile
        // girmiyor (TR-M3-02), dolayısıyla sunucuda karşılığı yok. Yine de
        // gelirse olduğu gibi yazılıyor — kullanıcının kendi cihazından
        // çıkmış bir kaydı burada gizlemek, sorunu görünmez yapardı.
        privacyMode: Value(
          row.enumOr(
            'privacy_mode',
            JournalPrivacyMode.values,
            JournalPrivacyMode.standard,
          ),
        ),
        isFavorite: Value(row.boolean('is_favorite')),
        convertedMemoryId: Value(row.text('converted_memory_id')),
        createdAt: Value(row.dateTimeOr('created_at', _epok)),
        updatedAt: Value(row.dateTimeOr('updated_at', _epok)),
        deletedAt: Value(row.dateTime('deleted_at')),
        version: Value(row.integerOr('version', 1)),
      );
}
