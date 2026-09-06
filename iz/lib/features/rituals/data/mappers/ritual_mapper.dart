/// Veritabanı satırı ↔ domain nesnesi çevirisi.
///
/// NEDEN BURADA, `memory_mapper.dart`TA DEĞİL?
/// Bu sınıf bir süre anılar feature'ının mapper dosyasında yaşadı, çünkü tek
/// kullanıcısı anı detayıydı. Artık serinin kendi veri hattı var; iki ayrı
/// kopya tutmak, birinin gün gelip ötekinden ayrışması demekti. Koleksiyon ve
/// medya tarafında da aynı taşımayı yaptık.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/features/rituals/domain/repositories/ritual_repository.dart';

abstract final class RitualMapper {
  static Ritual toDomain(RitualRow row) => Ritual(
    id: row.id,
    title: row.title,
    recurrenceType: row.recurrenceType,
    relatedPersonId: row.relatedPersonId,
    anchorMonth: row.anchorMonth,
    anchorDay: row.anchorDay,
    iconKey: row.iconKey,
  );

  /// Formu veritabanı satırına çevirir.
  ///
  /// [id] çağıran taraftan geliyor — gerekçesi `person_mapper.dart`taki
  /// notun aynısı: mapper saf bir çeviri olmalı, `IdGenerator` bir bağımlılık.
  static RitualsCompanion toCompanion(
    RitualDraft draft, {
    required String id,
  }) => RitualsCompanion.insert(
    id: id,
    title: draft.title.trim(),
    recurrenceType: Value(draft.recurrenceType),
    relatedPersonId: Value(draft.relatedPersonId),
    anchorMonth: Value(draft.anchorMonth),
    anchorDay: Value(draft.anchorDay),
    iconKey: Value(draft.iconKey),
  );
}
