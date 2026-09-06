/// Bellekte çalışan sahte dosya deposu.
///
/// NEDEN GERÇEK DOSYA SİSTEMİ DEĞİL?
/// Testin gerçek diske yazması iki şeyi bozar: koşular birbirinin dosyasını
/// görür ve `getApplicationDocumentsDirectory` widget testinde eklenti
/// gerektirir (`MissingPluginException`). Burada tuttuğumuz şey yalnızca
/// "hangi yol nereye kopyalandı" haritası.
library;

import 'package:iz/features/media/data/sources/media_file_store.dart';

class FakeMediaFileStore implements MediaFileStore {
  /// Kopyalanan dosyalar: hedef yol → kaynak yol.
  final Map<String, String> stored = {};

  /// Silinen yollar — testlerin doğrulayabilmesi için.
  final List<String> deleted = [];

  /// `true` ise [store] fırlatır: "galeriden seçilen dosya okunamadı"
  /// durumunu taklit ediyor.
  bool failOnStore = false;

  /// [exists] için cevabı testin belirlemesi. `null` → [stored]a bakılır.
  bool? existsOverride;

  @override
  Future<String> store(String sourcePath, {required String id}) async {
    if (failOnStore) {
      throw const FileSystemException('kaynak dosya okunamadı');
    }

    final target = '/sahte/medya/$id.jpg';
    stored[target] = sourcePath;
    return target;
  }

  @override
  Future<bool> exists(String path) async =>
      existsOverride ?? stored.containsKey(path);

  @override
  Future<void> delete(String path) async {
    deleted.add(path);
    stored.remove(path);
  }
}

/// `dart:io`ya bağımlı olmadan atmak için küçük bir istisna tipi.
class FileSystemException implements Exception {
  const FileSystemException(this.message);

  final String message;

  @override
  String toString() => 'FileSystemException: $message';
}
