/// [MemoryCategory] → ekranda görünecek ad köprüsü.
///
/// NEDEN AYRI DOSYA?
/// `failure_l10n.dart` ile aynı gerekçe: entity domain katmanında yaşar ve
/// dili bilmez. Sistem kategorilerinin adı ise dile göre değişir. İkisini
/// burada, presentation katmanında birleştiriyoruz.
///
/// KULLANIM:
/// ```dart
/// Text(category.displayName(context.l10n))
/// ```
library;

import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/features/categories/domain/entities/memory_category.dart';

extension MemoryCategoryL10nX on MemoryCategory {
  /// Sistem kategorisiyse çevirisini, kullanıcı kategorisiyse kullanıcının
  /// yazdığı adı döner.
  ///
  /// Kullanıcının "Kedim" diye açtığı kategori ÇEVRİLMEZ — o bir veridir,
  /// arayüz metni değil. Ayrımı [MemoryCategory.isSystem] yapar.
  String displayName(AppL10n l10n) {
    if (!isSystem) return name;
    return systemCategoryName(name, l10n) ?? name;
  }
}

/// Çeviri anahtarını okunabilir ada çevirir.
///
/// `switch` üzerinde `SystemCategory.values.asNameMap()` gibi bir kısayol
/// KULLANMIYORUZ: üretilen `AppL10n` sınıfına anahtarla (string) erişilemez,
/// her alan ayrı bir getter'dır. Bu switch, yeni bir sistem kategorisi
/// eklendiğinde çevirisini yazmayı unutursan derleyicinin seni uyarmasını
/// sağlar.
String? systemCategoryName(String nameKey, AppL10n l10n) {
  final category = SystemCategory.values
      .where((c) => c.nameKey == nameKey)
      .firstOrNull;
  if (category == null) return null;

  return switch (category) {
    SystemCategory.travel => l10n.categoryTravel,
    SystemCategory.family => l10n.categoryFamily,
    SystemCategory.relationships => l10n.categoryRelationships,
    SystemCategory.celebrations => l10n.categoryCelebrations,
    SystemCategory.education => l10n.categoryEducation,
    SystemCategory.career => l10n.categoryCareer,
    SystemCategory.home => l10n.categoryHome,
    SystemCategory.daily => l10n.categoryDaily,
  };
}
