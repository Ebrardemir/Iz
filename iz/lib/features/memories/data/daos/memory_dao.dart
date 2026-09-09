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
import 'package:iz/features/sync/data/daos/outbox_dao.dart';
import 'package:iz/features/sync/data/outbox_payload.dart';
import 'package:iz/features/sync/domain/entities/outbox_operation.dart';

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

/// Anının outbox'taki karşılığı — sunucu bu adla tanıyor.
///
/// Sabit ve DEĞİŞMEZ: kullanıcının cihazında bekleyen eski kuyruk satırları
/// bu adı taşıyor.
const kMemoryEntityType = 'memory';

/// Konumun outbox'taki karşılığı.
///
/// ⚠️ KONUM AYRI BİR KAYIT, anının parçası DEĞİL. Anı yalnız `locationId`
/// taşıyor; satırın kendisi ayrıca gönderilmezse ikinci cihazda o kimlik
/// hiçbir şeye karşılık gelmez ve anı KONUMSUZ görünür — üstelik hiçbir hata
/// üretmeden.
const kLocationEntityType = 'location';

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
    // `deletedAt IS NULL` HER BAĞ SORGUSUNDA ZORUNLU (TR-C-32, şema v8).
    // Bağlar artık silinmiyor, tombstone'lanıyor; süzgeci atlayan bir sorgu
    // koparılmış ilişkiyi ekranda göstermeye devam eder.
    final mediaCountExp = subqueryExpression<int>(
      selectOnly(memoryMedia)
        ..addColumns([memoryMedia.mediaId.count()])
        ..where(
          memoryMedia.memoryId.equalsExp(memories.id) &
              memoryMedia.deletedAt.isNull(),
        ),
    );

    final personCountExp = subqueryExpression<int>(
      selectOnly(memoryPeople)
        ..addColumns([memoryPeople.personId.count()])
        ..where(
          memoryPeople.memoryId.equalsExp(memories.id) &
              memoryPeople.deletedAt.isNull(),
        ),
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
                  memoryPeople.deletedAt.isNull() &
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
                  memoryCollections.deletedAt.isNull() &
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
                  memoryRituals.deletedAt.isNull() &
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
          ..where(
            memoryMedia.memoryId.equals(memoryId) &
                memoryMedia.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.asc(memoryMedia.sortOrder)]);

    return q.map((row) => row.readTable(mediaItems)).get();
  }

  Future<List<PersonRow>> _peopleOf(String memoryId) {
    final q =
        select(memoryPeople).join([
          innerJoin(people, people.id.equalsExp(memoryPeople.personId)),
        ])..where(
          memoryPeople.memoryId.equals(memoryId) &
              memoryPeople.deletedAt.isNull(),
        );

    return q.map((row) => row.readTable(people)).get();
  }

  Future<List<CollectionRow>> _collectionsOf(String memoryId) {
    final q = select(memoryCollections).join([
      innerJoin(
        collections,
        collections.id.equalsExp(memoryCollections.collectionId),
      ),
    ])..orderBy([OrderingTerm.asc(memoryCollections.sortOrder)]);
    q.where(
      memoryCollections.memoryId.equals(memoryId) &
          memoryCollections.deletedAt.isNull(),
    );

    return q.map((row) => row.readTable(collections)).get();
  }

  Future<({RitualRow row, int year})?> _ritualOf(String memoryId) async {
    final q =
        select(memoryRituals).join([
          innerJoin(rituals, rituals.id.equalsExp(memoryRituals.ritualId)),
        ])..where(
          memoryRituals.memoryId.equals(memoryId) &
              memoryRituals.deletedAt.isNull(),
        );

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

  /// Aynı ada sahip konumu bulur — yoksa null.
  ///
  /// Etikete göre arıyoruz çünkü kullanıcının elinde koordinat yok, yazdığı
  /// metin var. Aynı yeri iki kez yazınca iki satır açsaydık "bu şehirdeki
  /// anılarım" sorgusu ikiye bölünürdü.
  Future<LocationRow?> findLocationByLabel(String label) {
    return (select(locations)
          ..where((t) => t.label.equals(label) & t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  /// Konumu yazar VE kuyruğa düşürür.
  ///
  /// İkisi tek transaction'da: ayrı olsalardı aradaki bir çökme konumu
  /// yerelde bırakır ama sunucuya gideceği hiçbir yere yazmazdı (TR-M13-01).
  ///
  /// Konum yalnız OLUŞTURULUYOR, hiç güncellenmiyor: kullanıcının yazdığı
  /// etiket bir kez bir satıra çevriliyor ve aynı etiket ikinci kez
  /// yazıldığında var olan satır bulunuyor (bkz. [findLocationByLabel]).
  /// Bu yüzden tek işlem `create` ve `baseVersion` her zaman 0.
  Future<void> insertLocation(
    LocationsCompanion location, {
    required String outboxId,
    required DateTime now,
  }) => transaction(() async {
    await into(locations).insert(location);

    final row = await (select(
      locations,
    )..where((t) => t.id.equals(location.id.value))).getSingle();

    await OutboxDao(attachedDatabase).enqueue(
      id: outboxId,
      entityType: kLocationEntityType,
      entityId: row.id,
      op: OutboxOperation.create,
      payloadJson: encodeOutboxPayload(entity: outboxRowJson(row)),
      baseVersion: 0,
      now: now,
    );
  });

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
    // TR-C-41 — saat dışarıdan. Bağların `updatedAt`i anının kendisiyle
    // AYNI ana damgalanmalı; DAO kendi saatini okusaydı transaction içinde
    // milisaniyeler ayrışırdı.
    required DateTime now,
    // Kuyruk satırının kimliği. ÇAĞIRAN ÜRETİYOR çünkü `IdGenerator` bir
    // bağımlılık ve DAO'nun bağımlılığı yalnız veritabanı olmalı.
    required String outboxId,
    String? ritualId,
    int? ritualYear,
  }) {
    return transaction(() async {
      final id = memory.id.value;
      final onceki = await (select(
        memories,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      await into(memories).insertOnConflictUpdate(memory);

      await _syncPeople(id, personIds, now);
      await _syncCollections(id, collectionIds, now);
      await _syncMedia(id, mediaIds, now);
      await _syncRitual(id, ritualId, ritualYear, now);

      await _enqueue(
        id,
        // Kayıt önceden yoksa bu bir OLUŞTURMA. Sunucu ikisini ayırt
        // etmeli: var olmayan bir kaydı güncellemeye çalışmak hata.
        op: onceki == null ? OutboxOperation.create : OutboxOperation.update,
        baseVersion: onceki?.version ?? 0,
        outboxId: outboxId,
        now: now,
      );
    });
  }

  /// Değişikliği outbox'a düşürür — AYNI TRANSACTION İÇİNDEN.
  ///
  /// Ayrı transaction olsaydı ikisinin arasında çöken bir uygulama
  /// değişikliği kalıcı olarak kaybederdi: veri yerelde değişmiş ama
  /// sunucuya gideceği hiçbir yere yazılmamış olurdu (TR-M13-01).
  ///
  /// Gövde SATIRLARDAN üretiliyor ve BAĞLARI da taşıyor — tombstone'lananlar
  /// dâhil. Gerekçesi `outbox_payload.dart` başındaki notta.
  Future<void> _enqueue(
    String memoryId, {
    required OutboxOperation op,
    required int baseVersion,
    required String outboxId,
    required DateTime now,
  }) async {
    final row = await (select(
      memories,
    )..where((t) => t.id.equals(memoryId))).getSingleOrNull();
    if (row == null) return;

    // BAĞLAR SÜZÜLMEDEN alınıyor: tombstone'lananlar da gövdeye giriyor.
    // Yalnız canlıları gönderseydik sunucu "eksik olan henüz gelmemiş" ile
    // "eksik olan silinmiş"i ayırt edemezdi (rapor §1.1).
    final kisiler = await (select(
      memoryPeople,
    )..where((t) => t.memoryId.equals(memoryId))).get();
    final koleksiyonlar = await (select(
      memoryCollections,
    )..where((t) => t.memoryId.equals(memoryId))).get();
    final seriler = await (select(
      memoryRituals,
    )..where((t) => t.memoryId.equals(memoryId))).get();
    final medyalar = await (select(
      memoryMedia,
    )..where((t) => t.memoryId.equals(memoryId))).get();

    final payload = encodeOutboxPayload(
      entity: outboxRowJson(row),
      links: {
        'memory_people': [for (final link in kisiler) outboxRowJson(link)],
        'memory_collections': [
          for (final link in koleksiyonlar) outboxRowJson(link),
        ],
        'memory_rituals': [for (final link in seriler) outboxRowJson(link)],
        'memory_media': [for (final link in medyalar) outboxRowJson(link)],
      },
    );

    await OutboxDao(attachedDatabase).enqueue(
      id: outboxId,
      entityType: kMemoryEntityType,
      entityId: memoryId,
      op: op,
      payloadJson: payload,
      baseVersion: baseVersion,
      now: now,
    );
  }

  // --- Bağ eşitleme ---------------------------------------------------
  //
  // ESKİDEN "SİL VE YENİDEN YAZ" İDİ. v8'den beri yasak: bağı gerçekten
  // silersek ikinci cihaz o satırı hiç görmez, "bende var sende yok"
  // durumunu "sen henüz almamışsın" diye okur ve çıkarılan kişiyi geri
  // ekler (rapor §1.1). Silme artık bir SATIR.
  //
  // Her bağ için üç durum var:
  //   • kümede var, satır yok        → yeni bağ
  //   • kümede var, satır tombstone  → DİRİLTİLİYOR (`deletedAt` null'a döner)
  //   • kümede yok, satır canlı      → tombstone
  //
  // Önce mevcut satırlar OKUNUYOR: `version`ı bir artırmak için eski
  // değeri bilmek gerekiyor (TR-C-31) ve Drift'in `update().write()`i
  // sütunun kendisine dayalı ifade kabul etmiyor. Bir anıda onlarca bağ
  // olduğu için maliyeti önemsiz.
  //
  // Aşağıdaki dört fonksiyon aynı işi yapıyor; ayrı yazılmalarının sebebi
  // bağ tablolarının farklı ikinci anahtar ve ek sütunlar taşıması
  // (`sortOrder`, `occurrenceYear`).

  Future<void> _syncPeople(
    String id,
    List<String> personIds,
    DateTime now,
  ) async {
    final current = await (select(
      memoryPeople,
    )..where((t) => t.memoryId.equals(id))).get();
    final byPerson = {for (final row in current) row.personId: row};

    for (final row in current) {
      if (row.deletedAt == null && !personIds.contains(row.personId)) {
        await (update(memoryPeople)..where(
              (t) => t.memoryId.equals(id) & t.personId.equals(row.personId),
            ))
            .write(
              MemoryPeopleCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
                version: Value(row.version + 1),
              ),
            );
      }
    }

    for (final personId in personIds) {
      final existing = byPerson[personId];
      if (existing != null && existing.deletedAt == null) continue;

      await into(memoryPeople).insertOnConflictUpdate(
        MemoryPeopleCompanion.insert(
          memoryId: id,
          personId: personId,
          updatedAt: Value(now),
          // Diriltme: `deletedAt` açıkça null'a çekiliyor.
          deletedAt: const Value(null),
          version: Value((existing?.version ?? 0) + 1),
        ),
      );
    }
  }

  Future<void> _syncCollections(
    String id,
    List<String> collectionIds,
    DateTime now,
  ) async {
    final current = await (select(
      memoryCollections,
    )..where((t) => t.memoryId.equals(id))).get();
    final byCollection = {for (final row in current) row.collectionId: row};

    for (final row in current) {
      if (row.deletedAt == null && !collectionIds.contains(row.collectionId)) {
        await (update(memoryCollections)..where(
              (t) =>
                  t.memoryId.equals(id) &
                  t.collectionId.equals(row.collectionId),
            ))
            .write(
              MemoryCollectionsCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
                version: Value(row.version + 1),
              ),
            );
      }
    }

    for (final (index, collectionId) in collectionIds.indexed) {
      final existing = byCollection[collectionId];
      await into(memoryCollections).insertOnConflictUpdate(
        MemoryCollectionsCompanion.insert(
          memoryId: id,
          collectionId: collectionId,
          // Sıra HER ZAMAN yazılıyor: canlı bir bağın yeri değişmiş olabilir.
          sortOrder: Value(index),
          updatedAt: Value(now),
          deletedAt: const Value(null),
          version: Value((existing?.version ?? 0) + 1),
        ),
      );
    }
  }

  Future<void> _syncMedia(
    String id,
    List<String> mediaIds,
    DateTime now,
  ) async {
    final current = await (select(
      memoryMedia,
    )..where((t) => t.memoryId.equals(id))).get();
    final byMedia = {for (final row in current) row.mediaId: row};

    for (final row in current) {
      if (row.deletedAt == null && !mediaIds.contains(row.mediaId)) {
        await (update(memoryMedia)..where(
              (t) => t.memoryId.equals(id) & t.mediaId.equals(row.mediaId),
            ))
            .write(
              MemoryMediaCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
                version: Value(row.version + 1),
              ),
            );
      }
    }

    for (final (index, mediaId) in mediaIds.indexed) {
      final existing = byMedia[mediaId];
      await into(memoryMedia).insertOnConflictUpdate(
        MemoryMediaCompanion.insert(
          memoryId: id,
          mediaId: mediaId,
          sortOrder: Value(index),
          updatedAt: Value(now),
          deletedAt: const Value(null),
          version: Value((existing?.version ?? 0) + 1),
        ),
      );
    }
  }

  /// Anı en fazla BİR seriye bağlı (`ritualId` tekil).
  Future<void> _syncRitual(
    String id,
    String? ritualId,
    int? ritualYear,
    DateTime now,
  ) async {
    final current = await (select(
      memoryRituals,
    )..where((t) => t.memoryId.equals(id))).get();

    for (final row in current) {
      if (row.deletedAt == null && row.ritualId != ritualId) {
        await (update(memoryRituals)..where(
              (t) => t.memoryId.equals(id) & t.ritualId.equals(row.ritualId),
            ))
            .write(
              MemoryRitualsCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
                version: Value(row.version + 1),
              ),
            );
      }
    }

    if (ritualId == null) return;

    final existing = current.where((r) => r.ritualId == ritualId).firstOrNull;
    await into(memoryRituals).insertOnConflictUpdate(
      MemoryRitualsCompanion.insert(
        memoryId: id,
        ritualId: ritualId,
        occurrenceYear: ritualYear ?? now.year,
        updatedAt: Value(now),
        deletedAt: const Value(null),
        version: Value((existing?.version ?? 0) + 1),
      ),
    );
  }

  /// FR-019 — favori işaretini değiştirir.
  Future<void> setFavorite(
    String id, {
    required bool isFavorite,
    required DateTime now,
    required String outboxId,
  }) => _patch(
    id,
    (row) => MemoriesCompanion(
      isFavorite: Value(isFavorite),
      updatedAt: Value(now),
      version: Value(row.version + 1),
    ),
    now: now,
    outboxId: outboxId,
  );

  /// FR-014 — arşivle.
  Future<void> setArchived(
    String id, {
    required bool isArchived,
    required DateTime now,
    required String outboxId,
  }) => _patch(
    id,
    (row) => MemoriesCompanion(
      isArchived: Value(isArchived),
      updatedAt: Value(now),
      version: Value(row.version + 1),
    ),
    now: now,
    outboxId: outboxId,
  );

  /// FR-015 — geri alınabilir silme ("çöp kutusu").
  /// Kayıt gitmez, `deletedAt` dolar. Rapor 12.2'deki tombstone yaklaşımı.
  Future<void> softDelete(
    String id, {
    required DateTime now,
    required String outboxId,
  }) => _patch(
    id,
    (row) => MemoriesCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
      version: Value(row.version + 1),
    ),
    now: now,
    outboxId: outboxId,
    // Sunucuya "sil" diye gitmezse ikinci cihaz silmeyi hiç öğrenmez.
    op: OutboxOperation.delete,
  );

  Future<void> restore(
    String id, {
    required DateTime now,
    required String outboxId,
  }) => _patch(
    id,
    (row) => MemoriesCompanion(
      // Value(null) = "bu sütunu NULL yap".
      // Value.absent() ise "bu sütuna dokunma" demektir — ikisini
      // karıştırmak Drift'te en sık yapılan hatadır.
      deletedAt: const Value(null),
      updatedAt: Value(now),
      version: Value(row.version + 1),
    ),
    now: now,
    outboxId: outboxId,
  );

  /// Çöp kutusunda [retention] süresini aşmış kayıtları kalıcı siler.
  /// Uygulama açılışında çalıştırılır.
  ///
  /// [now] DIŞARIDAN (TR-C-41): "30 gün doldu mu" kararı testte sabit bir
  /// ana göre verilebilsin.
  Future<int> purgeExpiredTrash({
    required DateTime now,
    Duration retention = const Duration(days: 30),
  }) {
    final cutoff = now.subtract(retention);
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
    MemoriesCompanion Function(MemoryRow current) build, {
    required DateTime now,
    required String outboxId,
    OutboxOperation op = OutboxOperation.update,
  }) {
    return transaction(() async {
      final current = await (select(
        memories,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (current == null) return;

      await (update(
        memories,
      )..where((t) => t.id.equals(id))).write(build(current));

      await _enqueue(
        id,
        op: op,
        baseVersion: current.version,
        outboxId: outboxId,
        now: now,
      );
    });
  }
}
