// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ritual_dao.dart';

// ignore_for_file: type=lint
mixin _$RitualDaoMixin on DatabaseAccessor<AppDatabase> {
  $RitualsTable get rituals => attachedDatabase.rituals;
  $CategoriesTable get categories => attachedDatabase.categories;
  $LocationsTable get locations => attachedDatabase.locations;
  $MediaItemsTable get mediaItems => attachedDatabase.mediaItems;
  $MemoriesTable get memories => attachedDatabase.memories;
  $MemoryRitualsTable get memoryRituals => attachedDatabase.memoryRituals;
  $PeopleTable get people => attachedDatabase.people;
  $RitualPeopleTable get ritualPeople => attachedDatabase.ritualPeople;
  RitualDaoManager get managers => RitualDaoManager(this);
}

class RitualDaoManager {
  final _$RitualDaoMixin _db;
  RitualDaoManager(this._db);
  $$RitualsTableTableManager get rituals =>
      $$RitualsTableTableManager(_db.attachedDatabase, _db.rituals);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$LocationsTableTableManager get locations =>
      $$LocationsTableTableManager(_db.attachedDatabase, _db.locations);
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db.attachedDatabase, _db.mediaItems);
  $$MemoriesTableTableManager get memories =>
      $$MemoriesTableTableManager(_db.attachedDatabase, _db.memories);
  $$MemoryRitualsTableTableManager get memoryRituals =>
      $$MemoryRitualsTableTableManager(_db.attachedDatabase, _db.memoryRituals);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db.attachedDatabase, _db.people);
  $$RitualPeopleTableTableManager get ritualPeople =>
      $$RitualPeopleTableTableManager(_db.attachedDatabase, _db.ritualPeople);
}
