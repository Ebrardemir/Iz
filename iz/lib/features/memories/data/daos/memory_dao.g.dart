// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_dao.dart';

// ignore_for_file: type=lint
mixin _$MemoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $LocationsTable get locations => attachedDatabase.locations;
  $MediaItemsTable get mediaItems => attachedDatabase.mediaItems;
  $MemoriesTable get memories => attachedDatabase.memories;
  $MemoryMediaTable get memoryMedia => attachedDatabase.memoryMedia;
  $PeopleTable get people => attachedDatabase.people;
  $MemoryPeopleTable get memoryPeople => attachedDatabase.memoryPeople;
  $CollectionsTable get collections => attachedDatabase.collections;
  $MemoryCollectionsTable get memoryCollections =>
      attachedDatabase.memoryCollections;
  $RitualsTable get rituals => attachedDatabase.rituals;
  $MemoryRitualsTable get memoryRituals => attachedDatabase.memoryRituals;
  MemoryDaoManager get managers => MemoryDaoManager(this);
}

class MemoryDaoManager {
  final _$MemoryDaoMixin _db;
  MemoryDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$LocationsTableTableManager get locations =>
      $$LocationsTableTableManager(_db.attachedDatabase, _db.locations);
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db.attachedDatabase, _db.mediaItems);
  $$MemoriesTableTableManager get memories =>
      $$MemoriesTableTableManager(_db.attachedDatabase, _db.memories);
  $$MemoryMediaTableTableManager get memoryMedia =>
      $$MemoryMediaTableTableManager(_db.attachedDatabase, _db.memoryMedia);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db.attachedDatabase, _db.people);
  $$MemoryPeopleTableTableManager get memoryPeople =>
      $$MemoryPeopleTableTableManager(_db.attachedDatabase, _db.memoryPeople);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db.attachedDatabase, _db.collections);
  $$MemoryCollectionsTableTableManager get memoryCollections =>
      $$MemoryCollectionsTableTableManager(
        _db.attachedDatabase,
        _db.memoryCollections,
      );
  $$RitualsTableTableManager get rituals =>
      $$RitualsTableTableManager(_db.attachedDatabase, _db.rituals);
  $$MemoryRitualsTableTableManager get memoryRituals =>
      $$MemoryRitualsTableTableManager(_db.attachedDatabase, _db.memoryRituals);
}
