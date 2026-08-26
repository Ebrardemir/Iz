import 'package:drift/drift.dart';
import 'package:iz/core/database/table_mixins.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/media/data/tables/media_tables.dart';

/// FR-030 — belirli bir güne ait günlük kaydı.
@DataClassName('JournalEntryRow')
class JournalEntries extends Table with SyncableTable, OwnedTable {
  /// Saat bileşeni olmadan (gün bazlı). Takvim görünümü buna göre gruplar.
  DateTimeColumn get entryDate => dateTime()();

  /// DİKKAT: sütun adı `content`, `text` DEĞİL. `text` Drift'in sütun
  /// kurucu metodudur (`text()`), aynı adı sütuna veremezsin.
  /// Domain tarafında alan adı `text` olarak kalır; mapper çevirir.
  TextColumn get content => text().withDefault(const Constant(''))();

  /// Kullanıcının bugüne verdiği ad. Opsiyonel — günlük serbest yazılıyor.
  TextColumn get title => text().nullable()();

  /// FR-030 — bugünkü ruh hâli, 1..10. null = işaretlenmedi.
  IntColumn get moodScore => integer().nullable()();

  /// FR-032/FR-036 — prompt kütüphanesi referansı.
  TextColumn get promptId => text().nullable()();

  TextColumn get moodKey => text().nullable()();

  /// Yıldızlanan yazılar. Anıdaki favoriden AYRI bir alan.
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// FR-035 — gizlilik modu.
  TextColumn get privacyMode =>
      textEnum<JournalPrivacyMode>().withDefault(const Constant('standard'))();

  /// FR-034 — anıya dönüştürüldüyse hedef anı. BR-011: bağ kurar, silmez.
  TextColumn get convertedMemoryId => text().nullable()();
}

/// Günlük ↔ medya bağı (FR-031).
/// TERS YÖN İNDEKSİ — bkz. memory_tables.dart'taki aynı gerekçe.
@DataClassName('JournalMediaRow')
@TableIndex(name: 'idx_journal_media_media', columns: {#mediaId})
class JournalMedia extends Table {
  TextColumn get journalEntryId =>
      text().references(JournalEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get mediaId =>
      text().references(MediaItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {journalEntryId, mediaId};
}
