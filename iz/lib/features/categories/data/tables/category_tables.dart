import 'package:drift/drift.dart';
import 'package:iz/core/database/table_mixins.dart';

/// FR-070/071 — sistem + kullanıcı kategorileri.
@DataClassName('CategoryRow')
class Categories extends Table with SyncableTable, OwnedTable {
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get iconKey => text().withDefault(const Constant('daily'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Sistem kategorileri silinemez (FR-070).
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
}
