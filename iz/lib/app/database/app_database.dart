/// Veritabanı **composition root**'u.
///
/// MİMARİ NOTU:
/// `core/` katmanı hiçbir feature'ı bilmez — bu kural bilinçlidir.
/// Ama Drift'in tek bir `@DriftDatabase` sınıfında TÜM tabloları görmesi
/// gerekir. Bu yüzden veritabanı sınıfı `core/`de değil, `app/`de yaşar:
/// `app/` katmanı her şeyi bilmeye yetkili tek katmandır (router da öyle).
///
/// YENİ TABLO EKLERKEN:
///   1. Tabloyu ilgili feature'ın `data/tables/` klasöründe tanımla
///   2. Aşağıdaki `tables:` listesine ekle
///   3. `schemaVersion`i +1 yap
///   4. `migration` içine yeni sürüm adımını yaz
///   5. `dart run build_runner build` çalıştır
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// DİKKAT — Üretilen `app_database.g.dart` bu dosyanın `part`'ıdır ve
// bu dosyanın import'larını kullanır. Tablolarda `textEnum<X>()` ile
// kullandığın HER domain enum'unu buraya da import etmelisin (aşağıdaki
// `domain/entities/...` satırları), yoksa üretilen kod
// "X isn't a type" hatasıyla derlenmez.
//
// (`flutter analyze` bunu YAKALAMAZ: analysis_options.yaml `*.g.dart`
//  dosyalarını hariç tutar. Hata ancak `flutter test`/`flutter run`
//  sırasında görünür.)
import 'package:iz/core/database/owner_scope.dart';
import 'package:iz/features/auth/data/tables/user_tables.dart';
import 'package:iz/features/categories/data/daos/category_dao.dart';
import 'package:iz/features/categories/data/tables/category_tables.dart';
import 'package:iz/features/categories/domain/entities/memory_category.dart';
import 'package:iz/features/collections/data/daos/collection_dao.dart';
import 'package:iz/features/collections/data/tables/collection_tables.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/journal/data/daos/journal_dao.dart';
import 'package:iz/features/journal/data/tables/journal_tables.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/media/data/daos/media_dao.dart';
import 'package:iz/features/media/data/tables/media_tables.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/data/daos/memory_dao.dart';
import 'package:iz/features/memories/data/tables/memory_tables.dart';
import 'package:iz/features/people/data/daos/person_dao.dart';
import 'package:iz/features/people/data/tables/person_tables.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/rituals/data/daos/ritual_dao.dart';
import 'package:iz/features/rituals/data/tables/ritual_tables.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/features/sync/data/daos/sync_backfill_dao.dart';
import 'package:iz/features/sync/data/daos/sync_dao.dart';
import 'package:iz/features/sync/data/daos/sync_state_dao.dart';
import 'package:iz/features/sync/data/tables/sync_tables.dart';
import 'package:iz/features/sync/domain/entities/outbox_operation.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // Çekirdek
    Memories,
    Locations,
    MediaItems,
    // Organizasyon
    Categories,
    Collections,
    Rituals,
    People,
    // N-N ilişkiler
    MemoryPeople,
    MemoryCollections,
    MemoryRituals,
    RitualPeople,
    MemoryMedia,
    // Günlük
    JournalEntries,
    JournalMedia,
    // Hesap
    Users,
    // Senkronizasyon defterleri — yerel, asla senkronize edilmez
    OutboxEntries,
    SyncState,
    SyncConflicts,
  ],
  daos: [
    MemoryDao,
    PersonDao,
    CollectionDao,
    MediaDao,
    RitualDao,
    CategoryDao,
    JournalDao,
    // Senkronizasyon: uzak satiri yerele yazan tek yer.
    SyncDao,
    SyncStateDao,
    SyncBackfillDao,
  ],
  // FTS5 sanal tablosu ve trigger'ları SQL ile tanımlanır (Dart API'si
  // sanal tabloyu ifade edemez).
  include: {'package:iz/features/search/data/search.drift'},
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Testler için bellek içi veritabanı:
  /// ```dart
  /// final db = AppDatabase.forTesting(NativeDatabase.memory());
  /// ```
  AppDatabase.forTesting(super.executor);

  /// AKTİF HESAP — sahipli tablolardaki her okumanın kapsamı.
  ///
  /// Veritabanının kendisinde duruyor çünkü süzgeci uygulayan yer DAO'lar ve
  /// onlar veritabanına `attachedDatabase` ile zaten erişiyor. Ayrı bir
  /// provider'dan geçirseydik her DAO'nun kurucusuna bir parametre eklemek
  /// gerekirdi; eklenmeyen tek DAO da sessizce süzgeçsiz kalırdı.
  final ownerScope = OwnerScope();

  /// ŞEMA SÜRÜMÜ — her şema değişikliğinde artır.
  /// Artırmayı unutursan kullanıcının cihazındaki eski şema olduğu gibi
  /// kalır ve uygulama "no such column" hatasıyla çöker.
  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // FR-070 — varsayılan kategorileri tohumla.
      await _seedDefaultCategories();
      // TR-M1-01 — `ownerId` varsayılanının işaret ettiği satır.
      await _seedLocalUser();
    },

    onUpgrade: (m, from, to) async {
      // KURAL: Eski adımları ASLA silme/değiştirme. Kullanıcı v1'den
      // v5'e atlayabilir ve tüm adımların sırayla çalışması gerekir.

      if (from < 2) {
        // v2 — anı indeksleri (NFR-003). Sütun değişmiyor, yalnızca indeks
        // ekleniyor; veri dönüşümü gerekmiyor.
        //
        // Gerekçeler memory_tables.dart'taki `@TableIndex` yorumlarında.
        // `createIndex` yeni kurulumlarda `createAll()` tarafından zaten
        // çalıştırılıyor; bu adım YÜKSELTEN cihazlar için.
        await m.createIndex(idxMemoriesOccurredAt);
        await m.createIndex(idxMemoriesOnThisDay);
      }

      if (from < 3) {
        // v3 — günlük kaydına başlık ve ruh hâli puanı (FR-030).
        //
        // İkisi de NULLABLE: var olan kayıtlarda karşılığı yok ve olmaması
        // bir eksiklik değil ("işaretlemedim" geçerli bir durum). Bu yüzden
        // veri dönüşümü gerekmiyor, yalnızca sütun ekleniyor.
        await m.addColumn(journalEntries, journalEntries.title);
        await m.addColumn(journalEntries, journalEntries.moodScore);
      }

      if (from < 4) {
        // v4 — günlük yazılarının yıldızı. Varsayılanı false olan bir sütun;
        // var olan kayıtlar yıldızsız kalıyor ve bu doğru olan.
        await m.addColumn(journalEntries, journalEntries.isFavorite);
      }

      if (from < 5) {
        // v5 — TERS YÖN İNDEKSLERİ.
        //
        // Join tablolarının birincil anahtarı `(memoryId, xId)` biçiminde.
        // SQLite bileşik anahtarı yalnız SOLDAN eşleştirir: `memoryId` ile
        // yapılan sorgu indeksi kullanır, `xId` ile yapılan sorgu TAM TARAMA
        // yapar. Oysa kişi yaşam çizgisi, ritüel yıl karşılaştırması ve
        // koleksiyon detayı tam da ters yönde sorguluyor.
        //
        // Sütun eklenmiyor, veri dönüşmüyor — yalnız indeks kuruluyor.
        // Yeni kurulumlarda bunları `createAll()` zaten oluşturuyor;
        // bu adım YÜKSELTEN cihazlar için.
        await m.createIndex(idxMemoryPeoplePerson);
        await m.createIndex(idxMemoryCollectionsCollection);
        await m.createIndex(idxMemoryRitualsRitual);
        await m.createIndex(idxMemoryMediaMedia);
        await m.createIndex(idxJournalMediaMedia);

        // FR-091 — filtre panelinin en sık kullandığı sütun.
        await m.createIndex(idxMemoriesCategory);
      }

      if (from < 6) {
        // v6 — kişinin KENDİ YAZDIĞI ilişki adı ("Annem", "Kankam").
        //
        // Alan `Person` entity'sinde ve arayüzde baştan beri vardı; eksik
        // olan yalnız sütundu. Yani editörde yazılan metin kaydedilirken
        // sessizce düşüyordu. Veri katmanı yazılırken fark edildi.
        //
        // NULLABLE: var olan kayıtlarda karşılığı yok ve olmaması bir
        // eksiklik değil — o kişiler için ekranda `relationType`ın çevirisi
        // gösterilmeye devam eder (bkz. person_l10n.dart).
        await m.addColumn(people, people.relationLabel);
      }

      if (from < 7) {
        // v7 — SERİ ↔ KİŞİ ÇOKLU OLDU.
        //
        // `Rituals.relatedPersonId` tekildi ama bir seri birden fazla kişiyle
        // paylaşılıyor ("Aile Yemeklerimiz"). Form da çoklu seçim gösterip
        // tekil kaydetmek zorunda kalıyordu.
        //
        // SIRA ÖNEMLİ: önce yeni tablo kuruluyor, sonra VAR OLAN VERİ
        // taşınıyor, en sonda eski sütun düşüyor. Tersi olsaydı kullanıcının
        // seçtiği kişi kaybolurdu.
        await m.createTable(ritualPeople);
        await m.createIndex(idxRitualPeoplePerson);

        // Eski tekil bağı yeni tabloya kopyala. Ham SQL: `relatedPersonId`
        // artık Dart tarafında YOK (sütun tanımından kalktı), yani Drift'in
        // tip güvenli sorgusuyla okunamıyor.
        await customStatement(
          'INSERT OR IGNORE INTO ritual_people (ritual_id, person_id) '
          'SELECT id, related_person_id FROM rituals '
          'WHERE related_person_id IS NOT NULL',
        );

        // Sütunu düşürmek SQLite'ta tablo yeniden kurmayı gerektiriyor;
        // Drift bunu `TableMigration` ile yapıyor.
        await m.alterTable(TableMigration(rituals));
      }

      if (from < 8) {
        // v8 — SENKRONİZASYON HAZIRLIĞI. Görünür hiçbir özellik üretmiyor;
        // Faz 3'ün ön koşulu (yol haritası Faz 2).
        //
        // (a) BAĞ TABLOLARI ARTIK TOMBSTONE TAŞIYOR.
        //
        // Bağı gerçekten silersek ikinci cihaz o satırı hiç görmez ve
        // "bende var, sende yok" durumunu "sen henüz almamışsın" diye
        // okur — çıkarılan kişiyi geri ekler (rapor §1.1). Silmeyi bir
        // SATIR olarak saklamak bunun tek çaresi.
        //
        // Üç sütunun da varsayılanı var, yani var olan bağlar olduğu gibi
        // kalıyor: `deletedAt` null (bağ duruyor), `version` 1.
        // TABLO YENİDEN KURULARAK, `ALTER TABLE ADD COLUMN` ile DEĞİL.
        //
        // `updatedAt`in varsayılanı `CURRENT_TIMESTAMP` ve SQLite sabit
        // olmayan varsayılanı olan bir sütunu ALTER ile eklemeyi reddediyor
        // ("Cannot add a column with non-constant default"). Drift'in
        // `TableMigration`ı tabloyu bugünkü tanımıyla yeniden kurup veriyi
        // kopyalıyor; bileşik anahtar ve yabancı anahtarlar korunuyor.
        //
        // VAR OLAN SATIRLARA NE YAZILIYOR: `updatedAt`e migration ANI.
        // Doğru olan bu — bağın gerçekte ne zaman kurulduğunu bilmiyoruz ve
        // uydurmak yerine "bu kaydı en son burada gördük" demek, ilk
        // eşitlemede sunucunun kararını bozmuyor.
        // Her tablo TEK TEK: `newColumns` o tablonun kendi sütunlarını
        // istiyor ve ortak bir yardımcıya sığmıyor.
        await m.alterTable(
          TableMigration(
            memoryPeople,
            newColumns: [
              memoryPeople.updatedAt,
              memoryPeople.deletedAt,
              memoryPeople.version,
            ],
          ),
        );
        await m.alterTable(
          TableMigration(
            memoryCollections,
            newColumns: [
              memoryCollections.updatedAt,
              memoryCollections.deletedAt,
              memoryCollections.version,
            ],
          ),
        );
        await m.alterTable(
          TableMigration(
            memoryRituals,
            newColumns: [
              memoryRituals.updatedAt,
              memoryRituals.deletedAt,
              memoryRituals.version,
            ],
          ),
        );
        await m.alterTable(
          TableMigration(
            memoryMedia,
            newColumns: [
              memoryMedia.updatedAt,
              memoryMedia.deletedAt,
              memoryMedia.version,
            ],
          ),
        );
        await m.alterTable(
          TableMigration(
            journalMedia,
            newColumns: [
              journalMedia.updatedAt,
              journalMedia.deletedAt,
              journalMedia.version,
            ],
          ),
        );

        // ⚠️ `ritual_people` YALNIZ v7'DEN GELİYORSA dokunuluyor.
        //
        // `createTable` her zaman tablonun BUGÜNKÜ tanımını kuruyor. Yani
        // v6'dan yükselen bir cihazda yukarıdaki v7 adımı tabloyu zaten
        // yeni sütunlarıyla açtı; yeniden kurmak gereksiz iş olurdu.
        //
        // Bu tuzak `createTable` içeren HER migration'da tekrar edecek.
        if (from >= 7) {
          await m.alterTable(
            TableMigration(
              ritualPeople,
              newColumns: [
                ritualPeople.updatedAt,
                ritualPeople.deletedAt,
                ritualPeople.version,
              ],
            ),
          );
        }

        // (b) HESAP TABLOSU.
        //
        // Giriş hâlâ yerel ama tabloyu şimdi kuruyoruz: `ownerId`
        // varsayılanı olan `'local'`ın işaret edeceği satır bugünden var
        // olsun (TR-M1-01). Hesap açıldığı gün yapılacak iş bir satırı
        // güncellemek olacak, binlerce `ownerId`yi taşımak değil.
        await m.createTable(users);
        await _seedLocalUser();

        // (c) SENKRONİZASYON DEFTERLERİ. Kuruluyor, henüz kimse okumuyor.
        await m.createTable(outboxEntries);
        await m.createIndex(idxOutboxCreated);
        await m.createTable(syncState);
        await m.createTable(syncConflicts);
        await m.createIndex(idxSyncConflictsUnresolved);
      }
    },

    beforeOpen: (details) async {
      // Foreign key kısıtları SQLite'ta VARSAYILAN OLARAK KAPALIDIR.
      // Açmazsak `references(...)` tanımlarımız sessizce hiçbir şey yapmaz
      // ve cascade silme çalışmaz.
      await customStatement('PRAGMA foreign_keys = ON');

      // NFR-004: yazma işlemleri güvenli olmalı. WAL modu eşzamanlı
      // okuma/yazmayı hızlandırır ve çökme dayanıklılığı sağlar.
      await customStatement('PRAGMA journal_mode = WAL');

      if (details.wasCreated) {
        // İlk kurulumda FTS indeksi zaten boş; bir şey yapmaya gerek yok.
      }
    },
  );

  /// Hesabı olmayan kullanıcının satırı.
  ///
  /// `OwnedTable.ownerId`nin varsayılanı `'local'`; bu satır olmasaydı
  /// yabancı anahtar hiçbir şeye işaret etmezdi.
  Future<void> _seedLocalUser() async {
    await into(users).insert(
      UsersCompanion.insert(id: Users.localId),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> _seedDefaultCategories() async {
    await batch((b) {
      b.insertAll(categories, [
        for (final (index, c) in DefaultCategories.seed.indexed)
          CategoriesCompanion.insert(
            id: c.id,
            // Sistem kategorilerinde `name` sütununa AD değil çeviri
            // ANAHTARI yazılır — bkz. MemoryCategory.name açıklaması.
            name: c.nameKey,
            iconKey: Value(c.iconKey),
            sortOrder: Value(index),
            isSystem: const Value(true),
          ),
      ]);
    });
  }
}

/// Uygulama veritabanı dosyasını açar.
///
/// `drift_flutter` doğru platform dizinini (iOS/Android app sandbox) seçer;
/// dosya kullanıcının paylaşılan alanına değil, uygulamaya özel alana yazılır
/// — NFR-012 (içerik varsayılan private) ile uyumlu.
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'iz_db',
    native: const DriftNativeOptions(
      // Veritabanını ayrı bir isolate'te çalıştırır: ağır sorgular
      // UI thread'ini kilitlemez (NFR-001/NFR-003).
      shareAcrossIsolates: true,
    ),
  );
}

/// Uygulama boyunca tek veritabanı örneği.
///
/// `ref.onDispose` ile kapanışı bağlıyoruz; testlerde container
/// dispose edilince bağlantı da kapanır (sızıntı olmaz).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Sahipli tablolarda AKTİF HESABIN kapsamı.
///
/// KURAL: sahipli bir tablodan (`OwnedTable`) okuyan her sorgu bu süzgeçten
/// geçmek ZORUNDA. `select(memories)` yazmak serbest bırakılsaydı, unutulan
/// tek sorgu sızıntının devam etmesi demek olurdu — bu yüzden çıplak
/// kullanım CI'da yasak (`test/unit/sahip_suzgeci_test.dart`).
extension OwnerScopedQueries on DatabaseAccessor<AppDatabase> {
  /// Sahipli tablodan YALNIZ aktif hesabın satırlarını seçer.
  ///
  /// `select(...)` yerine bunu çağır. Sahip sütunu açıkça geçiliyor çünkü
  /// `OwnedTable` bir mixin: Drift her tabloya kendi `ownerId` sütununu
  /// üretiyor ve hepsini kapsayan ortak bir arayüz yok.
  SimpleSelectStatement<T, D> selectOwned<T extends HasResultSet, D>(
    ResultSetImplementation<T, D> tablo,
    GeneratedColumn<String> sahip,
  ) => select(tablo)..where((_) => ownedBy(sahip));

  /// Aynı süzgecin İFADE hâli — join kuran ya da `selectOnly` kullanan
  /// sorgular `selectOwned`ı kullanamıyor, süzgeci elle ekliyorlar.
  Expression<bool> ownedBy(GeneratedColumn<String> sahip) =>
      sahip.equals(activeOwnerId);

  /// Yeni yazılan satırın sahibi.
  ///
  /// YAZMA ANINDA damgalanıyor, sonradan düzeltilmiyor. Satır varsayılan
  /// `'local'` ile yazılsaydı, hesaplı kullanıcı kaydettiği anıyı ANINDA
  /// kaybederdi: süzgeç onu kendi kapsamının dışında sayardı.
  String get activeOwnerId => attachedDatabase.ownerScope.current;
}
