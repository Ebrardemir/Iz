/// Yerel kullanıcı kaydı — M1.2.
///
/// NEDEN ŞİMDİ, GİRİŞ HENÜZ YERELKEN?
/// Her tablo `OwnedTable.ownerId` taşıyor ve bugün hepsinde `'local'`
/// yazıyor. `Users` tablosu geldiğinde bu değerlerin gerçek bir satıra
/// işaret etmesi gerekiyor (TR-M1-01). Tabloyu bugün kurup `'local'`
/// kullanıcısını tohumlarsak, hesap açıldığı gün yapılacak iş bir satırı
/// GÜNCELLEMEK olur — binlerce `ownerId`yi taşımak değil.
library;

import 'package:drift/drift.dart';
import 'package:iz/core/database/table_mixins.dart';
import 'package:iz/features/media/data/tables/media_tables.dart';

@DataClassName('UserRow')
class Users extends Table with SyncableTable {
  /// TR-M1-06 — e-posta burada da tutuluyor (hesap silme ve destek için),
  /// ama TEK GERÇEK KAYNAK Firebase'dir. `null` = henüz hesap açılmadı.
  TextColumn get email => text().nullable()();

  TextColumn get displayName => text().nullable()();

  /// Kullanıcının seçtiği dil. `shared_preferences`taki `locale` ile aynı
  /// bilgi ama burada da duruyor: hesap ikinci bir cihazda açıldığında
  /// tercih onunla birlikte gelsin.
  TextColumn get locale => text().nullable()();

  TextColumn get avatarMediaId => text().nullable().references(
    MediaItems,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Hesabı olmayan kullanıcının satırı. `OwnedTable.ownerId`nin
  /// varsayılanıyla AYNI değer olmak zorunda — yoksa yabancı anahtar
  /// hiçbir şeye işaret etmez.
  static const localId = 'local';
}
