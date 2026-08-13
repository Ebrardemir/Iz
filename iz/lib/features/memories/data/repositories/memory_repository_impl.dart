/// [MemoryRepository] sözleşmesinin yerel (Drift) uygulaması.
///
/// SORUMLULUĞU:
///   1. DAO'nun ham satırlarını mapper ile domain'e çevirmek
///   2. Exception'ları [Failure]'a çevirmek (dışarı exception SIZMAZ)
///   3. Birden fazla veri kaynağını (DAO + FTS indeksi) birleştirmek
///
/// SORUMLULUĞU DEĞİL: iş kuralı doğrulaması. O UseCase'te.
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz, bu yüzden private
// alanlara `this._db` biçiminde initializing formal kullanamıyoruz.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/memories/data/daos/memory_dao.dart';
import 'package:iz/features/memories/data/mappers/memory_mapper.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';
import 'package:iz/features/memories/domain/repositories/memory_repository.dart';

final class MemoryRepositoryImpl implements MemoryRepository {
  MemoryRepositoryImpl({
    required AppDatabase database,
    required IdGenerator idGenerator,
    required Clock clock,
  }) : _dao = database.memoryDao,
       _ids = idGenerator,
       _clock = clock;

  final MemoryDao _dao;
  final IdGenerator _ids;
  final Clock _clock;

  static final _log = appLogger('memories.repository');

  @override
  Stream<Result<List<Memory>>> watchMemories(MemoryFilter filter) {
    // Arama ifadesini FTS5 sözdizimine çevirip DAO'ya veriyoruz. Eşleşme
    // sorgunun İÇİNDE yapıldığı için sonuç canlı kalır: arama açıkken
    // eklenen ya da düzenlenen anı da anında listeye girer/çıkar.
    final ftsQuery = filter.hasTextQuery ? _toFtsQuery(filter.query!) : null;

    // Kullanıcı yalnızca noktalama yazdıysa ('***') geriye anlamlı token
    // kalmaz. Bu durumda arama yapılmamış sayılır, tüm liste gösterilir.
    return _dao
        .watchMemories(filter, ftsQuery: ftsQuery)
        .map<Result<List<Memory>>>(
          (rows) => Ok(rows.map(MemoryMapper.toDomain).toList()),
        )
        // Stream'in hata kanalını Result'a çeviriyoruz ki UI'da
        // stream kapanmasın (bkz. StreamUseCase açıklaması).
        .transform(_resultGuard<List<Memory>>());
  }

  /// Kullanıcı girdisini güvenli bir FTS5 ifadesine çevirir.
  ///
  /// Ham girdiyi doğrudan `MATCH`e vermek sözdizimi hatası üretir
  /// ("a AND" gibi yarım ifadeler). Token'lara ayırıp her birini tırnaklıyor
  /// ve sonuna `*` ekliyoruz — böylece "kapadokya bal" yazarken
  /// "Kapadokya balon turu" bulunur.
  String? _toFtsQuery(String rawQuery) {
    final tokens = rawQuery
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        // Harf ve rakam DIŞINDAKİ her şeyi at. Bu hem FTS5'in özel
        // karakterlerini (`* ( ) : ^ - "`) hem de tırnak/kaçış karakterlerini
        // eler; DAO'daki ham SQL'in güvenliği bu satıra dayanır.
        // `unicode: true` şart — yoksa 'ı', 'ş', 'ğ' harf sayılmaz ve
        // Türkçe kelimeler bozulur.
        .map((t) => t.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
        .where((t) => t.isNotEmpty)
        .toList();

    if (tokens.isEmpty) return null;

    return tokens.map((t) => '"$t"*').join(' AND ');
  }

  @override
  Stream<Result<MemoryDetail?>> watchDetail(String id) {
    return _dao
        .watchDetail(id)
        .map<Result<MemoryDetail?>>(
          (row) => Ok(row == null ? null : MemoryMapper.toDetailDomain(row)),
        )
        .transform(_resultGuard<MemoryDetail?>());
  }

  @override
  Future<Result<MemoryDetail?>> findDetail(String id) => guard(() async {
    final row = await _dao.findDetail(id);
    return row == null ? null : MemoryMapper.toDetailDomain(row);
  }, onError: (e, s) => DatabaseFailure(cause: e, stackTrace: s));

  @override
  Future<Result<String>> saveDraft(MemoryDraft draft) => guard(
    () async {
      final id = draft.id ?? _ids.newId();
      final now = _clock.now();

      // Güncellemede mevcut sürümü koru ve +1'le (rapor 12.2).
      var currentVersion = 0;
      if (draft.id != null) {
        final existing = await _dao.findDetail(draft.id!);
        currentVersion = existing?.memory.version ?? 0;
      }

      await _dao.upsertMemory(
        memory: MemoryMapper.toCompanion(
          draft,
          id: id,
          now: now,
          currentVersion: currentVersion,
        ),
        personIds: draft.personIds,
        collectionIds: draft.collectionIds,
        mediaIds: draft.mediaIds,
        ritualId: draft.ritualId,
        ritualYear: draft.ritualYear ?? draft.occurredAt.year,
      );

      _log.info('Memory saved: $id');
      return id;
    },
    // `message` LOG içindir, kullanıcı bunu görmez (DatabaseFailure ekranda
    // l10n.errorDatabase olarak görünür). Bu yüzden teknik ve İngilizce.
    onError: (e, s) =>
        DatabaseFailure(message: 'saveDraft failed', cause: e, stackTrace: s),
  );

  @override
  Future<Result<Unit>> setFavorite(String id, {required bool isFavorite}) =>
      guard(() async {
        await _dao.setFavorite(id, isFavorite: isFavorite);
        return Unit.value;
      }, onError: (e, s) => DatabaseFailure(cause: e, stackTrace: s));

  @override
  Future<Result<Unit>> setArchived(String id, {required bool isArchived}) =>
      guard(() async {
        await _dao.setArchived(id, isArchived: isArchived);
        return Unit.value;
      }, onError: (e, s) => DatabaseFailure(cause: e, stackTrace: s));

  @override
  Future<Result<Unit>> moveToTrash(String id) => guard(() async {
    await _dao.softDelete(id);
    return Unit.value;
  }, onError: (e, s) => DatabaseFailure(cause: e, stackTrace: s));

  @override
  Future<Result<Unit>> restoreFromTrash(String id) => guard(() async {
    await _dao.restore(id);
    return Unit.value;
  }, onError: (e, s) => DatabaseFailure(cause: e, stackTrace: s));

  @override
  Future<Result<int>> purgeExpiredTrash() => guard(
    _dao.purgeExpiredTrash,
    onError: (e, s) => DatabaseFailure(cause: e, stackTrace: s),
  );

  @override
  Future<Result<List<Memory>>> findOnThisDay(DateTime day) => guard(() async {
    final rows = await _dao.findOnThisDay(day);
    // Bu sorgu kapak medyası döndürmez; kart için hafif model yeterli.
    return rows
        .map(
          (r) => Memory(
            id: r.id,
            occurredAt: r.occurredAt,
            title: r.title,
            note: r.note,
            categoryId: r.categoryId,
            isFavorite: r.isFavorite,
            isArchived: r.isArchived,
            mediaCount: 0,
            personCount: 0,
          ),
        )
        .toList();
  }, onError: (e, s) => DatabaseFailure(cause: e, stackTrace: s));

  @override
  Future<Result<int>> countAll() => guard(
    _dao.countAll,
    onError: (e, s) => DatabaseFailure(cause: e, stackTrace: s),
  );

  /// Stream'in hata kanalına düşen exception'ları `Err`e çevirir.
  /// Böylece hata sonrası stream KAPANMAZ ve UI yeniden denenebilir kalır.
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

/// Domain arayüzü üzerinden veriyoruz: ViewModel'ler `MemoryRepositoryImpl`i
/// değil `MemoryRepository`yi görür. Testte bu provider'ı sahte bir
/// implementasyonla override etmek yeterli.
final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});
