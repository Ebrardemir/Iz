// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_backfill_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncBackfillDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $LocationsTable get locations => attachedDatabase.locations;
  $MediaItemsTable get mediaItems => attachedDatabase.mediaItems;
  $MemoriesTable get memories => attachedDatabase.memories;
  $CollectionsTable get collections => attachedDatabase.collections;
  $RitualsTable get rituals => attachedDatabase.rituals;
  $PeopleTable get people => attachedDatabase.people;
  $MemoryPeopleTable get memoryPeople => attachedDatabase.memoryPeople;
  $MemoryCollectionsTable get memoryCollections =>
      attachedDatabase.memoryCollections;
  $MemoryRitualsTable get memoryRituals => attachedDatabase.memoryRituals;
  $RitualPeopleTable get ritualPeople => attachedDatabase.ritualPeople;
  $MemoryMediaTable get memoryMedia => attachedDatabase.memoryMedia;
  $JournalEntriesTable get journalEntries => attachedDatabase.journalEntries;
  $JournalMediaTable get journalMedia => attachedDatabase.journalMedia;
  $OutboxEntriesTable get outboxEntries => attachedDatabase.outboxEntries;
  SyncBackfillDaoManager get managers => SyncBackfillDaoManager(this);
}

class SyncBackfillDaoManager {
  final _$SyncBackfillDaoMixin _db;
  SyncBackfillDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$LocationsTableTableManager get locations =>
      $$LocationsTableTableManager(_db.attachedDatabase, _db.locations);
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db.attachedDatabase, _db.mediaItems);
  $$MemoriesTableTableManager get memories =>
      $$MemoriesTableTableManager(_db.attachedDatabase, _db.memories);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db.attachedDatabase, _db.collections);
  $$RitualsTableTableManager get rituals =>
      $$RitualsTableTableManager(_db.attachedDatabase, _db.rituals);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db.attachedDatabase, _db.people);
  $$MemoryPeopleTableTableManager get memoryPeople =>
      $$MemoryPeopleTableTableManager(_db.attachedDatabase, _db.memoryPeople);
  $$MemoryCollectionsTableTableManager get memoryCollections =>
      $$MemoryCollectionsTableTableManager(
        _db.attachedDatabase,
        _db.memoryCollections,
      );
  $$MemoryRitualsTableTableManager get memoryRituals =>
      $$MemoryRitualsTableTableManager(_db.attachedDatabase, _db.memoryRituals);
  $$RitualPeopleTableTableManager get ritualPeople =>
      $$RitualPeopleTableTableManager(_db.attachedDatabase, _db.ritualPeople);
  $$MemoryMediaTableTableManager get memoryMedia =>
      $$MemoryMediaTableTableManager(_db.attachedDatabase, _db.memoryMedia);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(
        _db.attachedDatabase,
        _db.journalEntries,
      );
  $$JournalMediaTableTableManager get journalMedia =>
      $$JournalMediaTableTableManager(_db.attachedDatabase, _db.journalMedia);
  $$OutboxEntriesTableTableManager get outboxEntries =>
      $$OutboxEntriesTableTableManager(_db.attachedDatabase, _db.outboxEntries);
}
