/// Tüm tabloların paylaştığı sütunlar.
///
/// Rapor 12.2 "Senkronizasyon için veri modelleme kararı":
///   • Her mutable kayıt `updatedAt` ve `version` taşımalıdır.
///   • Silmeler tombstone/soft-delete olarak temsil edilmelidir.
///
/// Bunları MVP'de bile eklememizin sebebi: V1.5'te bulut senkronizasyonu
/// geldiğinde şemayı baştan yazmak zorunda kalmamak. Şimdi 4 sütun,
/// sonra kurtarılmış bir migration.
library;

import 'package:drift/drift.dart';

/// Senkronize edilebilir her tablo bunu kullanır.
///
/// KULLANIM:
/// ```dart
/// class Memories extends Table with SyncableTable {
///   TextColumn get title => text().nullable()();
/// }
/// ```
mixin SyncableTable on Table {
  /// UUID v7 — cihazlar arası benzersiz ve zaman sıralı.
  TextColumn get id => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Çakışma çözümünde (V1.5) karşılaştırılacak alan.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Soft delete / tombstone. FR-015'teki "çöp kutusu" da buna dayanır:
  /// dolu ise kayıt çöpte, 30 gün sonra kalıcı silinir.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Her yazmada +1. Sunucu ile istemci sürümünü karşılaştırmak için.
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Kullanıcıya ait kayıtlar için. MVP'de tek yerel kullanıcı var ama
/// sütunu şimdiden koyuyoruz: V1.5'te çoklu hesap geldiğinde tablo
/// yeniden yazılmasın.
mixin OwnedTable on Table {
  TextColumn get ownerId => text().withDefault(const Constant('local'))();
}

/// N-N **bağ** tabloları için — `SyncableTable`ın kimliksiz kardeşi.
///
/// NEDEN AYRI BİR MIXIN?
/// `SyncableTable` bir `id` sütunu ve `primaryKey = {id}` dayatıyor. Bağ
/// tablosunun kimliği ise zaten `(memoryId, personId)` çifti; ona ayrıca bir
/// UUID vermek hem gereksiz hem tehlikeli olurdu — aynı çift iki farklı
/// kimlikle iki kez girebilirdi. Bu yüzden bileşik anahtar KORUNUYOR,
/// yalnız senkronizasyon sütunları ekleniyor.
///
/// NEDEN BAĞLAR DA TOMBSTONE OLMALI (rapor §1.1):
/// Bağı gerçekten SİLERSEK, ikinci cihaz o satırı hiç görmez ve "bende var,
/// sende yok" durumunu "sen henüz almamışsın" diye okur — çıkarılan kişiyi
/// geri ekler. Kullanıcı anıdan kişiyi çıkarır, bir sonraki eşitlemede kişi
/// geri gelir. Silmeyi bir SATIR olarak saklamak bunun tek çaresi.
mixin SyncableLink on Table {
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Dolu ise bağ KOPARILMIŞ. Okuyan her sorgu `deletedAt IS NULL` süzmek
  /// zorunda — atlanırsa silinmiş ilişkiler ekranda görünmeye başlar.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();
}
