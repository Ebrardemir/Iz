/// Kategori deposu **sözleşmesi**.
///
/// YALNIZ OKUMA — bilinçli. FR-070/071 kullanıcı kategorisi açmayı da
/// tanımlıyor ama o ekran henüz yok; yazma metotlarını şimdiden koymak,
/// kullanılmayan bir yüzeyi taşımak olurdu.
///
/// KURAL: hiçbir metot exception fırlatmaz — hepsi `Result` döner (TR-C-02).
library;

import 'package:iz/core/result/result.dart';
import 'package:iz/features/categories/domain/entities/memory_category.dart';

abstract interface class CategoryRepository {
  /// FR-070 — kategori listesi, tanımlı düzende.
  ///
  /// Sistem kategorileri ilk açılışta tohumlanıyor, yani liste hiçbir zaman
  /// boş değil.
  Stream<Result<List<MemoryCategory>>> watchCategories();

  /// Tek kategori. Kayıt yoksa `Ok(null)` — silinmiş bir kategorinin
  /// kimliğini taşıyan bir anı olağan bir durum (TR-M6-10: kategori
  /// silinince anı silinmez, `categoryId` null'a düşer).
  Future<Result<MemoryCategory?>> findCategory(String id);
}
