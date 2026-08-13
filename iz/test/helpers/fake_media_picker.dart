/// Testlerde galeri yerine geçen sahte seçici.
///
/// GERÇEK SEÇİCİ TESTTE ÇALIŞMAZ: `image_picker` bir platform eklentisi ve
/// widget testinde `MissingPluginException` atar. `MediaPicker` arayüzü tam
/// bunun için var (bkz. core/media/media_picker.dart).
///
/// Üç davranışı da kurabiliyoruz: seçim yapıldı, vazgeçildi, hata döndü.
library;

import 'package:iz/core/error/failure.dart';
import 'package:iz/core/media/media_picker.dart';
import 'package:iz/core/result/result.dart';

class FakeMediaPicker implements MediaPicker {
  FakeMediaPicker({this.paths = const [], this.failure});

  /// Kullanıcının seçtiği varsayılan dosyalar. Boş liste → vazgeçti.
  final List<String> paths;

  /// Doluysa seçici hata döner (izin reddi gibi).
  final Failure? failure;

  /// Seçiciye geçirilen limitler — çağrının gerçekten limitle yapıldığını
  /// doğrulamak için.
  final List<int> receivedLimits = [];

  @override
  Future<Result<List<PickedImage>>> pickImages({required int limit}) async {
    receivedLimits.add(limit);

    final error = failure;
    if (error != null) return Err(error);

    return Ok([for (final path in paths) (path: path, mimeType: 'image/jpeg')]);
  }
}
