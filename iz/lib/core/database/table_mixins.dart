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
