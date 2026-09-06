/// Medya deposu **sözleşmesi**.
///
/// KURAL: hiçbir metot exception fırlatmaz — hepsi `Result` döner (TR-C-02).
library;

import 'package:iz/core/result/result.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';

abstract interface class MediaRepository {
  /// Galeriden seçilmiş dosyaları KALICI hâle getirir.
  ///
  /// Her dosya için: uygulama alanına kopyalanır (TR-M4-11) ve `MediaItems`
  /// tablosuna bir satır yazılır. Dönen [MediaItem]lar GERÇEK kimlik taşır;
  /// anıya, kişiye ya da koleksiyona bağlanmaya hazırdır.
  ///
  /// NEDEN TOPLU?
  /// Kullanıcı seçiciden birden fazla fotoğrafla dönüyor. Tek tek çağırsaydık
  /// biri düştüğünde yarısı yazılmış olurdu ve kullanıcı hangisinin
  /// eklendiğini bilemezdi.
  Future<Result<List<MediaItem>>> importPicked(List<String> paths);

  Future<Result<MediaItem?>> findMedia(String id);

  Future<Result<List<MediaItem>>> findMany(List<String> ids);

  /// TR-M4-12 — orijinal hâlâ duruyor mu? Tembel doğrulama.
  ///
  /// Her açılışta tüm galeriyi taramıyoruz; bu metot yalnız ekranda görünen
  /// medya için çağrılıyor. Sonuç `lastVerifiedAt` ile birlikte yazılıyor.
  Future<Result<MediaOriginalStatus>> verify(String id);

  /// Kaydı ve kalıcı kopyasını siler.
  Future<Result<Unit>> delete(String id);
}
