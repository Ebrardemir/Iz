import 'package:drift/drift.dart';
import 'package:iz/core/database/table_mixins.dart';
import 'package:iz/features/people/data/tables/person_tables.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';

/// FR-075 — tekrarlanan olayları yıllar bazında ilişkilendirir.
@DataClassName('RitualRow')
class Rituals extends Table with SyncableTable, OwnedTable {
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get recurrenceType =>
      textEnum<RecurrenceType>().withDefault(const Constant('yearly'))();

  IntColumn get anchorMonth => integer().nullable()();
  IntColumn get anchorDay => integer().nullable()();
  TextColumn get iconKey => text().withDefault(const Constant('ritual'))();
}

/// FR-064 — seri ↔ kişi bağı, ÇOKLU.
///
/// NEDEN AYRI TABLO, `Rituals.relatedPersonId` DEĞİL?
/// Bir seri birden fazla kişiyle paylaşılıyor: "Aile Yemeklerimiz"in bir
/// değil birkaç sahibi var. Tekil sütun bu gerçeği taşıyamıyordu ve form
/// çoklu seçim gösterip tekil kaydetmek zorunda kalıyordu.
///
/// TERS YÖN İNDEKSİ — NEDEN GEREKLİ?
/// Birincil anahtar `(ritualId, personId)`. SQLite bileşik anahtarı yalnız
/// SOLDAN eşleştirir: `ritualId` ile sorgu indeksi kullanır, `personId` ile
/// sorgu TAM TARAMA yapar. Ama kişi detayı "bu kişinin serileri" diye tam
/// ters yönde soruyor.
@DataClassName('RitualPersonRow')
@TableIndex(name: 'idx_ritual_people_person', columns: {#personId})
class RitualPeople extends Table with SyncableLink {
  TextColumn get ritualId =>
      text().references(Rituals, #id, onDelete: KeyAction.cascade)();
  TextColumn get personId =>
      text().references(People, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {ritualId, personId};
}
