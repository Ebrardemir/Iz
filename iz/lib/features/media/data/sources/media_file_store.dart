/// Seçilen dosyayı uygulamanın kendi alanına taşır.
///
/// NEDEN KOPYALIYORUZ?
/// TR-M4-11 — her seçilen öğe için uygulama alanında bir önizleme üretilir;
/// amacı, kullanıcı galeriden orijinali silse bile kartın anlaşılır kalması
/// (FR-043). Sistem seçicisi bize geçici bir önbellek yolu veriyor; işletim
/// sistemi orayı istediği zaman temizleyebilir. O yolu veritabanına yazsaydık
/// anının görseli bir gün sessizce kaybolurdu.
///
/// NEDEN SOYUTLAMA?
/// `MediaPicker`, `Clock`, `IdGenerator` ile aynı gerekçe: widget ve birim
/// testlerinde gerçek dosya sistemine dokunmak istemiyoruz. Testler
/// `FakeMediaFileStore` geçiyor.
///
/// ⚠️ HENÜZ KÜÇÜLTME YOK. TR-M4-11 "optimize edilmiş önizleme" diyor; bugün
/// dosyayı olduğu gibi kopyalıyoruz. Kalıcılık sorununu çözüyor ama boyut
/// sorununu çözmüyor: 4000×3000 bir fotoğraf sandbox'ta da o boyutta duruyor.
/// Küçültme bir görüntü işleme paketi gerektiriyor ve ayrı bir adım.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

abstract interface class MediaFileStore {
  /// [sourcePath]taki dosyayı uygulama alanına kopyalar ve YENİ yolu döner.
  ///
  /// Kaynak dosya yoksa exception fırlatır — çağıran taraf `Result`a
  /// çeviriyor. Sessizce boş dönmek, kullanıcıya "eklendi" deyip hiçbir şey
  /// eklememek olurdu.
  Future<String> store(String sourcePath, {required String id});

  /// Dosya hâlâ duruyor mu? (TR-M4-12 — tembel doğrulama)
  Future<bool> exists(String path);

  /// Kalıcı kopyayı siler. Kayıt silinince dosyanın da gitmesi gerekiyor,
  /// yoksa sandbox zamanla çöple dolar.
  Future<void> delete(String path);
}

final class AppDirectoryMediaFileStore implements MediaFileStore {
  const AppDirectoryMediaFileStore();

  /// Uygulama belgeler dizini altındaki klasör.
  ///
  /// `getApplicationDocumentsDirectory` KULLANIYORUZ, önbellek dizinini
  /// değil: önbelleği işletim sistemi yer daraldığında silebilir ve
  /// kullanıcının anısının görseli kaybolur.
  static const String _folder = 'media';

  @override
  Future<String> store(String sourcePath, {required String id}) async {
    final source = File(sourcePath);
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/$_folder');
    if (!dir.existsSync()) await dir.create(recursive: true);

    // Uzantıyı koruyoruz: `Image.file` içeriğe bakıyor ama dosyayı dışa
    // aktarırken (M11) uzantısız bir dosya kullanıcıyı zorlar.
    final dot = sourcePath.lastIndexOf('.');
    final extension = dot > sourcePath.lastIndexOf('/') && dot != -1
        ? sourcePath.substring(dot)
        : '';

    final target = '${dir.path}/$id$extension';
    await source.copy(target);
    return target;
  }

  @override
  // `existsSync` KULLANIYORUZ: `File.exists()` bir mikro görev kuyruğu
  // kurmasına rağmen diske eşit derecede senkron erişiyor (`avoid_slow_async_io`).
  // Arayüz yine de `Future` dönüyor — sahte depolar ve ileride gelecek bulut
  // uygulaması gerçekten asenkron olacak.
  Future<bool> exists(String path) async => File(path).existsSync();

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }
}

final mediaFileStoreProvider = Provider<MediaFileStore>(
  (ref) => const AppDirectoryMediaFileStore(),
);
