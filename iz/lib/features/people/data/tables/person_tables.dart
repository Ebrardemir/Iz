import 'package:drift/drift.dart';
import 'package:iz/core/database/table_mixins.dart';
import 'package:iz/features/people/domain/entities/person.dart';

/// FR-060 — kullanıcının hayatındaki önemli kişiler/özneler.
@DataClassName('PersonRow')
class People extends Table with SyncableTable, OwnedTable {
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get kind =>
      textEnum<PersonKind>().withDefault(const Constant('human'))();
  TextColumn get relationType =>
      textEnum<RelationType>().withDefault(const Constant('other'))();

  /// Kullanıcının KENDİ YAZDIĞI ilişki adı: "Annem", "Kankam", "Komşu Ayla".
  ///
  /// [relationType] makine için, bu insan için — gerekçesi
  /// [Person.relationLabel] doc'unda. İkisi ayrı sütun çünkü tür yazılandan
  /// TÜRETİLİYOR ve tahmin yanlış olsa bile kullanıcının yazdığı metin
  /// ekranda aynen kalmalı.
  ///
  /// v6'da eklendi. Öncesinde entity'de vardı ama sütunu yoktu: kullanıcı
  /// "Annem" yazsa kayıt sırasında sessizce kaybolurdu.
  TextColumn get relationLabel => text().withLength(max: 60).nullable()();

  DateTimeColumn get birthDate => dateTime().nullable()();
  TextColumn get avatarMediaId => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
}
