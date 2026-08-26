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
import 'package:iz/features/categories/data/tables/category_tables.dart';
import 'package:iz/features/categories/domain/entities/memory_category.dart';
import 'package:iz/features/collections/data/tables/collection_tables.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/journal/data/tables/journal_tables.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/media/data/tables/media_tables.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/data/daos/memory_dao.dart';
import 'package:iz/features/memories/data/tables/memory_tables.dart';
import 'package:iz/features/people/data/tables/person_tables.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/rituals/data/tables/ritual_tables.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';

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
    MemoryMedia,
    // Günlük
    JournalEntries,
    JournalMedia,
  ],
  daos: [MemoryDao],
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

  /// ŞEMA SÜRÜMÜ — her şema değişikliğinde artır.
  /// Artırmayı unutursan kullanıcının cihazındaki eski şema olduğu gibi
  /// kalır ve uygulama "no such column" hatasıyla çöker.
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // FR-070 — varsayılan kategorileri tohumla.
      await _seedDefaultCategories();
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
