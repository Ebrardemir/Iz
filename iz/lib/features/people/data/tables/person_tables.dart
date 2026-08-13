import 'package:drift/drift.dart';
import 'package:iz/core/database/table_mixins.dart';
import 'package:iz/features/people/domain/entities/person.dart';

/// FR-060 — kullanıcının hayatındaki önemli kişiler/özneler.
@DataClassName('PersonRow')
class People extends Table with SyncableTable, OwnedTable {
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get kind =>
      textEnum<PersonKind>().withDefault(const Constant('human'))();
  TextColumn get relationType =>
      textEnum<RelationType>().withDefault(const Constant('other'))();

  DateTimeColumn get birthDate => dateTime().nullable()();
  TextColumn get avatarMediaId => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
}
