/// Anı veri erişim nesnesi (DAO).
///
/// SORUMLULUĞU: SQL. Sadece SQL.
/// Burada iş kuralı YOK, domain tipi YOK, `Result` YOK.
/// DAO ham satır (`MemoryRow`) döner; domain'e çeviren `MemoryMapper`,
/// hataları `Failure`a çeviren `MemoryRepositoryImpl`dir.
///
/// Bu ayrım sayesinde DAO'yu gerçek (bellek içi) veritabanıyla test
/// edebilirsin — mock'a gerek kalmaz.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/collections/data/tables/collection_tables.dart';
import 'package:iz/features/media/data/tables/media_tables.dart';
import 'package:iz/features/memories/data/tables/memory_tables.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';
import 'package:iz/features/people/data/tables/person_tables.dart';
import 'package:iz/features/rituals/data/tables/ritual_tables.dart';

part 'memory_dao.g.dart';

/// Liste sorgusunun sonucu: anı + kapak medyası + ilişki sayıları.
///
/// NEDEN AYRI TİP?
/// Timeline'da 500 anı varsa her birinin tüm medyasını/kişisini yüklemek
/// NFR-003'ü ihlal eder. Sadece sayıları ve TEK kapak görselini çekiyoruz.
class MemoryListRow {
  const MemoryListRow({
    required this.memory,
    required this.mediaCount,
    required this.personCount,
    this.cover,
    this.location,
  });

  final MemoryRow memory;
  final MediaRow? cover;
  final LocationRow? location;
  final int mediaCount;
  final int personCount;
}

/// Detay sorgusunun sonucu — ilişkiler yüklü.
class MemoryDetailRow {
  const MemoryDetailRow({
    required this.memory,
    required this.media,
    required this.people,
    required this.collections,
    this.ritual,
    this.ritualYear,
    this.location,
  });

  final MemoryRow memory;
  final List<MediaRow> media;
  final List<PersonRow> people;
  final List<CollectionRow> collections;
  final RitualRow? ritual;
  final int? ritualYear;
  final LocationRow? location;
}

@DriftAccessor(
  tables: [
    Memories,
    Locations,
    MediaItems,
    MemoryMedia,
    MemoryPeople,
    MemoryCollections,
    MemoryRituals,
    People,
    Collections,
    Rituals,
  ],
)
class MemoryDao extends DatabaseAccessor<AppDatabase> with _$MemoryDaoMixin {
  MemoryDao(super.db);

  // ---------------------------------------------------------------------
  // OKUMA
  // ---------------------------------------------------------------------

  /// Timeline akışı.
  ///
  /// `watch()` döndürüyoruz, `get()` değil: Drift ilgili tablolar
  /// değiştiğinde stream'i otomatik yeniler. Yani bir anı kaydedince
  /// liste ekranı kendi kendine güncellenir — elle "refresh" çağırmaya
  /// gerek kalmaz. MVVM'de ViewModel'i bu akışa bağlarız.
  ///
  /// [ftsQuery] doluysa sonuç FTS5 indeksiyle eşleşen anılarla sınırlanır.
  ///
  /// DİKKAT — arama neden ayrı bir sorgu DEĞİL?
  /// Önce FTS'i çalıştırıp id listesi çıkarmak ve o listeyi buraya vermek
  /// cazip görünür ama **bayat sonuç** üretir: id listesi bir kez hesaplanır,
  /// sonra kullanıcı arama açıkken yeni bir anı eklerse veya bir anının
  /// metnini düzenlerse liste onu göremez.
  ///
  /// FTS eşleşmesini alt sorgu olarak buraya gömünce sorgu tek parça olur;
  /// Drift `memories` tablosu her değiştiğinde tamamını yeniden çalıştırır ve
  /// sonuç her zaman günceldir.
  Stream<List<MemoryListRow>> watchMemories(
    MemoryFilter filter, {
    String? ftsQuery,
  }) {
    // Correlated subquery'ler: her anı için ilişki sayısı.
    final mediaCountExp = subqueryExpression<int>(
      selectOnly(memoryMedia)
        ..addColumns([memoryMedia.mediaId.count()])
        ..where(memoryMedia.memoryId.equalsExp(memories.id)),
    );

    final personCountExp = subqueryExpression<int>(
      selectOnly(memoryPeople)
        ..addColumns([memoryPeople.personId.count()])
        ..where(memoryPeople.memoryId.equalsExp(memories.id)),
    );

    final query = select(memories).join([
      leftOuterJoin(mediaItems, mediaItems.id.equalsExp(memories.coverMediaId)),
      leftOuterJoin(locations, locations.id.equalsExp(memories.locationId)),
    ])..addColumns([mediaCountExp, personCountExp]);

    // --- Filtreler -------------------------------------------------------

    // Soft-delete edilmiş kayıtlar hiçbir zaman listede görünmez.
    query.where(memories.deletedAt.isNull());

    if (!filter.includeArchived) {
      query.where(memories.isArchived.equals(false));
    }
    if (filter.onlyFavorites) {
      query.where(memories.isFavorite.equals(true));
    }
    if (filter.categoryIds.isNotEmpty) {
      query.where(memories.categoryId.isIn(filter.categoryIds.toList()));
    }
    if (filter.from != null) {
      query.where(memories.occurredAt.isBiggerOrEqualValue(filter.from!));
    }
    if (filter.to != null) {
      query.where(memories.occurredAt.isSmallerOrEqualValue(filter.to!));
    }
    if (ftsQuery != null) {
      // Drift'in Dart API'si FTS5 `MATCH`i ifade edemez; alt sorguyu ham SQL
      // olarak yazıyoruz.
      //
      // GÜVENLİK: `CustomExpression` parametre (`?`) desteklemiyor, bu yüzden
      // ifade metne gömülüyor. Güvenli olmasının sebebi, gömülen metnin
      // kullanıcıdan gelmemesi: `MemoryRepositoryImpl._toFtsQuery` girdiden
      // harf ve rakam DIŞINDAKİ her karakteri atar, sonra token'ları kendisi
      // tırnaklar. Yani tırnak/kaçış karakteri buraya asla ulaşamaz.
      //
      // Stream tazeliği: bu ifade `memory_search`i okuyor ama onu
      // `watchedTables`a EKLEMİYORUZ — o tabloyu trigger'lar yazıyor ve Drift
      // trigger yazmalarını göremez. Buna gerek de yok: indeks yalnızca
      // `memories` değiştiğinde değişir ve bu sorgu zaten `memories`i izliyor.
      query.where(
        CustomExpression<bool>(
          'memories.id IN (SELECT memory_id FROM memory_search '
          "WHERE memory_search MATCH '$ftsQuery')",
        ),
      );
    }

    // N-N filtreler EXISTS ile: join yapıp DISTINCT çekmekten daha ucuz
    // ve satır çoğaltma (kartezyen) riski yok.
    if (filter.personIds.isNotEmpty) {
      query.where(
        existsQuery(
          selectOnly(memoryPeople)
            ..addColumns([memoryPeople.personId])
            ..where(
              memoryPeople.memoryId.equalsExp(memories.id) &
                  memoryPeople.personId.isIn(filter.personIds.toList()),
            ),
        ),
      );
    }
    if (filter.collectionIds.isNotEmpty) {
      query.where(
        existsQuery(
          selectOnly(memoryCollections)
            ..addColumns([memoryCollections.collectionId])
            ..where(
              memoryCollections.memoryId.equalsExp(memories.id) &
                  memoryCollections.collectionId.isIn(
                    filter.collectionIds.toList(),
                  ),
            ),
        ),
      );
    }
    if (filter.ritualId != null) {
      query.where(
        existsQuery(
          selectOnly(memoryRituals)
            ..addColumns([memoryRituals.ritualId])
            ..where(
              memoryRituals.memoryId.equalsExp(memories.id) &
                  memoryRituals.ritualId.equals(filter.ritualId!),
            ),
        ),
      );
    }

    // --- Sıralama ve limit ----------------------------------------------
    query.orderBy(switch (filter.sortOrder) {
      MemorySortOrder.occurredAtDesc => [
        OrderingTerm.desc(memories.occurredAt),
      ],
      MemorySortOrder.occurredAtAsc => [OrderingTerm.asc(memories.occurredAt)],
      MemorySortOrder.recentlyAdded => [OrderingTerm.desc(memories.createdAt)],
    });

    if (filter.limit != null) {
      query.limit(filter.limit!);
    }

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => MemoryListRow(
              memory: row.readTable(memories),
              cover: row.readTableOrNull(mediaItems),
              location: row.readTableOrNull(locations),
              mediaCount: row.read(mediaCountExp) ?? 0,
              personCount: row.read(personCountExp) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// FR-020 — detay ekranı için tüm ilişkileri yükler.
  Future<MemoryDetailRow?> findDetail(String id) async {
    final memory = await (select(
      memories,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

    if (memory == null) return null;
    return _detailOf(memory);
  }

  /// Detayın canlı akışı.
  ///
  /// Anı satırı her değiştiğinde ilişkiler yeniden çekilir. Medya/kişi
  /// eklendiğinde de tetiklenir, çünkü `upsertMemory` aynı transaction'da
  /// `memories.updatedAt` alanını da tazeler.
  Stream<MemoryDetailRow?> watchDetail(String id) {
    return (select(memories)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .watchSingleOrNull()
        .asyncMap((row) async => row == null ? null : await _detailOf(row));
  }

  Future<MemoryDetailRow> _detailOf(MemoryRow memory) async {
    final id = memory.id;

    // İlişkileri paralel çek — sıralı await'ten belirgin şekilde hızlı.
    final results = await Future.wait([
      _mediaOf(id),
      _peopleOf(id),
      _collectionsOf(id),
      _ritualOf(id),
      if (memory.locationId != null)
        (select(
          locations,
        )..where((t) => t.id.equals(memory.locationId!))).getSingleOrNull()
      else
        Future<LocationRow?>.value(),
    ]);

    final ritualPair = results[3] as ({RitualRow row, int year})?;

    return MemoryDetailRow(
      memory: memory,
      media: results[0]! as List<MediaRow>,
      people: results[1]! as List<PersonRow>,
      collections: results[2]! as List<CollectionRow>,
      ritual: ritualPair?.row,
      ritualYear: ritualPair?.year,
      location: results[4] as LocationRow?,
    );
  }

  Future<List<MediaRow>> _mediaOf(String memoryId) {
    final q =
        select(memoryMedia).join([
            innerJoin(mediaItems, mediaItems.id.equalsExp(memoryMedia.mediaId)),
          ])
          ..where(memoryMedia.memoryId.equals(memoryId))
          ..orderBy([OrderingTerm.asc(memoryMedia.sortOrder)]);

    return q.map((row) => row.readTable(mediaItems)).get();
  }

  Future<List<PersonRow>> _peopleOf(String memoryId) {
    final q = select(memoryPeople).join([
      innerJoin(people, people.id.equalsExp(memoryPeople.personId)),
    ])..where(memoryPeople.memoryId.equals(memoryId));

    return q.map((row) => row.readTable(people)).get();
  }

  Future<List<CollectionRow>> _collectionsOf(String memoryId) {
    final q = select(memoryCollections).join([
      innerJoin(
        collections,
        collections.id.equalsExp(memoryCollections.collectionId),
      ),
    ])..orderBy([OrderingTerm.asc(memoryCollections.sortOrder)]);
    q.where(memoryCollections.memoryId.equals(memoryId));

    return q.map((row) => row.readTable(collections)).get();
  }

  Future<({RitualRow row, int year})?> _ritualOf(String memoryId) async {
    final q = select(memoryRituals).join([
      innerJoin(rituals, rituals.id.equalsExp(memoryRituals.ritualId)),
    ])..where(memoryRituals.memoryId.equals(memoryId));

    final row = await q.getSingleOrNull();
    if (row == null) return null;
    return (
      row: row.readTable(rituals),
      year: row.readTable(memoryRituals).occurrenceYear,
    );
  }

  /// FR-080 "Bugünün İzi": geçmiş yılların aynı gününe ait anılar.
  ///
  /// SQLite'ta tarih TEXT (ISO-8601) saklandığı için ay/gün karşılaştırmasını
  /// `strftime` ile yapıyoruz.
  Future<List<MemoryRow>> findOnThisDay(DateTime day) {
    return (select(memories)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.isArchived.equals(false) &
                // occurredAt üzerinden strftime ile ay/gün çıkarmıyoruz:
                // o değer UTC'dir ve gün kaydırabilir. Yerel tarih
                // parçalarını kullanıyoruz.
                t.occurredMonth.equals(day.month) &
                t.occurredDay.equals(day.day) &
                // Sadece GEÇMİŞ yıllar — bugünün anısı "bugünün izi" değil.
                t.occurredYear.isSmallerThanValue(day.year),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
        .get();
  }

  /// FR-063 — kişinin yaşam çizgisi.
  Stream<List<MemoryListRow>> watchByPerson(String personId) =>
      watchMemories(MemoryFilter(personIds: {personId}));

  /// FR-076 — ritüelin yıllara göre anıları.
  Stream<List<MemoryListRow>> watchByRitual(String ritualId) => watchMemories(
    MemoryFilter(ritualId: ritualId, sortOrder: MemorySortOrder.occurredAtAsc),
  );

  // ---------------------------------------------------------------------
  // YAZMA
  // ---------------------------------------------------------------------

  /// Anıyı ve TÜM ilişkilerini tek transaction'da yazar.
  ///
  /// NFR-020: "Bir Anı kaydı yarım yazılmış durumda bırakılmamalı; ilişkili
  /// DB işlemleri transaction mantığıyla ele alınmalıdır."
  ///
  /// Transaction olmadan: anı yazılır, sonra kişi bağlama sırasında hata
  /// olur → kullanıcının anısı kişisiz kalır ve bunu asla fark etmez.
  Future<void> upsertMemory({
    required MemoriesCompanion memory,
    required List<String> personIds,
    required List<String> collectionIds,
    required List<String> mediaIds,
    String? ritualId,
    int? ritualYear,
  }) {
    return transaction(() async {
      final id = memory.id.value;

      await into(memories).insertOnConflictUpdate(memory);

      // İlişkileri "sil ve yeniden yaz" stratejisi: diff hesaplamaktan
      // çok daha basit ve bu ölçekte (bir anıda onlarca ilişki) yeterince hızlı.
      await (delete(memoryPeople)..where((t) => t.memoryId.equals(id))).go();
      await (delete(
        memoryCollections,
      )..where((t) => t.memoryId.equals(id))).go();
      await (delete(memoryRituals)..where((t) => t.memoryId.equals(id))).go();
      await (delete(memoryMedia)..where((t) => t.memoryId.equals(id))).go();

      await batch((b) {
        b.insertAll(memoryPeople, [
          for (final personId in personIds)
            MemoryPeopleCompanion.insert(memoryId: id, personId: personId),
        ]);

        b.insertAll(memoryCollections, [
          for (final (index, collectionId) in collectionIds.indexed)
            MemoryCollectionsCompanion.insert(
              memoryId: id,
              collectionId: collectionId,
              sortOrder: Value(index),
            ),
        ]);

        b.insertAll(memoryMedia, [
          for (final (index, mediaId) in mediaIds.indexed)
            MemoryMediaCompanion.insert(
              memoryId: id,
              mediaId: mediaId,
              sortOrder: Value(index),
            ),
        ]);

        if (ritualId != null) {
          b.insert(
            memoryRituals,
            MemoryRitualsCompanion.insert(
              memoryId: id,
              ritualId: ritualId,
              occurrenceYear: ritualYear ?? DateTime.now().year,
            ),
          );
        }
      });
    });
  }

  /// FR-019 — favori işaretini değiştirir.
  Future<void> setFavorite(String id, {required bool isFavorite}) => _patch(
    id,
    (row) => MemoriesCompanion(
      isFavorite: Value(isFavorite),
      updatedAt: Value(DateTime.now()),
      version: Value(row.version + 1),
    ),
  );

  /// FR-014 — arşivle.
  Future<void> setArchived(String id, {required bool isArchived}) => _patch(
    id,
    (row) => MemoriesCompanion(
      isArchived: Value(isArchived),
      updatedAt: Value(DateTime.now()),
      version: Value(row.version + 1),
    ),
  );

  /// FR-015 — geri alınabilir silme ("çöp kutusu").
  /// Kayıt gitmez, `deletedAt` dolar. Rapor 12.2'deki tombstone yaklaşımı.
  Future<void> softDelete(String id) => _patch(
    id,
    (row) => MemoriesCompanion(
      deletedAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
      version: Value(row.version + 1),
    ),
  );

  Future<void> restore(String id) => _patch(
    id,
    (row) => MemoriesCompanion(
      // Value(null) = "bu sütunu NULL yap".
      // Value.absent() ise "bu sütuna dokunma" demektir — ikisini
      // karıştırmak Drift'te en sık yapılan hatadır.
      deletedAt: const Value(null),
      updatedAt: Value(DateTime.now()),
      version: Value(row.version + 1),
    ),
  );

  /// Çöp kutusunda [retention] süresini aşmış kayıtları kalıcı siler.
  /// Uygulama açılışında çalıştırılır.
  Future<int> purgeExpiredTrash({
    Duration retention = const Duration(days: 30),
  }) {
    final cutoff = DateTime.now().subtract(retention);
    return (delete(memories)..where(
          (t) =>
              t.deletedAt.isNotNull() & t.deletedAt.isSmallerThanValue(cutoff),
        ))
        .go();
  }

  Future<List<MemoryRow>> trashedMemories() =>
      (select(memories)
            ..where((t) => t.deletedAt.isNotNull())
            ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
          .get();

  Future<int> countAll() async {
    final countExp = memories.id.count();
    final row =
        await (selectOnly(memories)
              ..addColumns([countExp])
              ..where(memories.deletedAt.isNull()))
            .getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Mevcut satırı okuyup üstüne yazan yardımcı.
  ///
  /// `version + 1` gibi ifadeleri Companion'a doğrudan yazamayız
  /// (Companion sabit değer bekler), bu yüzden önce okuyoruz.
  /// Transaction içinde olduğu için araya başka yazma giremez.
  Future<void> _patch(
    String id,
    MemoriesCompanion Function(MemoryRow current) build,
  ) {
    return transaction(() async {
      final current = await (select(
        memories,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (current == null) return;

      await (update(
        memories,
      )..where((t) => t.id.equals(id))).write(build(current));
    });
  }
}
