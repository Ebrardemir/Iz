/// Veritabanı satırı ↔ domain nesnesi çevirisi.
///
/// Gerekçesi `memory_mapper.dart` başındaki notta: Drift'in ürettiği satır
/// sınıfı şema değişince değişir; mapper bu değişimi tek noktada emer.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/journal/domain/repositories/journal_repository.dart';

abstract final class JournalMapper {
  /// [mediaIds] AYRI GELİYOR: bağ ayrı bir tabloda yaşıyor ve mapper saf bir
  /// çeviri olmalı — sorgu açamaz.
  static JournalEntry toDomain(
    JournalEntryRow row, {
    List<String> mediaIds = const [],
  }) => JournalEntry(
    id: row.id,
    entryDate: row.entryDate,
    // DİKKAT: sütun adı `content`, domain alanı `text`. `text` Drift'in
    // sütun kurucu metodudur, aynı adı sütuna veremiyoruz (bkz.
    // journal_tables.dart).
    text: row.content,
    title: row.title,
    createdAt: row.createdAt,
    moodScore: row.moodScore,
    moodKey: row.moodKey,
    promptId: row.promptId,
    privacyMode: row.privacyMode,
    isFavorite: row.isFavorite,
    convertedMemoryId: row.convertedMemoryId,
    mediaIds: mediaIds,
  );

  /// Formu veritabanı satırına çevirir.
  ///
  /// [id] çağıran taraftan geliyor — gerekçesi `person_mapper.dart`taki
  /// notun aynısı: mapper saf bir çeviri olmalı, `IdGenerator` bir bağımlılık.
  static JournalEntriesCompanion toCompanion(
    JournalDraft draft, {
    required String id,
  }) {
    // Boş metin ile "yazılmamış" aynı şey; '' yazmak her okuma yerinde
    // ayrıca `isEmpty` kontrolü gerektirirdi.
    final title = draft.title?.trim();

    return JournalEntriesCompanion.insert(
      id: id,
      // GÜN BAZINDA: saat bileşenini atıyoruz. Takvim görünümü kayıtları
      // güne göre gruplandırıyor ve aynı günün iki kaydı farklı saatlerde
      // farklı kovalara düşerdi.
      entryDate: DateTime(
        draft.entryDate.year,
        draft.entryDate.month,
        draft.entryDate.day,
      ),
      content: Value(draft.text.trim()),
      title: Value((title == null || title.isEmpty) ? null : title),
      moodScore: Value(draft.moodScore),
      moodKey: Value(draft.moodKey),
      promptId: Value(draft.promptId),
      privacyMode: Value(draft.privacyMode),
      isFavorite: Value(draft.isFavorite),
    );
  }
}
