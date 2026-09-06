/// [CollectionRepository] sözleşmesinin yerel (Drift) uygulaması.
///
/// SORUMLULUĞU:
///   1. DAO'nun ham satırlarını mapper ile domain'e çevirmek
///   2. Exception'ları [Failure]'a çevirmek — dışarı exception SIZMAZ
///
/// SORUMLULUĞU DEĞİL: iş kuralı doğrulaması. O UseCase'te.
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz, bu yüzden private
// alanlara `this._dao` biçiminde initializing formal kullanamıyoruz.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/collections/data/daos/collection_dao.dart';
import 'package:iz/features/collections/data/mappers/collection_mapper.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/collections/domain/repositories/collection_repository.dart';

final class CollectionRepositoryImpl implements CollectionRepository {
  CollectionRepositoryImpl({
    required CollectionDao dao,
    required IdGenerator idGenerator,
  }) : _dao = dao,
       _ids = idGenerator;

  final CollectionDao _dao;
  final IdGenerator _ids;

  static final _log = appLogger('collections.repository');

  @override
  Stream<Result<List<MemoryCollection>>> watchCollections() => _dao
      .watchCollections()
      .map<Result<List<MemoryCollection>>>(
        (rows) => Ok(rows.map(CollectionMapper.toDomain).toList()),
      )
      .transform(_resultGuard<List<MemoryCollection>>());

  @override
  Stream<Result<MemoryCollection?>> watchCollection(String id) => _dao
      .watchCollection(id)
      .map<Result<MemoryCollection?>>(
        (row) => Ok(row == null ? null : CollectionMapper.toDomain(row)),
      )
      .transform(_resultGuard<MemoryCollection?>());

  @override
  Future<Result<MemoryCollection?>> findCollection(String id) =>
      guard(() async {
        final row = await _dao.findCollection(id);
        return row == null ? null : CollectionMapper.toDomain(row);
      }, onError: _dbFailure);

  @override
  Stream<Result<Map<String, List<String>>>> watchMemoryLinks() => _dao
      .watchMemoryLinks()
      .map<Result<Map<String, List<String>>>>(Ok.new)
      .transform(_resultGuard<Map<String, List<String>>>());

  @override
  Future<Result<String>> save(CollectionDraft draft) => guard(() async {
    // Kimlik yeni kayıtta ÜRETİLİYOR, güncellemede korunuyor. UUID v7
    // (TR-C-40): cihazlar arası çakışmaz ve zaman sıralı olduğu için
    // birincil anahtar indeksi parçalanmaz.
    final id = draft.id ?? _ids.newId();
    await _dao.upsertCollection(
      CollectionMapper.toCompanion(draft, id: id),
      memoryIds: draft.memoryIds,
    );
    return id;
  }, onError: _dbFailure);

  @override
  Future<Result<Unit>> softDelete(String id) => guard(() async {
    await _dao.softDelete(id);
    return Unit.value;
  }, onError: _dbFailure);

  /// Yazma/okuma hatasını LOGLAYIP [DatabaseFailure]a çevirir.
  ///
  /// NEDEN LOGLUYORUZ?
  /// `guard` istisnayı yutuyor ve kullanıcıya "Verilerine şu anda
  /// ulaşılamıyor" yazıyor — doğru mesaj, ama geriye hiçbir iz kalmıyordu.
  /// Koleksiyona sahte kimlikli bir anı bağlanınca düşen yabancı anahtar
  /// kısıtı tam olarak böyle sessiz kalmıştı; sebebi bulmak için kodu
  /// okumak gerekti.
  ///
  /// AYNI EKSİK ÖTEKİ DEPOLARDA DA VAR (`PersonRepositoryImpl`,
  /// `MemoryRepositoryImpl`); oraları da aynı şekilde düzeltmek gerekiyor.
  Failure _dbFailure(Object error, StackTrace stack) {
    _log.severe('Database error', error, stack);
    return DatabaseFailure(cause: error, stackTrace: stack);
  }

  /// Stream'in HATA KANALINI `Result`a çevirir.
  ///
  /// Neden şart: Dart'ta bir stream hata yayınladığında dinleyici kapanır.
  /// Hatayı olduğu gibi geçirseydik, tek bir veritabanı hatasından sonra
  /// liste bir daha hiç güncellenmezdi.
  StreamTransformer<Result<T>, Result<T>> _resultGuard<T>() {
    return StreamTransformer<Result<T>, Result<T>>.fromHandlers(
      handleError: (error, stack, sink) {
        _log.severe('Stream error', error, stack);
        sink.add(Err<T>(DatabaseFailure(cause: error, stackTrace: stack)));
      },
    );
  }
}

// --- Providers --------------------------------------------------------------

/// Domain arayüzü üzerinden veriyoruz: ViewModel'ler
/// `CollectionRepositoryImpl`i değil `CollectionRepository`yi görür.
final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return CollectionRepositoryImpl(
    dao: ref.watch(appDatabaseProvider).collectionDao,
    idGenerator: ref.watch(idGeneratorProvider),
  );
});
