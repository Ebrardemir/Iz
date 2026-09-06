// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_dao.dart';

// ignore_for_file: type=lint
mixin _$CollectionDaoMixin on DatabaseAccessor<AppDatabase> {
  $CollectionsTable get collections => attachedDatabase.collections;
  $CategoriesTable get categories => attachedDatabase.categories;
  $LocationsTable get locations => attachedDatabase.locations;
  $MediaItemsTable get mediaItems => attachedDatabase.mediaItems;
  $MemoriesTable get memories => attachedDatabase.memories;
  $MemoryCollectionsTable get memoryCollections =>
      attachedDatabase.memoryCollections;
  CollectionDaoManager get managers => CollectionDaoManager(this);
}

class CollectionDaoManager {
  final _$CollectionDaoMixin _db;
  CollectionDaoManager(this._db);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db.attachedDatabase, _db.collections);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$LocationsTableTableManager get locations =>
      $$LocationsTableTableManager(_db.attachedDatabase, _db.locations);
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db.attachedDatabase, _db.mediaItems);
  $$MemoriesTableTableManager get memories =>
      $$MemoriesTableTableManager(_db.attachedDatabase, _db.memories);
  $$MemoryCollectionsTableTableManager get memoryCollections =>
      $$MemoryCollectionsTableTableManager(
        _db.attachedDatabase,
        _db.memoryCollections,
      );
}
