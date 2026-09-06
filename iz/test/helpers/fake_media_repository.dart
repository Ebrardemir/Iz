/// Bellekte çalışan sahte medya deposu.
///
/// NEDEN GERÇEK DEPO DEĞİL?
/// Gerçeği hem Drift'e hem `getApplicationDocumentsDirectory`ye dokunuyor;
/// widget testinde ikisi de istenmez (eklenti yok, timer kalır). SQL ve
/// dosya davranışı `test/unit/media_repository_test.dart`ta gerçek SQLite ve
/// sahte dosya sistemiyle zaten sınanıyor.
library;

import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/media/domain/repositories/media_repository.dart';

class FakeMediaRepository implements MediaRepository {
  final List<MediaItem> items = [];

  /// İçe aktarılan kaynak yollar — testlerin doğrulayabilmesi için.
  final List<String> importedPaths = [];

  final List<String> deleted = [];

  /// `true` ise [importPicked] hata döner.
  bool failOnImport = false;

  int _counter = 0;

  @override
  Future<Result<List<MediaItem>>> importPicked(List<String> paths) async {
    if (failOnImport) {
      return const Err(DatabaseFailure(cause: 'sahte hata'));
    }

    importedPaths.addAll(paths);

    final imported = [
      for (final path in paths)
        MediaItem(
          id: 'sahte-medya-${++_counter}',
          type: MediaType.photo,
          // Gerçeğinde dosya uygulama alanına kopyalanıyor; sahtede yolu
          // ayırt edilebilir tutuyoruz ki test hangi kareyi gördüğünü bilsin.
          localPreviewPath: '/sahte/medya/$path',
          originalStatus: MediaOriginalStatus.unknown,
        ),
    ];

    items.addAll(imported);
    return Ok(imported);
  }

  @override
  Future<Result<MediaItem?>> findMedia(String id) async =>
      Ok(items.where((m) => m.id == id).firstOrNull);

  @override
  Future<Result<List<MediaItem>>> findMany(List<String> ids) async => Ok([
    for (final item in items)
      if (ids.contains(item.id)) item,
  ]);

  @override
  Future<Result<MediaOriginalStatus>> verify(String id) async =>
      const Ok(MediaOriginalStatus.available);

  @override
  Future<Result<Unit>> delete(String id) async {
    deleted.add(id);
    items.removeWhere((m) => m.id == id);
    return const Ok(Unit.value);
  }
}
