/// [PersonRepository] sözleşmesinin yerel (Drift) uygulaması.
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
import 'package:iz/features/people/data/daos/person_dao.dart';
import 'package:iz/features/people/data/mappers/person_mapper.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/people/domain/repositories/person_repository.dart';

final class PersonRepositoryImpl implements PersonRepository {
  PersonRepositoryImpl({
    required PersonDao dao,
    required IdGenerator idGenerator,
  }) : _dao = dao,
       _ids = idGenerator;

  final PersonDao _dao;
  final IdGenerator _ids;

  static final _log = appLogger('people.repository');

  @override
  Stream<Result<List<Person>>> watchPeople() => _dao
      .watchPeople()
      .map<Result<List<Person>>>(
        (rows) => Ok(rows.map(PersonMapper.toDomain).toList()),
      )
      .transform(_resultGuard<List<Person>>());

  @override
  Stream<Result<Person?>> watchPerson(String id) => _dao
      .watchPerson(id)
      .map<Result<Person?>>(
        (row) => Ok(row == null ? null : PersonMapper.toDomain(row)),
      )
      .transform(_resultGuard<Person?>());

  @override
  Future<Result<Person?>> findPerson(String id) => guard(
    () async {
      final row = await _dao.findPerson(id);
      return row == null ? null : PersonMapper.toDomain(row);
    },
    onError: (error, stack) => DatabaseFailure(cause: error, stackTrace: stack),
  );

  @override
  Future<Result<String>> save(PersonDraft draft) => guard(
    () async {
      // Kimlik yeni kayıtta ÜRETİLİYOR, güncellemede korunuyor. UUID v7
      // (TR-C-40): cihazlar arası çakışmaz ve zaman sıralı olduğu için
      // birincil anahtar indeksi parçalanmaz.
      final id = draft.id ?? _ids.newId();
      await _dao.upsertPerson(PersonMapper.toCompanion(draft, id: id));
      return id;
    },
    onError: (error, stack) => DatabaseFailure(cause: error, stackTrace: stack),
  );

  @override
  Future<Result<Unit>> softDelete(String id) => guard(
    () async {
      await _dao.softDelete(id);
      return Unit.value;
    },
    onError: (error, stack) => DatabaseFailure(cause: error, stackTrace: stack),
  );

  @override
  Future<Result<Unit>> setFavorite(String id, {required bool isFavorite}) =>
      guard(
        () async {
          await _dao.setFavorite(id, isFavorite: isFavorite);
          return Unit.value;
        },
        onError: (error, stack) =>
            DatabaseFailure(cause: error, stackTrace: stack),
      );

  /// Stream'in HATA KANALINI `Result`a çevirir.
  ///
  /// Neden şart: Dart'ta bir stream hata yayınladığında dinleyici kapanır.
  /// Hatayı olduğu gibi geçirseydik, tek bir veritabanı hatasından sonra
  /// liste bir daha hiç güncellenmezdi — kullanıcı uygulamayı yeniden
  /// başlatana kadar donmuş bir ekrana bakardı.
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

/// Domain arayüzü üzerinden veriyoruz: ViewModel'ler `PersonRepositoryImpl`i
/// değil `PersonRepository`yi görür.
final personRepositoryProvider = Provider<PersonRepository>((ref) {
  return PersonRepositoryImpl(
    dao: ref.watch(appDatabaseProvider).personDao,
    idGenerator: ref.watch(idGeneratorProvider),
  );
});
