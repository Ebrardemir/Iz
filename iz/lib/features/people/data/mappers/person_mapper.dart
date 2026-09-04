/// Veritabanı satırı ↔ domain nesnesi çevirisi.
///
/// Gerekçesi `memory_mapper.dart` başındaki notta: Drift'in ürettiği satır
/// sınıfı şema değişince değişir; mapper bu değişimi tek noktada emer.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/people/domain/relation_guess.dart';
import 'package:iz/features/people/domain/repositories/person_repository.dart';

abstract final class PersonMapper {
  static Person toDomain(PersonRow row) => Person(
    id: row.id,
    name: row.name,
    kind: row.kind,
    relationType: row.relationType,
    relationLabel: row.relationLabel,
    birthDate: row.birthDate,
    avatarMediaId: row.avatarMediaId,
    note: row.note,
    isFavorite: row.isFavorite,
  );

  /// Formu veritabanı satırına çevirir.
  ///
  /// [id] çağıran taraftan geliyor: yeni kayıtta üretilmiş bir UUID v7,
  /// güncellemede mevcut kimlik. Kimliği burada üretmiyoruz çünkü mapper
  /// saf bir çeviri olmalı — `IdGenerator` bir bağımlılıktır ve onu buraya
  /// sokmak mapper'ı test edilebilir olmaktan çıkarırdı.
  static PeopleCompanion toCompanion(PersonDraft draft, {required String id}) {
    // Boş metin ile "yazılmamış" aynı şey: veritabanına '' yazmak, sonra
    // her okuma yerinde `isEmpty` kontrolü gerektirirdi.
    final label = draft.relationLabel?.trim();
    final normalizedLabel = (label == null || label.isEmpty) ? null : label;

    final note = draft.note?.trim();

    return PeopleCompanion.insert(
      id: id,
      name: draft.name.trim(),
      kind: Value(draft.kind),
      // TÜR YAZILANDAN TÜRETİLİYOR (FR-061). Kullanıcı listeden seçmiyor;
      // "Annem" yazıyor, tür oradan çıkarılıyor. Yanlış tahmin edilse bile
      // ekranda görünen şey kullanıcının yazdığı metin — kayıp yok.
      relationType: Value(
        normalizedLabel == null
            ? RelationType.other
            : guessRelationType(normalizedLabel),
      ),
      relationLabel: Value(normalizedLabel),
      birthDate: Value(draft.birthDate),
      avatarMediaId: Value(draft.avatarMediaId),
      note: Value((note == null || note.isEmpty) ? null : note),
      isFavorite: Value(draft.isFavorite),
    );
  }
}
