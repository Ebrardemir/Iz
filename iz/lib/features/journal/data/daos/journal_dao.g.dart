// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_dao.dart';

// ignore_for_file: type=lint
mixin _$JournalDaoMixin on DatabaseAccessor<AppDatabase> {
  $JournalEntriesTable get journalEntries => attachedDatabase.journalEntries;
  $MediaItemsTable get mediaItems => attachedDatabase.mediaItems;
  $JournalMediaTable get journalMedia => attachedDatabase.journalMedia;
  JournalDaoManager get managers => JournalDaoManager(this);
}

class JournalDaoManager {
  final _$JournalDaoMixin _db;
  JournalDaoManager(this._db);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(
        _db.attachedDatabase,
        _db.journalEntries,
      );
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db.attachedDatabase, _db.mediaItems);
  $$JournalMediaTableTableManager get journalMedia =>
      $$JournalMediaTableTableManager(_db.attachedDatabase, _db.journalMedia);
}
