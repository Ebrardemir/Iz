import 'package:drift/drift.dart';
import 'package:iz/core/database/table_mixins.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';

/// FR-073 — kullanıcı tanımlı olay/dönem grubu.
@DataClassName('CollectionRow')
class Collections extends Table with SyncableTable, OwnedTable {
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get description => text().nullable()();
  TextColumn get coverMediaId => text().nullable()();

  /// BR-003 — varsayılan private.
  TextColumn get visibility =>
      textEnum<CollectionVisibility>().withDefault(const Constant('private'))();

  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
}
