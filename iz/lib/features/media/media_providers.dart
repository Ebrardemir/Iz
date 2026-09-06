/// Medya feature'ının DIŞARI AÇILAN yüzü.
///
/// NEDEN AYRI DOSYA?
/// Fotoğraf üç ayrı feature'ın işine yarıyor: anı, kişi (avatar) ve
/// koleksiyon (kapak). Hepsinin medyayı kaydetmesi gerekiyor ama hiçbiri
/// medyanın İÇİNİ (DAO, dosya deposu, uygulama sınıfı) görmemeli —
/// ARCHITECTURE.md §2 / TR-C-03: bir feature başka feature'ın yalnız
/// sözleşmesini tanır.
///
/// Sağlayıcıyı `data/repositories/...` içinde bırakmak, onu okumak isteyen
/// herkesi veri katmanını import etmeye zorluyordu. Burası tek satırlık bir
/// kapı: dışarıya YALNIZCA [MediaRepository] sözleşmesi görünüyor.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/media/data/repositories/media_repository_impl.dart';
import 'package:iz/features/media/data/sources/media_file_store.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/media/domain/repositories/media_repository.dart';

/// Domain arayüzü üzerinden veriyoruz: çağıranlar
/// `MediaRepositoryImpl`i değil `MediaRepository`yi görür.
final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepositoryImpl(
    dao: ref.watch(appDatabaseProvider).mediaDao,
    fileStore: ref.watch(mediaFileStoreProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});

/// Tek bir medyanın kaydı — kimlikten görsele.
///
/// Kişi `avatarMediaId`, koleksiyon `coverMediaId` yalnızca KİMLİK taşıyor;
/// entity'ye `MediaItem` gömmek, kişiyi her okuduğumuz yerde medyayı da
/// yüklemek olurdu (NFR-003). Görseli gösterecek ekran kimliği burada
/// çözüyor.
///
/// `family` kullanıyoruz: her kimlik için ayrı bir kayıt. Kayıt yoksa `null`
/// dönüyor ve `MediaThumbnail` yer tutucusunu çiziyor — hata değil.
final mediaItemProvider = FutureProvider.family<MediaItem?, String>((
  ref,
  id,
) async {
  final result = await ref.watch(mediaRepositoryProvider).findMedia(id);
  // Hata da yer tutucuya düşüyor: kayıp bir görsel yüzünden ekran
  // çökmemeli (NFR-021).
  return switch (result) {
    Ok(:final value) => value,
    Err() => null,
  };
});
