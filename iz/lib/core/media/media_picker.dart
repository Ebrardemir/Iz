/// Galeriden fotoğraf seçimi.
///
/// NEDEN SOYUTLAMA?
/// `ImagePicker`ı doğrudan View içinde çağırmak üç şeyi bozardı:
///   1. Widget testinde eklenti yok — her test `MissingPluginException` ile
///      düşerdi. Arayüz sayesinde testte sahte bir seçici veriyoruz.
///   2. Hata yönetimi ekrana sızardı. Burada exception `Failure`a çevriliyor;
///      View yalnızca `Result` görüyor (bkz. core/result/result.dart).
///   3. Paket değiştirmek 5 ekranı dolaşmak demek olurdu.
/// `SecureStore`, `Clock` ve `IdGenerator` da aynı desende.
///
/// NEDEN SİSTEM SEÇİCİSİ?
/// `image_picker`, Android'de Photo Picker'ı, iOS'ta PHPicker'ı açıyor. Bu
/// seçiciler uygulamanın dışında çalışıyor ve **tüm galeriye erişim izni
/// istemiyor** — kullanıcı ne seçtiyse yalnızca onun dosyasını veriyorlar.
/// NFR-051 ("sınırlı fotoğraf erişimi") ve ürünün "tüm galeriyi yedeklemeyen
/// seçilmiş anı" tezi için doğru olan bu. Kendi galeri arayüzünü çizen
/// paketler (photo_manager) tam erişim izni isterdi.
///
/// Bu yüzden burada AYRICA BİR İZİN AKIŞI YOK: izin diyaloğu diye bir şey
/// görmüyoruz. Yine de [PermissionFailure] dalını tutuyoruz — eski Android
/// sürümlerinde ya da kurumsal kısıtlı cihazlarda platform reddedebiliyor.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';

/// Kullanıcının seçtiği tek bir görsel.
///
/// Henüz bir `MediaItem` DEĞİL: veritabanına yazma, önizleme üretme ve
/// kalıcı depolama medya hattı kurulunca gelecek. Şimdilik yalnızca dosyanın
/// nerede olduğunu taşıyoruz.
typedef PickedImage = ({String path, String? mimeType});

abstract interface class MediaPicker {
  /// Galeriyi açar ve en fazla [limit] görsel seçilmesine izin verir.
  ///
  /// Kullanıcı vazgeçerse BOŞ LİSTE döner — bu bir hata değil, bir karar.
  Future<Result<List<PickedImage>>> pickImages({required int limit});
}

final class SystemMediaPicker implements MediaPicker {
  const SystemMediaPicker(this._picker);

  final ImagePicker _picker;

  @override
  Future<Result<List<PickedImage>>> pickImages({required int limit}) => guard(
    () async {
      // `limit` SEÇİCİYE VERİLİYOR, sonradan kırpılmıyor.
      //
      // Kullanıcıya 10 fotoğraf seçtirip sonra "en fazla 3" demek kötü bir
      // deneyim. Sistem seçicisi limiti kendisi uyguluyor: dördüncüye
      // dokunulduğunda seçime izin vermiyor.
      //
      // (FR-041 doğrulaması yine `SaveMemory` içinde duruyor — arayüz
      //  katmanı atlanabilir, iş kuralı atlanamaz.)
      final files = await _picker.pickMultiImage(limit: limit);

      return [
        for (final file in files) (path: file.path, mimeType: file.mimeType),
      ];
    },
    onError: (error, stackTrace) {
      // Platform "izin yok" derse kullanıcıyı ayarlara yönlendirebilmemiz
      // için ayrı bir Failure tipi gerekiyor (bkz. failure_l10n.dart).
      if (error is PlatformException && _isPermissionDenied(error.code)) {
        return PermissionFailure(permission: 'photos', cause: error);
      }
      return UnexpectedFailure(
        message: 'pickImages failed',
        cause: error,
        stackTrace: stackTrace,
      );
    },
  );

  /// `image_picker`ın izin reddi kodları.
  ///
  /// Metin karşılaştırması hoş değil ama paket tipli bir hata sunmuyor;
  /// hangi kodların geldiği paketin belgelerinde yazıyor.
  static bool _isPermissionDenied(String code) =>
      code == 'photo_access_denied' || code == 'camera_access_denied';
}

/// Testte sahte bir seçiciyle override edilir.
final mediaPickerProvider = Provider<MediaPicker>(
  (ref) => SystemMediaPicker(ImagePicker()),
);
