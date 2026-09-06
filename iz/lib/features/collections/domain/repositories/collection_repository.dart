/// Koleksiyon deposu **sözleşmesi**.
///
/// Gerekçesi `PersonRepository` ile aynı: domain "veriyi nasıl aldığımı
/// bilmem, ne aldığımı bilirim" der.
///
/// KURAL: hiçbir metot exception fırlatmaz — hepsi `Result` döner (TR-C-02).
library;

import 'package:iz/core/result/result.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';

abstract interface class CollectionRepository {
  /// FR-073 — koleksiyon listesi. Veri değiştiğinde kendiliğinden yeniden
  /// yayınlar. Silinenler (tombstone) dahil DEĞİL.
  Stream<Result<List<MemoryCollection>>> watchCollections();

  /// Koleksiyon detayı. Kayıt yoksa `Ok(null)` — bu bir hata değil, silinmiş
  /// bir koleksiyonun bağlantısına tıklamak olağan bir durum.
  Stream<Result<MemoryCollection?>> watchCollection(String id);

  Future<Result<MemoryCollection?>> findCollection(String id);

  /// Koleksiyon kimliği → içindeki anı kimlikleri (kullanıcının dizdiği sırada).
  ///
  /// Anıların KENDİSİ burada dönmüyor: onları `MemoryRepository` veriyor.
  /// İki depo aynı anı sorgusunu ayrı ayrı kursaydı, biri gün gelip
  /// ötekinden ayrışırdı.
  Stream<Result<Map<String, List<String>>>> watchMemoryLinks();

  /// Oluşturur veya günceller. Dönen değer kaydedilen koleksiyonun kimliğidir.
  Future<Result<String>> save(CollectionDraft draft);

  /// TR-M6-11 — koleksiyon silindiğinde ANILAR SİLİNMEZ, yalnız bağ kopar.
  ///
  /// TR-C-32: fiziksel silme yapılmaz. Senkronizasyon geldiğinde "bu
  /// koleksiyonu sildim" olayının diğer cihaza taşınabilmesi buna bağlı.
  Future<Result<Unit>> softDelete(String id);
}

/// Koleksiyon formunun taşıdığı veri.
///
/// [MemoryCollection]'dan AYRI bir tip: burada [id] boş olabilir (yeni kayıt)
/// ve [memoryIds] var — o, entity'de değil ayrı bir bağ tablosunda yaşıyor.
final class CollectionDraft {
  const CollectionDraft({
    required this.title,
    this.id,
    this.description,
    this.coverMediaId,
    this.visibility = CollectionVisibility.private,
    this.startDate,
    this.endDate,
    this.memoryIds,
  });

  /// `null` → yeni kayıt; dolu → güncelleme.
  final String? id;

  final String title;
  final String? description;
  final String? coverMediaId;

  /// BR-003 — varsayılan private.
  final CollectionVisibility visibility;

  /// Seyahat/dönem koleksiyonları için opsiyonel tarih aralığı.
  final DateTime? startDate;
  final DateTime? endDate;

  /// Koleksiyona bağlanacak anılar.
  ///
  /// `null` ile boş liste AYNI ŞEY DEĞİL:
  ///   • `null`  → "bağlara dokunma" (yalnız başlığı düzenleyen form)
  ///   • `[]`    → "bağların hepsini kaldır"
  /// Ayrımı kaldırsaydık, adını değiştirmek için açılan bir form
  /// koleksiyonun tüm anılarını sessizce koparırdı.
  final List<String>? memoryIds;
}
