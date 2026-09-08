/// Koleksiyon formunun anı listesini okuyan yükleyici.
///
/// NEDEN AYRI TEST DOSYASI?
/// Buradaki tek kural — "her çağrı GÜNCEL listeyi verir" — bir widget
/// testinde görünmüyor: form ikinci kez açıldığında hatayı gösteriyordu ama
/// bir widget testi içinde formu kapatıp yeniden açmak, ölçtüğü şeyden çok
/// kurulumunu anlatan bir test olurdu.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/composition/collections_with_memories.dart';
import 'package:iz/features/collections/collections_providers.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';

import '../helpers/fake_collection_repository.dart';
import '../helpers/fake_memory_repository.dart';

Memory _ani(String id) => Memory(
  id: id,
  occurredAt: DateTime(2026, 5, 11),
  title: id,
  isFavorite: false,
  mediaCount: 0,
  personCount: 0,
);

void main() {
  late FakeCollectionRepository collections;
  late FakeMemoryRepository memories;
  late ProviderContainer container;

  setUp(() {
    collections = FakeCollectionRepository();
    memories = FakeMemoryRepository([
      _ani('ani-1'),
      _ani('ani-2'),
      _ani('ani-3'),
    ]);

    container = ProviderContainer(
      overrides: [
        collectionRepositoryProvider.overrideWithValue(collections),
        memoryRepositoryProvider.overrideWithValue(memories),
      ],
    );
    addTearDown(() {
      container.dispose();
      collections.dispose();
      memories.dispose();
    });
  });

  Future<List<String>> yukle(String id) async {
    final sonuc = await container.read(collectionMemoriesProvider).load(id);
    return [for (final memory in sonuc) memory.id];
  }

  test('bağdaki SIRA korunuyor, tarih sırası değil', () async {
    // Kullanıcının formda kurduğu anlatı `sortOrder`da yaşıyor; sorgu ise
    // tarihe göre dönüyor.
    collections.links['kol-1'] = ['ani-3', 'ani-1', 'ani-2'];

    expect(await yukle('kol-1'), ['ani-3', 'ani-1', 'ani-2']);
  });

  test('her çağrı GÜNCEL listeyi veriyor — önbelleğe takılmıyor', () async {
    // GERİLEME KORUMASI. Bu bir `FutureProvider.family` idi ve ilk sonucunu
    // saklıyordu. Kullanıcı koleksiyondan iki anı çıkarıp kaydediyor,
    // listede doğru sonucu görüyor, ama formu TEKRAR açtığında çıkardığı
    // anılar hâlâ seçili geliyordu — ve kaydederse geri gelirlerdi.
    collections.links['kol-1'] = ['ani-1', 'ani-2', 'ani-3'];
    expect(await yukle('kol-1'), hasLength(3));

    collections.links['kol-1'] = ['ani-1'];

    expect(
      await yukle('kol-1'),
      ['ani-1'],
      reason:
          'yükleyici eski listeyi verdi; form çıkarılan anıları geri '
          'seçili gösterir ve kaydedince geri gelirler',
    );
  });

  test('bağı olmayan koleksiyon BOŞ dönüyor', () async {
    expect(await yukle('kol-yok'), isEmpty);
  });

  test('silinmiş anının bağı listeyi BOZMUYOR', () async {
    // Bağ duruyor ama anı artık okunmuyor (çöp kutusunda). Listede
    // atlanıyor; `null` bir eleman koymak ekranı çökertirdi.
    collections.links['kol-1'] = ['ani-1', 'yok-boyle-bir-ani', 'ani-2'];

    expect(await yukle('kol-1'), ['ani-1', 'ani-2']);
  });
}
