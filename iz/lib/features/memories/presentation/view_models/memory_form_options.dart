/// Anı formundaki seçme kutularının GERÇEK içeriği.
///
/// Form üç şey soruyor: "kimler vardı?", "hangi koleksiyona girsin?",
/// "hangi seriye ait?". İlk ikisinin artık veri katmanı var; üçüncüsü
/// (ritüel) yazılmadı.
///
/// NEDEN BURADA, EKRANIN İÇİNDE DEĞİL?
/// Ekran `ref.watch` edip listeyi kendisi kurabilirdi ama o zaman "kişiyi
/// seçenek satırına çevirme" kuralı bir `build` metodunun ortasında yaşardı
/// ve test edilemezdi. ViewModel katmanı bunun doğru yeri (TR-C-04).
///
/// NEDEN BAŞKA FEATURE'IN DEPOSUNU OKUYORUZ?
/// Kişiler ve koleksiyonlar ayrı feature'lar; buradan yalnızca onların
/// DIŞA AÇILAN yüzünü (`*_providers.dart` → domain sözleşmesi) görüyoruz,
/// içlerini değil (ARCHITECTURE.md §2 / TR-C-03).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/features/collections/collections_providers.dart';
import 'package:iz/features/people/people_providers.dart';
import 'package:iz/shared/widgets/iz_selection_dialog.dart';

/// Anıya bağlanabilecek kişiler.
///
/// Sıralama kişi listesinin kendi sırası (favoriler önce, sonra alfabetik):
/// kullanıcı iki ekranda aynı düzeni görsün.
final memoryPeopleOptionsProvider = StreamProvider<List<IzSelectionOption>>((
  ref,
) {
  return ref
      .watch(personRepositoryProvider)
      .watchPeople()
      .unwrap()
      .map(
        (people) => [
          for (final person in people)
            (id: person.id, label: person.name, icon: AppIcons.person),
        ],
      );
});

/// Anının girebileceği koleksiyonlar.
final memoryCollectionOptionsProvider = StreamProvider<List<IzSelectionOption>>(
  (ref) {
    return ref
        .watch(collectionRepositoryProvider)
        .watchCollections()
        .unwrap()
        .map(
          (collections) => [
            for (final collection in collections)
              (
                id: collection.id,
                label: collection.title,
                icon: AppIcons.collection,
              ),
          ],
        );
  },
);
