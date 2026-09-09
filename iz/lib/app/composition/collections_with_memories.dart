/// Koleksiyonları ANILARIYLA birlikte veren birleşik akış.
///
/// NEDEN `features/collections/` ALTINDA DEĞİL?
/// Burası iki ayrı feature'ı birleştiriyor: koleksiyonun kendisi
/// `CollectionRepository`den, içindeki anılar `MemoryRepository`den geliyor.
/// Bir feature başka feature'ın YALNIZ `domain/`ini görebilir
/// (ARCHITECTURE.md §2, TR-C-03); koleksiyon tarafına koysaydık anıların veri
/// katmanına uzanmak zorunda kalırdı ve sınır delinirdi.
///
/// `app/` her şeyi bilmeye yetkili tek katman — router da bu yüzden burada.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/features/collections/collections_providers.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/collections/presentation/view_models/collections_list_view_model.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/media/media_providers.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';

/// Koleksiyon + içindeki anılar.
///
/// NEDEN AYRI TİP?
/// [MemoryCollection] domain varlığı anıları TAŞIMIYOR — bağ ayrı bir tabloda
/// yaşıyor. Ekranın ihtiyacı ikisinin birleşimi; entity'ye anı listesi
/// eklemek, koleksiyonu her okuduğumuz yerde anıları da yüklemek demekti
/// (NFR-003).
typedef CollectionWithMemories = ({
  MemoryCollection collection,
  List<Memory> memories,

  /// Koleksiyonun kapağı — `coverMediaId` çözülmüş hâli.
  ///
  /// Entity yalnızca KİMLİK taşıyor; görseli burada çözüyoruz çünkü kart
  /// hazır bir [MediaItem] bekliyor ve `MediaThumbnail` kayıp dosyayı kendi
  /// içinde ele alıyor.
  MediaItem? cover,
});

/// Koleksiyonların kapak görselleri — kimlikten `MediaItem`a.
///
/// TEK SORGUDA: koleksiyon başına ayrı çağrı açmak 20 koleksiyonda 20 sorgu
/// demekti.
final _collectionCoversProvider = FutureProvider<Map<String, MediaItem>>((
  ref,
) async {
  final collections = ref.watch(collectionsListProvider).value ?? const [];
  final ids = [for (final collection in collections) ?collection.coverMediaId];
  if (ids.isEmpty) return const {};

  final result = await ref.watch(mediaRepositoryProvider).findMany(ids);
  return switch (result) {
    Ok(:final value) => {for (final media in value) media.id: media},
    // Kapak çözülemezse kart yer tutucu çiziyor; liste yine görünüyor.
    Err() => const {},
  };
});

/// Herhangi bir koleksiyona bağlı TÜM anılar.
///
/// Koleksiyon başına ayrı sorgu açmıyoruz: 20 koleksiyon = 20 abonelik
/// demekti. Tek sorgu, gruplama Dart tarafında.
final _collectionMemoriesProvider = StreamProvider<List<Memory>>((ref) {
  final links = ref.watch(collectionMemoryLinksProvider).value ?? const {};
  if (links.isEmpty) return Stream.value(const []);

  return ref
      .watch(memoryRepositoryProvider)
      .watchMemories(MemoryFilter(collectionIds: links.keys.toSet()))
      .unwrap();
});

/// Ekranın gördüğü birleşik liste.
///
/// NEDEN `Provider` İÇİNDE BİRLEŞTİRME?
/// Üç ayrı akışı (koleksiyonlar, bağlar, anılar) birleştirmek gerekiyor.
/// rxdart eklemek yerine Riverpod'un kendi bağımlılık takibini kullanıyoruz:
/// herhangi biri değişince bu provider yeniden hesaplanıyor.
///
/// Anı sırası kullanıcının formda dizdiği sıra — bağ tablosundaki
/// `sortOrder`. Anıları tarihe göre yeniden sıralasaydık kullanıcının
/// kurduğu anlatı bozulurdu.
final collectionsWithMemoriesProvider =
    Provider<AsyncValue<List<CollectionWithMemories>>>((ref) {
      final collections = ref.watch(collectionsListProvider);
      final links = ref.watch(collectionMemoryLinksProvider);
      final memories = ref.watch(_collectionMemoriesProvider);
      final covers = ref.watch(_collectionCoversProvider).value ?? const {};

      // Koleksiyonlar yüklenmeden liste kurulamaz. Bağlar ve anılar ise
      // gecikirse boş kabul ediliyor: koleksiyon kartı anısız da görünmeli,
      // aksi hâlde yeni açılmış boş bir koleksiyon hiç belirmezdi.
      return collections.whenData((list) {
        final linkMap = links.value ?? const <String, List<String>>{};
        final byId = {
          for (final memory in memories.value ?? const <Memory>[])
            memory.id: memory,
        };

        return [
          for (final collection in list)
            (
              collection: collection,
              cover: collection.coverMediaId == null
                  ? null
                  : covers[collection.coverMediaId],
              memories: [
                for (final id in linkMap[collection.id] ?? const <String>[])
                  ?byId[id],
              ],
            ),
        ];
      });
    });

/// Anıyı çöp kutusuna taşıma ve geri alma — koleksiyon sekmesi için.
///
/// NEDEN BURADA, EKRANDA DEĞİL?
/// `my_life` yalnız `memories/domain`i görebilir (TR-C-03) ama
/// `memoryRepositoryProvider` `memories/data` içinde yaşıyor. Ekran onu
/// doğrudan import etseydi feature sınırı delinirdi ve CI kapısı bunu
/// yakalardı. Cross-feature bağı kurmaya yetkili tek katman `app/`.
///
/// SADECE İKİ METOT: deponun tamamını sızdırmıyoruz. Ekranın ihtiyacı
/// "çöpe at" ve "geri al"; gerisini görmesi için bir sebep yok.
final memoryTrashProvider = Provider<MemoryTrashActions>(
  MemoryTrashActions._new,
);

final class MemoryTrashActions {
  const MemoryTrashActions._(this._ref);

  factory MemoryTrashActions._new(Ref ref) = MemoryTrashActions._;

  final Ref _ref;

  /// FR-015 — kayıt gitmiyor, `deletedAt` doluyor. 30 gün geri alınabilir.
  Future<Result<Unit>> moveToTrash(String memoryId) =>
      _ref.read(memoryRepositoryProvider).moveToTrash(memoryId);

  /// SnackBar'daki "Geri al".
  Future<Result<Unit>> restore(String memoryId) =>
      _ref.read(memoryRepositoryProvider).restoreFromTrash(memoryId);
}

/// TEK bir koleksiyonun anılarını okur — kullanıcının dizdiği sırada.
///
/// NEDEN BURADA, KOLEKSİYON FORMUNUN İÇİNDE DEĞİL?
/// Form `collections/presentation` altında ve bir feature başka feature'ın
/// yalnız `domain/`ini görebilir (TR-C-03). Anıları okumak
/// `memoryRepositoryProvider`a, yani `memories/data`ya uzanmak demek.
/// Cross-feature bağı kurmaya yetkili tek katman `app/`.
///
/// [collectionsWithMemoriesProvider]'dan AYRI: o, LİSTE ekranı için tüm
/// koleksiyonları birden veriyor. Form tek koleksiyon açıyor ve hepsini
/// yüklemesi için bir sebep yok (NFR-003).
///
/// ⚠️ NEDEN `FutureProvider.family` DEĞİL?
/// Öyleydi ve ÖNBELLEĞE TAKILDI: `FutureProvider` ilk sonucunu saklıyor,
/// yani form ikinci kez açıldığında ilk açılıştaki listeyi görüyordu.
/// Kullanıcı koleksiyondan iki anı çıkarıp kaydediyor, listede doğru sonucu
/// görüyor, ama formu tekrar açtığında çıkardığı anılar hâlâ seçili
/// geliyordu — ve kaydederse geri gelirlerdi.
///
/// Form ANLIK BİR GÖRÜNTÜ istiyor, canlı bir akış değil: kullanıcının
/// düzenlediği liste yerel bir kopya olmalı, altından değişmemeli. Bu yüzden
/// yanıtı önbelleğe alan bir provider değil, her çağrıldığında yeniden okuyan
/// bir METOT veriyoruz. [memoryTrashProvider] ile aynı desen.
final collectionMemoriesProvider = Provider<CollectionMemoriesLoader>(
  CollectionMemoriesLoader._new,
);

final class CollectionMemoriesLoader {
  const CollectionMemoriesLoader._(this._ref);

  factory CollectionMemoriesLoader._new(Ref ref) = CollectionMemoriesLoader._;

  final Ref _ref;

  Future<List<Memory>> load(String collectionId) async {
    // DEPODAN DOĞRUDAN okuyoruz, `collectionMemoryLinksProvider` üzerinden
    // DEĞİL: `StreamProvider.future` ilk değeri beklerken çözülmüyor ve form
    // açılışta kilitleniyordu. İki akışı da aynı yoldan almak zaten daha
    // simetrik.
    final links = await _ref
        .read(collectionRepositoryProvider)
        .watchMemoryLinks()
        .unwrap()
        .first;
    final ids = links[collectionId] ?? const <String>[];
    if (ids.isEmpty) return const [];

    final memories = await _ref
        .read(memoryRepositoryProvider)
        .watchMemories(MemoryFilter(collectionIds: {collectionId}))
        .unwrap()
        .first;

    // SIRA BAĞDAN geliyor, sorgudan değil: sorgu tarihe göre dönüyor ama
    // kullanıcının formda kurduğu anlatı `sortOrder`da yaşıyor.
    final byId = {for (final memory in memories) memory.id: memory};
    return [for (final id in ids) ?byId[id]];
  }
}
