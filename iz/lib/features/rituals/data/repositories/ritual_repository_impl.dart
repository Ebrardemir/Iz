/// [RitualRepository] sözleşmesinin yerel (Drift) uygulaması.
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
import 'package:iz/core/utils/clock.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/rituals/data/daos/ritual_dao.dart';
import 'package:iz/features/rituals/data/mappers/ritual_mapper.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/features/rituals/domain/repositories/ritual_repository.dart';

final class RitualRepositoryImpl implements RitualRepository {
  RitualRepositoryImpl({
    required RitualDao dao,
    required IdGenerator idGenerator,
    required Clock clock,
  }) : _dao = dao,
       _ids = idGenerator,
       _clock = clock;

  final RitualDao _dao;
  final IdGenerator _ids;
  final Clock _clock;

  static final _log = appLogger('rituals.repository');

  @override
  Stream<Result<List<Ritual>>> watchRituals() => _dao
      .watchRituals()
      .map<Result<List<Ritual>>>(
        (rows) => Ok(rows.map(RitualMapper.toDomain).toList()),
      )
      .transform(_resultGuard<List<Ritual>>());

  @override
  Stream<Result<Ritual?>> watchRitual(String id) => _dao
      .watchRitual(id)
      .map<Result<Ritual?>>(
        (row) => Ok(row == null ? null : RitualMapper.toDomain(row)),
      )
      .transform(_resultGuard<Ritual?>());

  @override
  Future<Result<Ritual?>> findRitual(String id) => guard(() async {
    final row = await _dao.findRitual(id);
    return row == null ? null : RitualMapper.toDomain(row);
  }, onError: _dbFailure);

  @override
  Stream<Result<Map<String, List<RitualOccurrence>>>> watchOccurrences() => _dao
      .watchOccurrences()
      .map<Result<Map<String, List<RitualOccurrence>>>>(Ok.new)
      .transform(_resultGuard<Map<String, List<RitualOccurrence>>>());

  @override
  Stream<Result<Map<String, Set<String>>>> watchPeopleLinks() => _dao
      .watchPeopleLinks()
      .map<Result<Map<String, Set<String>>>>(Ok.new)
      .transform(_resultGuard<Map<String, Set<String>>>());

  @override
  Future<Result<String>> save(RitualDraft draft) => guard(() async {
    // Kimlik yeni kayıtta ÜRETİLİYOR, güncellemede korunuyor (TR-C-40).
    final id = draft.id ?? _ids.newId();
    await _dao.upsertRitual(
      now: _clock.now(),
      outboxId: _ids.newId(),
      RitualMapper.toCompanion(draft, id: id),
      occurrences: draft.occurrences,
      personIds: draft.personIds,
    );
    return id;
  }, onError: _dbFailure);

  @override
  Future<Result<Unit>> softDelete(String id) => guard(() async {
    await _dao.softDelete(id, now: _clock.now(), outboxId: _ids.newId());
    return Unit.value;
  }, onError: _dbFailure);

  /// Hatayı LOGLAYIP [DatabaseFailure]a çevirir.
  ///
  /// `guard` istisnayı yutuyor ve kullanıcıya doğru mesajı gösteriyor ama
  /// geriye iz bırakmıyor; koleksiyon tarafında bunun bedelini ödedik.
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
