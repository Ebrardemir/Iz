/// Anı tabloları ve N-N ilişki tabloları.
///
/// Rapor 7.6: "Derin klasör yapısı yerine çok boyutlu düzenleme önerilir.
/// 'Aile > Annem > Tatiller > Yaz > Antalya > 2026' gibi hiyerarşiler zamanla
/// yönetilemez hâle gelir."
///
/// Bu yüzden şema hiyerarşik değil **ilişkisel**: bir anı aynı anda birden
/// çok kişiye, koleksiyona ve bir ritüele bağlanabilir. Aşağıdaki join
/// tabloları bunu sağlar.
library;

import 'package:drift/drift.dart';
import 'package:iz/core/database/table_mixins.dart';
import 'package:iz/features/categories/data/tables/category_tables.dart';
import 'package:iz/features/collections/data/tables/collection_tables.dart';
import 'package:iz/features/media/data/tables/media_tables.dart';
import 'package:iz/features/people/data/tables/person_tables.dart';
import 'package:iz/features/rituals/data/tables/ritual_tables.dart';

/// Rapor 12: Memory — temel Anı nesnesi.
///
/// İNDEKSLER — NEDEN BUNLAR?
/// Şema bir süre indekssiz kaldı: yorumda "indeks şart" yazıyordu ama
/// karşılığı yoktu. NFR-003 (yüzlerce anıyla akıcı liste) tam olarak bu iki
/// sorguya bağlı:
///
///   • `idx_memories_occurred_at` → timeline HER ZAMAN `occurredAt`e göre
///     sıralanıyor (bkz. MemoryDao.watchMemories). İndeks olmadan SQLite her
///     açılışta tüm tabloyu okuyup belleğe alarak sıralar.
///     `deletedAt` de içinde: liste sorgusu onu her koşulda filtreliyor,
///     ikisi bir aradayken indeks tek başına yetiyor.
///
///   • `idx_memories_on_this_day` → FR-080 "Bugünün İzi" ay+gün eşitliğiyle
///     arıyor (bkz. MemoryDao.findOnThisDay). Bu sorgu uygulama AÇILIŞINDA
///     çalışıyor; tarama maliyeti doğrudan açılış süresine yazılır.
@DataClassName('MemoryRow')
@TableIndex(
  name: 'idx_memories_occurred_at',
  columns: {#occurredAt, #deletedAt},
)
@TableIndex(
  name: 'idx_memories_on_this_day',
  columns: {#occurredMonth, #occurredDay},
)
class Memories extends Table with SyncableTable, OwnedTable {
  TextColumn get title => text().nullable().withLength(max: 200)();
  TextColumn get note => text().nullable()();

  /// FR-013 — anının GERÇEKTEN yaşandığı tarih. Timeline bunu kullanır.
  /// `createdAt` ise kaydın ne zaman girildiği; ikisi çok farklı olabilir.
  DateTimeColumn get occurredAt => dateTime()();

  // --- Bilinçli denormalizasyon: yerel tarih parçaları ------------------
  //
  // NEDEN? Drift, DateTime'ı UTC ISO-8601 metni olarak saklar. Türkiye'de
  // 26 Temmuz 00:30'da yaşanan bir anı UTC'de 25 Temmuz 21:30 olur.
  // "Bugünün İzi" (FR-080) ve ritüel yıl karşılaştırması (FR-076) yerel
  // takvim gününe göre çalışmalı — yoksa anı yanlış güne düşer.
  //
  // Bu üç sütun anının YEREL tarihini taşır; sorgular tamamen tip güvenli
  // tamsayı karşılaştırmasına indirgenir ve indekslenebilir.
  // Mapper her yazmada doldurur (bkz. MemoryMapper.toCompanion).
  IntColumn get occurredYear => integer()();
  IntColumn get occurredMonth => integer()();
  IntColumn get occurredDay => integer()();

  /// FR-017 — bir anı TEK kategoriye bağlanır (koleksiyon ise çoklu).
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  TextColumn get locationId => text().nullable().references(Locations, #id)();

  /// FR-018 — kapak görseli.
  TextColumn get coverMediaId =>
      text().nullable().references(MediaItems, #id)();

  BoolColumn get isFavorite =>
      boolean().withDefault(const Constant(false))(); // FR-019
  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false))(); // FR-014

  /// FR-034 — bu anı bir günlük kaydından mı üretildi?
  /// BR-011: dönüşüm orijinal günlük kaydını silmez, bağ kurar.
  TextColumn get sourceJournalEntryId => text().nullable()();
}

/// Rapor 12: Location.
@DataClassName('LocationRow')
class Locations extends Table with SyncableTable {
  TextColumn get label => text().withLength(min: 1, max: 200)();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get country => text().nullable()();
}

// ---------------------------------------------------------------------------
// N-N İLİŞKİ TABLOLARI
//
// Bunlar SyncableTable kullanmaz: kendi başlarına bir "kayıt" değil,
// iki kayıt arasındaki bağdır. Birleşik birincil anahtar kullanırlar.
// ---------------------------------------------------------------------------

/// FR-016 / BR-001: bir anı birden fazla kişiyle ilişkilendirilebilir;
/// anının kopyaları kişi profillerinde çoğaltılmaz.
@DataClassName('MemoryPersonRow')
class MemoryPeople extends Table {
  TextColumn get memoryId =>
      text().references(Memories, #id, onDelete: KeyAction.cascade)();
  TextColumn get personId =>
      text().references(People, #id, onDelete: KeyAction.cascade)();

  /// Opsiyonel rol ("fotoğrafı çeken", "doğum günü sahibi").
  TextColumn get role => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {memoryId, personId};
}

/// FR-074 — bir anı birden fazla koleksiyona bağlanabilir.
@DataClassName('MemoryCollectionRow')
class MemoryCollections extends Table {
  TextColumn get memoryId =>
      text().references(Memories, #id, onDelete: KeyAction.cascade)();
  TextColumn get collectionId =>
      text().references(Collections, #id, onDelete: KeyAction.cascade)();

  /// Koleksiyon içi elle sıralama (kitap taslağı için önemli).
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {memoryId, collectionId};
}

/// BR-012 — anı ↔ ritüel bağı, hangi yılın tekrarı olduğu bilgisiyle.
/// FR-076'daki "yılları yan yana karşılaştırma" bu sütuna dayanır.
@DataClassName('MemoryRitualRow')
class MemoryRituals extends Table {
  TextColumn get memoryId =>
      text().references(Memories, #id, onDelete: KeyAction.cascade)();
  TextColumn get ritualId =>
      text().references(Rituals, #id, onDelete: KeyAction.cascade)();
  IntColumn get occurrenceYear => integer()();

  @override
  Set<Column<Object>> get primaryKey => {memoryId, ritualId};
}

/// Anı ↔ medya, sırasıyla birlikte.
@DataClassName('MemoryMediaRow')
class MemoryMedia extends Table {
  TextColumn get memoryId =>
      text().references(Memories, #id, onDelete: KeyAction.cascade)();
  TextColumn get mediaId =>
      text().references(MediaItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {memoryId, mediaId};
}
