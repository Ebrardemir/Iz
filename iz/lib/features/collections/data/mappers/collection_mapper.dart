/// Veritabanı satırı ↔ domain nesnesi çevirisi.
///
/// NEDEN BURADA, `memory_mapper.dart`TA DEĞİL?
/// Bu sınıf bir süre anılar feature'ının mapper dosyasında yaşadı, çünkü tek
/// kullanıcısı anı detayıydı. Artık koleksiyonun kendi veri hattı var; iki
/// ayrı kopya tutmak, birinin gün gelip ötekinden ayrışması demekti — kişi
/// tarafında `relationLabel`ın sessizce düşmesi tam olarak böyle olmuştu.
/// Tek tanım burada; anılar mapper'ı bunu import ediyor.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/collections/domain/entities/memory_collection.dart';
import 'package:iz/features/collections/domain/repositories/collection_repository.dart';

abstract final class CollectionMapper {
  static MemoryCollection toDomain(CollectionRow row) => MemoryCollection(
    id: row.id,
    title: row.title,
    description: row.description,
    coverMediaId: row.coverMediaId,
    visibility: row.visibility,
    startDate: row.startDate,
    endDate: row.endDate,
  );

  /// Formu veritabanı satırına çevirir.
  ///
  /// [id] çağıran taraftan geliyor — gerekçesi `person_mapper.dart`taki
  /// notun aynısı: mapper saf bir çeviri olmalı, `IdGenerator` bir bağımlılık.
  static CollectionsCompanion toCompanion(
    CollectionDraft draft, {
    required String id,
  }) {
    // Boş metin ile "yazılmamış" aynı şey. Veritabanına '' yazmak, sonra her
    // okuma yerinde `isEmpty` kontrolü gerektirirdi.
    final description = draft.description?.trim();

    return CollectionsCompanion.insert(
      id: id,
      title: draft.title.trim(),
      description: Value(
        (description == null || description.isEmpty) ? null : description,
      ),
      coverMediaId: Value(draft.coverMediaId),
      // BR-003 — varsayılan private. Paylaşım koleksiyonun temel birimi
      // olduğu için kullanıcı paylaşmayı ayrıca seçmeli.
      visibility: Value(draft.visibility),
      startDate: Value(draft.startDate),
      endDate: Value(draft.endDate),
    );
  }
}
