/// Bu oturumda oluşturulan ritüeller.
///
/// ⚠️ GEÇİCİ DEPO — VERİTABANI DEĞİL.
/// `RitualDao`/`RitualRepository` yazılmadı; kullanıcı "Ritüeli Oluştur"a
/// bastığında kayıt hiçbir yere yazılmıyor. Ama akışın sonunun GÖRÜNMESİ
/// gerekiyor: ritüel oluştuktan sonra "Serilerim"de belirmezse kullanıcı
/// düğmenin çalışmadığını düşünür ve tasarımı değerlendiremez.
///
/// Bu yüzden oluşturulan ritüeller bellekte, oturum boyunca duruyor.
/// Uygulama kapanınca gidiyorlar — bilinçli: kalıcı gibi davranıp yeniden
/// açılışta kaybolmak, hiç görünmemekten daha kötü bir yanılgı olurdu.
///
/// HAT KURULDUĞUNDA: bu dosya silinecek, "Serilerim" listesi repository'den
/// gelen ritüelleri gösterecek. Ekranların hiçbiri değişmeyecek — form
/// zaten [add] çağırıyor, liste zaten dışarıdan veri alıyor.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/shared/preview/form_preview_data.dart';

/// Formun ürettiği kayıt.
///
/// NEDEN [Ritual] ENTITY'Sİ DEĞİL?
/// Entity'de açıklama, kapak görseli ve bağlı anılar YOK — onlar ayrı
/// tablolarda yaşayacak (`RitualMedia`, `MemoryRitual`). Formun elindeki her
/// şeyi tek yerde tutmak için burada bir sunum kaydı kullanıyoruz; [toRitual]
/// domain'e çeviriyor.
typedef CreatedRitual = ({
  String id,
  String title,
  String description,
  RecurrenceType recurrence,
  Set<String> personIds,
  String? categoryId,
  MediaItem? cover,

  /// Ritüele bağlanan anılar. Tarih aralığı BUNLARDAN türetiliyor: kullanıcı
  /// forma tarih girmiyor (kendi kararı — "bu tarih anılardan gelsin").
  List<FormMemoryOption> memories,
});

extension CreatedRitualX on CreatedRitual {
  /// Domain karşılığı.
  ///
  /// TARİH ÇAPASI YOK: ritüelin tarihi anılardan geliyor, kullanıcı
  /// girmiyor. `anchorMonth`/`anchorDay` bu yüzden boş kalıyor.
  Ritual toRitual() => Ritual(
    id: id,
    title: title,
    recurrenceType: recurrence,
    relatedPersonId: personIds.firstOrNull,
    iconKey: 'ritual',
  );

  /// Bağlı anıların EN ERKEN ve EN GEÇ yılı — "2024 – 2026".
  ///
  /// Tek yıl varsa tek yıl yazıyor ("2026"): "2026 – 2026" saçma görünüyor.
  /// Anı seçilmemişse null; çağıran taraf satırı hiç çizmiyor.
  ({int from, int to})? get yearRange {
    if (memories.isEmpty) return null;

    final years = [for (final memory in memories) memory.year]..sort();
    return (from: years.first, to: years.last);
  }
}

class CreatedRitualsViewModel extends Notifier<List<CreatedRitual>> {
  @override
  List<CreatedRitual> build() => const [];

  /// Yeni ritüeli listenin BAŞINA ekliyor: kullanıcı az önce oluşturduğunu
  /// "Serilerim"i açtığında en üstte görmeli, aşağı kaydırıp aramamalı.
  void add(CreatedRitual ritual) => state = [ritual, ...state];
}

final createdRitualsProvider =
    NotifierProvider<CreatedRitualsViewModel, List<CreatedRitual>>(
      CreatedRitualsViewModel.new,
    );
