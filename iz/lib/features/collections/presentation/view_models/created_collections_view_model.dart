/// Bu oturumda oluşturulan koleksiyonlar.
///
/// ⚠️ GEÇİCİ DEPO — VERİTABANI DEĞİL. `CollectionDao`/`CollectionRepository`
/// yazılmadı; "Koleksiyonu Oluştur"a basıldığında kayıt hiçbir yere
/// yazılmıyor. Ama akışın sonunun GÖRÜNMESİ gerekiyor: koleksiyon
/// "Hayatım"daki listede belirmezse kullanıcı düğmenin çalışmadığını düşünür.
///
/// Seri tarafındaki `created_rituals_view_model.dart` ile birebir aynı
/// gerekçe ve aynı ömür: veri hattı kurulduğunda ikisi de silinecek.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/shared/preview/form_preview_data.dart';

/// Formun ürettiği kayıt.
///
/// NEDEN [MemoryCollection] ENTITY'Sİ DEĞİL?
/// Entity'de kapak GÖRSELİ değil `coverMediaId` var, bağlı anılar ise ayrı bir
/// tabloda yaşayacak. Formun elindeki her şeyi tek yerde tutmak için burada
/// bir sunum kaydı kullanıyoruz; [toCollection] domain'e çeviriyor.
typedef CreatedCollection = ({
  String id,
  String title,
  String description,
  DateTime? startDate,
  DateTime? endDate,
  Set<String> personIds,
  String? categoryId,
  MediaItem? cover,
  List<FormMemoryOption> memories,
});

extension CreatedCollectionX on CreatedCollection {
  /// Domain karşılığı.
  ///
  /// GÖRÜNÜRLÜK VARSAYILAN OLARAK ÖZEL (BR-003): koleksiyon paylaşımın temel
  /// birimi ve kullanıcı paylaşmayı ayrıca seçmeli.
  MemoryCollection toCollection() => MemoryCollection(
    id: id,
    title: title,
    description: description.isEmpty ? null : description,
    visibility: CollectionVisibility.private,
    startDate: startDate,
    endDate: endDate,
  );
}

class CreatedCollectionsViewModel extends Notifier<List<CreatedCollection>> {
  @override
  List<CreatedCollection> build() => const [];

  /// Yeni koleksiyonu listenin BAŞINA ekliyor: kullanıcı az önce
  /// oluşturduğunu en üstte görmeli.
  void add(CreatedCollection collection) => state = [collection, ...state];
}

final createdCollectionsProvider =
    NotifierProvider<CreatedCollectionsViewModel, List<CreatedCollection>>(
      CreatedCollectionsViewModel.new,
    );
