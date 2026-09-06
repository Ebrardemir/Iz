/// [MediaRepository] sözleşmesinin yerel uygulaması.
///
/// SORUMLULUĞU:
///   1. Dosyayı kalıcı alana taşıtmak ([MediaFileStore])
///   2. Metadata satırını yazmak ([MediaDao])
///   3. Exception'ları [Failure]'a çevirmek — dışarı exception SIZMAZ
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz.
// ignore_for_file: prefer_initializing_formals

import 'package:iz/core/error/failure.dart';
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/media/data/daos/media_dao.dart';
import 'package:iz/features/media/data/mappers/media_mapper.dart';
import 'package:iz/features/media/data/sources/media_file_store.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/media/domain/repositories/media_repository.dart';

final class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl({
    required MediaDao dao,
    required MediaFileStore fileStore,
    required IdGenerator idGenerator,
    required Clock clock,
  }) : _dao = dao,
       _files = fileStore,
       _ids = idGenerator,
       _clock = clock;

  final MediaDao _dao;
  final MediaFileStore _files;
  final IdGenerator _ids;
  final Clock _clock;

  static final _log = appLogger('media.repository');

  @override
  Future<Result<List<MediaItem>>> importPicked(List<String> paths) =>
      guard(() async {
        final imported = <MediaItem>[];

        for (final path in paths) {
          // Kimliği ÖNCE üretiyoruz: dosya adı da bu kimlikten türüyor, yani
          // sandbox'taki dosyaya bakan biri hangi kayda ait olduğunu görüyor.
          final id = _ids.newId();
          final storedPath = await _files.store(path, id: id);

          await _dao.upsertMedia(
            MediaMapper.toCompanion(id: id, previewPath: storedPath),
          );

          final row = await _dao.findMedia(id);
          // Satırı geri okuyoruz: varsayılanları (tip, durum, sürüm) ikinci kez
          // elle kurmak, veritabanıyla ayrışabilecek bir kopya yazmak olurdu.
          if (row != null) imported.add(MediaMapper.toDomain(row));
        }

        return imported;
      }, onError: _dbFailure);

  @override
  Future<Result<MediaItem?>> findMedia(String id) => guard(() async {
    final row = await _dao.findMedia(id);
    return row == null ? null : MediaMapper.toDomain(row);
  }, onError: _dbFailure);

  @override
  Future<Result<List<MediaItem>>> findMany(List<String> ids) => guard(() async {
    final rows = await _dao.findMany(ids);
    return rows.map(MediaMapper.toDomain).toList();
  }, onError: _dbFailure);

  @override
  Future<Result<MediaOriginalStatus>> verify(String id) => guard(() async {
    final row = await _dao.findMedia(id);
    if (row == null) return MediaOriginalStatus.unknown;

    final path = row.localPreviewPath;
    // Yolu olmayan kayıt için "kayıp" demiyoruz: hiç dosya üretilmemiş
    // olabilir (bulut-öncelikli bir kayıt, V1.5). `unknown` dürüst cevap.
    if (path == null) return MediaOriginalStatus.unknown;

    final status = await _files.exists(path)
        ? MediaOriginalStatus.available
        : MediaOriginalStatus.missing;

    await _dao.markOriginalStatus(id, status, verifiedAt: _clock.now());
    return status;
  }, onError: _dbFailure);

  @override
  Future<Result<Unit>> delete(String id) => guard(() async {
    final row = await _dao.findMedia(id);
    // Önce satır, sonra dosya: tersi olsaydı dosya silinip satır kalabilirdi
    // ve kart var olmayan bir görseli göstermeye çalışırdı.
    await _dao.softDelete(id);
    if (row?.localPreviewPath case final path?) await _files.delete(path);
    return Unit.value;
  }, onError: _dbFailure);

  /// Hatayı LOGLAYIP [DatabaseFailure]a çevirir.
  ///
  /// `guard` istisnayı yutuyor ve kullanıcıya doğru mesajı gösteriyor ama
  /// geriye iz bırakmıyor; koleksiyon tarafında bunun bedelini ödedik.
  Failure _dbFailure(Object error, StackTrace stack) {
    _log.severe('Media error', error, stack);
    return DatabaseFailure(cause: error, stackTrace: stack);
  }
}
