// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_dao.dart';

// ignore_for_file: type=lint
mixin _$MediaDaoMixin on DatabaseAccessor<AppDatabase> {
  $MediaItemsTable get mediaItems => attachedDatabase.mediaItems;
  MediaDaoManager get managers => MediaDaoManager(this);
}

class MediaDaoManager {
  final _$MediaDaoMixin _db;
  MediaDaoManager(this._db);
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db.attachedDatabase, _db.mediaItems);
}
