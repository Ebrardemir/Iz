/// [JournalRepository] sözleşmesinin yerel (Drift) uygulaması.
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
import 'package:iz/features/journal/data/daos/journal_dao.dart';
import 'package:iz/features/journal/data/mappers/journal_mapper.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/journal/domain/repositories/journal_repository.dart';

final class JournalRepositoryImpl implements JournalRepository {
  JournalRepositoryImpl({
    required JournalDao dao,
    required IdGenerator idGenerator,
    required Clock clock,
  }) : _dao = dao,
       _ids = idGenerator,
       _clock = clock;

  final JournalDao _dao;
  final IdGenerator _ids;
  final Clock _clock;

  static final _log = appLogger('journal.repository');

  @override
  Stream<Result<List<JournalEntry>>> watchEntries() => _dao
      .watchEntries()
      .map<Result<List<JournalEntry>>>(
        // MEDYA KİMLİKLERİ LİSTEDE YOK — bilinçli. Günlük listesi satır satır
        // metin gösteriyor; her satır için ayrı bir bağ sorgusu açmak
        // NFR-003'ü ihlal ederdi. Detay ekranı gerektiğinde `watchEntry` ile
        // tek kaydı okuyor.
        (rows) => Ok(rows.map(JournalMapper.toDomain).toList()),
      )
      .transform(_resultGuard<List<JournalEntry>>());

  @override
  Stream<Result<JournalEntry?>> watchEntry(String id) => _dao
      .watchEntry(id)
      .map<Result<JournalEntry?>>(
        (row) => Ok(row == null ? null : JournalMapper.toDomain(row)),
      )
      .transform(_resultGuard<JournalEntry?>());

  @override
  Future<Result<JournalEntry?>> findEntry(String id) => guard(() async {
    final row = await _dao.findEntry(id);
    return row == null ? null : JournalMapper.toDomain(row);
  }, onError: _dbFailure);

  @override
  Stream<Result<int>> watchCount() =>
      _dao.watchCount().map<Result<int>>(Ok.new).transform(_resultGuard<int>());

  @override
  Future<Result<String>> save(JournalDraft draft) => guard(() async {
    // Kimlik yeni kayıtta ÜRETİLİYOR, güncellemede korunuyor (TR-C-40).
    final id = draft.id ?? _ids.newId();
    await _dao.upsertEntry(
      JournalMapper.toCompanion(draft, id: id),
      now: _clock.now(),
      mediaIds: draft.mediaIds,
    );
    return id;
  }, onError: _dbFailure);

  @override
  Future<Result<Unit>> setFavorite(String id, {required bool isFavorite}) =>
      guard(() async {
        await _dao.setFavorite(id, isFavorite: isFavorite, now: _clock.now());
        return Unit.value;
      }, onError: _dbFailure);

  @override
  Future<Result<Unit>> softDelete(String id) => guard(() async {
    await _dao.softDelete(id, now: _clock.now());
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
  StreamTransformer<Result<T>, Result<T>> _resultGuard<T>() {
    return StreamTransformer<Result<T>, Result<T>>.fromHandlers(
      handleError: (error, stack, sink) {
        _log.severe('Stream error', error, stack);
        sink.add(Err<T>(DatabaseFailure(cause: error, stackTrace: stack)));
      },
    );
  }
}
