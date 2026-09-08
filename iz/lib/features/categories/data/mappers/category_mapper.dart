/// Veritabanı satırı ↔ domain nesnesi çevirisi.
///
/// Gerekçesi `memory_mapper.dart` başındaki notta: Drift'in ürettiği satır
/// sınıfı şema değişince değişir; mapper bu değişimi tek noktada emer.
library;

import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/categories/domain/entities/memory_category.dart';

abstract final class CategoryMapper {
  static MemoryCategory toDomain(CategoryRow row) => MemoryCategory(
    id: row.id,
    // TR-M6-02 — SİSTEM kategorisinde bu alan bir ÇEVİRİ ANAHTARI, ekranda
    // gösterilecek metin değil ("categoryTravel"). Kullanıcı kategorisinde
    // ise doğrudan yazdığı ad. Ayrımı `isSystem` yapıyor ve çeviriye
    // dönüştürmeyi `category_l10n.dart` üstleniyor — veritabanına Türkçe
    // metin gömülmüyor (TR-C-43).
    name: row.name,
    iconKey: row.iconKey,
    sortOrder: row.sortOrder,
    isSystem: row.isSystem,
  );
}
