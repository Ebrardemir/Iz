/// Seri (ritüel) deposu **sözleşmesi**.
///
/// Gerekçesi `CollectionRepository` ile aynı: domain "veriyi nasıl aldığımı
/// bilmem, ne aldığımı bilirim" der.
///
/// KURAL: hiçbir metot exception fırlatmaz — hepsi `Result` döner (TR-C-02).
library;

import 'package:iz/core/result/result.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';

abstract interface class RitualRepository {
  /// FR-075 — seri listesi. Silinenler (tombstone) dahil DEĞİL.
  Stream<Result<List<Ritual>>> watchRituals();

  /// Seri detayı. Kayıt yoksa `Ok(null)` — silinmiş bir serinin bağlantısına
  /// tıklamak olağan bir durum, hata değil.
  Stream<Result<Ritual?>> watchRitual(String id);

  Future<Result<Ritual?>> findRitual(String id);

  /// Oluşturur veya günceller. Dönen değer kaydedilen serinin kimliğidir.
  Future<Result<String>> save(RitualDraft draft);

  /// Seri kimliği → (anı kimliği, hangi yıla ait).
  ///
  /// BR-012 / TR-M6-04: `occurrenceYear` bu tabloda ZORUNLU — ritüelin hangi
  /// yılına ait olduğu bilinmeden "yılları yan yana karşılaştırma" (FR-076)
  /// kurulamaz.
  Stream<Result<Map<String, List<RitualOccurrence>>>> watchOccurrences();

  /// Seri kimliği → bağlı kişi kimlikleri.
  ///
  /// Anılardan ayrı bir akış: kişi bağı değişince anı listesini yeniden
  /// çekmek gereksiz iş olurdu.
  Stream<Result<Map<String, Set<String>>>> watchPeopleLinks();

  /// TR-M6-11'in seri karşılığı: seri silinince ANILAR SİLİNMEZ.
  ///
  /// TR-C-32: fiziksel silme yapılmaz, tombstone yazılır.
  Future<Result<Unit>> softDelete(String id);
}

/// Bir serinin tek bir yıldaki anısı.
typedef RitualOccurrence = ({String memoryId, int year});

/// Seri formunun taşıdığı veri.
///
/// [Ritual]'dan AYRI bir tip: burada [id] boş olabilir (yeni kayıt) ve
/// [memoryIds] var — o, entity'de değil ayrı bir bağ tablosunda yaşıyor.
final class RitualDraft {
  const RitualDraft({
    required this.title,
    this.id,
    this.recurrenceType = RecurrenceType.yearly,
    this.personIds,
    this.anchorMonth,
    this.anchorDay,
    this.iconKey = 'ritual',
    this.occurrences,
  });

  /// `null` → yeni kayıt; dolu → güncelleme.
  final String? id;

  final String title;
  final RecurrenceType recurrenceType;

  /// FR-064 — seriye bağlı KİŞİLER.
  ///
  /// ÇOKLU: bir seri birden fazla kişiyle paylaşılıyor ("Aile
  /// Yemeklerimiz"). Bir süre tekil bir sütunda tutuluyordu ve form çoklu
  /// seçim gösterip tekil kaydetmek zorunda kalıyordu; şema v7 ile bağ
  /// tablosuna geçti.
  ///
  /// `null` ile boş küme AYNI ŞEY DEĞİL — [occurrences] ile aynı ayrım:
  ///   • `null`  → "bağlara dokunma"
  ///   • `{}`    → "hepsini kaldır"
  final Set<String>? personIds;

  final int? anchorMonth;
  final int? anchorDay;
  final String iconKey;

  /// Seriye bağlanacak anılar ve ait oldukları yıllar.
  ///
  /// `null` ile boş liste AYNI ŞEY DEĞİL:
  ///   • `null`  → "bağlara dokunma" (yalnız başlığı düzenleyen form)
  ///   • `[]`    → "bağların hepsini kaldır"
  /// Koleksiyon tarafındaki ayrımın aynısı; kaldırsaydık adını değiştirmek
  /// için açılan bir form serinin tüm anılarını sessizce koparırdı.
  final List<RitualOccurrence>? occurrences;
}
