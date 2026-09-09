// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_state_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncStateDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncStateTable get syncState => attachedDatabase.syncState;
  $SyncConflictsTable get syncConflicts => attachedDatabase.syncConflicts;
  SyncStateDaoManager get managers => SyncStateDaoManager(this);
}

class SyncStateDaoManager {
  final _$SyncStateDaoMixin _db;
  SyncStateDaoManager(this._db);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db.attachedDatabase, _db.syncState);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db.attachedDatabase, _db.syncConflicts);
}
