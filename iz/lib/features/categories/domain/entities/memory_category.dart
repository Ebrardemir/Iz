/// Kategori — "genel tema" (Seyahat, Aile, Kutlamalar...).
///
/// `Category` yerine `MemoryCategory` adını kullanıyoruz; `Category` çok
/// genel bir ad ve başka paketlerle çakışması muhtemel.
///
/// FR-072 / FR-138 / rapor 14.2: kategori sayısını paywall yapmak ürün
/// stratejisi DEĞİL. Sınır varsayılan olarak sınırsızdır.
library;

import 'package:equatable/equatable.dart';

final class MemoryCategory extends Equatable {
  const MemoryCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.sortOrder,
    this.isSystem = false,
  });

  final String id;

  /// Kullanıcının verdiği ad.
  ///
  /// ⚠️ [isSystem] true ise burada AD DEĞİL, bir çeviri ANAHTARI durur
  /// (`travel`, `family`…). Sistem kategorilerinin adı dile göre değişir;
  /// veritabanına Türkçe yazsaydık İngilizce arayüzde de Türkçe görünürdü.
  /// Ekranda göstermek için `displayName(l10n)` kullan
  /// (bkz. features/categories/presentation/category_l10n.dart).
  final String name;

  /// Material ikon adı yerine kendi anahtarımız — ikon setini
  /// değiştirsek bile veri bozulmasın. Anahtarı çizime çeviren tablo:
  /// `core/theme/app_icons.dart` → `AppIcons.forKey(iconKey)`.
  final String iconKey;

  final int sortOrder;

  /// FR-070 varsayılan kategorileri: kullanıcı silemez, yalnız gizleyebilir.
  final bool isSystem;

  MemoryCategory copyWith({String? name, String? iconKey, int? sortOrder}) =>
      MemoryCategory(
        id: id,
        name: name ?? this.name,
        iconKey: iconKey ?? this.iconKey,
        sortOrder: sortOrder ?? this.sortOrder,
        isSystem: isSystem,
      );

  @override
  List<Object?> get props => [id, name, iconKey, sortOrder, isSystem];
}

/// Sistem kategorilerinin kimlikleri ve çeviri anahtarları.
///
/// Bu değerler veritabanına yazılır ve **asla değişmez** — kullanıcının
/// cihazındaki kayıtlar bunlara bağlıdır. Görünen ad ise her dilde farklıdır
/// ve `category_l10n.dart` içinde çözülür.
enum SystemCategory {
  travel(id: 'cat_travel', iconKey: 'travel'),
  family(id: 'cat_family', iconKey: 'family'),
  relationships(id: 'cat_relationships', iconKey: 'heart'),
  celebrations(id: 'cat_celebrations', iconKey: 'celebration'),
  education(id: 'cat_education', iconKey: 'school'),
  career(id: 'cat_career', iconKey: 'work'),
  home(id: 'cat_home', iconKey: 'home'),
  daily(id: 'cat_daily', iconKey: 'daily');

  const SystemCategory({required this.id, required this.iconKey});

  /// Veritabanı satırının birincil anahtarı.
  final String id;
  final String iconKey;

  /// `name` sütununa yazılan çeviri anahtarı (enum'ın kendi adı).
  String get nameKey => name;
}

/// FR-070: "Sistem Seyahat, Aile, İlişkiler, Kutlamalar, Eğitim, Kariyer,
/// Ev, Günlük Yaşam gibi varsayılan kategoriler sunmalıdır."
///
/// İlk açılışta veritabanına tohumlanır (bkz. AppDatabase.onCreate).
abstract final class DefaultCategories {
  static const List<SystemCategory> seed = SystemCategory.values;
}
