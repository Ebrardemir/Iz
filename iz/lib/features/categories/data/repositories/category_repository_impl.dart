/// [CategoryRepository] sözleşmesinin yerel (Drift) uygulaması.
///
/// SORUMLULUĞU:
///   1. DAO'nun ham satırlarını mapper ile domain'e çevirmek
///   2. Exception'ları [Failure]'a çevirmek — dışarı exception SIZMAZ
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:iz/core/error/failure.dart';
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/features/categories/data/daos/category_dao.dart';
import 'package:iz/features/categories/data/mappers/category_mapper.dart';
import 'package:iz/features/categories/domain/entities/memory_category.dart';
import 'package:iz/features/categories/domain/repositories/category_repository.dart';

final class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({required CategoryDao dao}) : _dao = dao;

  final CategoryDao _dao;

  static final _log = appLogger('categories.repository');

  @override
  Stream<Result<List<MemoryCategory>>> watchCategories() => _dao
      .watchCategories()
      .map<Result<List<MemoryCategory>>>(
        (rows) => Ok(rows.map(CategoryMapper.toDomain).toList()),
      )
      .transform(_resultGuard<List<MemoryCategory>>());

  @override
  Future<Result<MemoryCategory?>> findCategory(String id) => guard(() async {
    final row = await _dao.findCategory(id);
    return row == null ? null : CategoryMapper.toDomain(row);
  }, onError: _dbFailure);

  /// Hatayı LOGLAYIP [DatabaseFailure]a çevirir.
  Failure _dbFailure(Object error, StackTrace stack) {
    _log.severe('Database error', error, stack);
    return DatabaseFailure(cause: error, stackTrace: stack);
  }

  /// Stream'in HATA KANALINI `Result`a çevirir.
  ///
  /// Neden şart: Dart'ta bir stream hata yayınladığında dinleyici kapanır.
  StreamTransformer<Result<T>, Result<T>> _resultGuard<T>() {
    return StreamTransformer<Result<T>, Result<T>>.fromHandlers(
      handleError: (error, stack, sink) {
        _log.severe('Stream error', error, stack);
        sink.add(Err<T>(DatabaseFailure(cause: error, stackTrace: stack)));
      },
    );
  }
}
