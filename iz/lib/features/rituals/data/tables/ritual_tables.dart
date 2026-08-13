import 'package:drift/drift.dart';
import 'package:iz/core/database/table_mixins.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';

/// FR-075 — tekrarlanan olayları yıllar bazında ilişkilendirir.
@DataClassName('RitualRow')
class Rituals extends Table with SyncableTable, OwnedTable {
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get recurrenceType =>
      textEnum<RecurrenceType>().withDefault(const Constant('yearly'))();

  /// FR-064 — kişiye bağlı ritüel.
  TextColumn get relatedPersonId => text().nullable()();

  IntColumn get anchorMonth => integer().nullable()();
  IntColumn get anchorDay => integer().nullable()();
  TextColumn get iconKey => text().withDefault(const Constant('ritual'))();
}
