/// Günlük deposu **sözleşmesi**.
///
/// KURAL: hiçbir metot exception fırlatmaz — hepsi `Result` döner (TR-C-02).
library;

import 'package:iz/core/result/result.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';

abstract interface class JournalRepository {
  /// FR-030 — günlük listesi, en yeni gün üstte. Silinenler dahil DEĞİL.
  Stream<Result<List<JournalEntry>>> watchEntries();

  /// Tek kayıt. Yoksa `Ok(null)` — silinmiş bir kaydın bağlantısına tıklamak
  /// olağan bir durum, hata değil.
  Stream<Result<JournalEntry?>> watchEntry(String id);

  Future<Result<JournalEntry?>> findEntry(String id);

  /// Ana sayfadaki sayaç için.
  ///
  /// Listeyi sayıp uzunluğuna bakmıyoruz: 2.000 kayıtta hepsini belleğe
  /// almak bir sayı için ağır olurdu (NFR-003).
  Stream<Result<int>> watchCount();

  /// Oluşturur veya günceller. Dönen değer kaydedilen kaydın kimliğidir.
  Future<Result<String>> save(JournalDraft draft);

  Future<Result<Unit>> setFavorite(String id, {required bool isFavorite});

  /// TR-C-32 — fiziksel silme yok, tombstone.
  Future<Result<Unit>> softDelete(String id);
}

/// Günlük formunun taşıdığı veri.
///
/// [JournalEntry]'den AYRI bir tip: burada [id] boş olabilir (yeni kayıt).
final class JournalDraft {
  const JournalDraft({
    required this.entryDate,
    required this.text,
    this.id,
    this.title,
    this.moodScore,
    this.moodKey,
    this.promptId,
    this.privacyMode = JournalPrivacyMode.standard,
    this.isFavorite = false,
    this.mediaIds,
  });

  /// `null` → yeni kayıt; dolu → güncelleme.
  final String? id;

  /// Kaydın ait olduğu GÜN — yazıldığı an değil.
  ///
  /// Kullanıcı dün yaşadığı bir günü bugün yazabilir ve o kayıt dünün
  /// yerinde durmalı.
  final DateTime entryDate;

  final String text;
  final String? title;

  /// FR-030 — bugünkü ruh hâli, 1..10. null = işaretlenmedi.
  final int? moodScore;
  final String? moodKey;

  /// FR-032/FR-036 — prompt kütüphanesi referansı.
  final String? promptId;

  /// FR-035 — gizlilik modu.
  final JournalPrivacyMode privacyMode;

  final bool isFavorite;

  /// `null` ile boş liste AYNI ŞEY DEĞİL:
  ///   • `null`  → "bağlara dokunma"
  ///   • `[]`    → "hepsini kaldır"
  /// Koleksiyon ve seri taraflarındaki ayrımın aynısı.
  final List<String>? mediaIds;
}
