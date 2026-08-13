/// Anı deposu **sözleşmesi**.
///
/// NEDEN ARAYÜZ (interface)?
/// Domain katmanı "veriyi nasıl aldığımı bilmem, ne aldığımı bilirim" der.
/// Bugün Drift'ten geliyor; V1.5'te aynı arayüzün arkasına bir
/// `SyncingMemoryRepository` koyup buluta bağlanacağız ve ViewModel'lerin
/// TEK SATIRI değişmeyecek.
///
/// Ayrıca testte `FakeMemoryRepository` yazmak mock kütüphanesinden bile kolay.
///
/// KURAL: Buradaki hiçbir metot exception fırlatmaz — hepsi `Result` döner.
library;

import 'package:iz/core/result/result.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';

abstract interface class MemoryRepository {
  /// Timeline/liste akışı. Veri değiştiğinde kendiliğinden yeniden yayınlar.
  Stream<Result<List<Memory>>> watchMemories(MemoryFilter filter);

  /// FR-020 — detay ekranı (ilişkiler yüklü).
  Stream<Result<MemoryDetail?>> watchDetail(String id);

  Future<Result<MemoryDetail?>> findDetail(String id);

  /// FR-010/FR-014 — oluşturur veya günceller.
  /// Dönen değer kaydedilen anının id'sidir (yeni kayıtta üretilen id).
  Future<Result<String>> saveDraft(MemoryDraft draft);

  /// FR-019
  Future<Result<Unit>> setFavorite(String id, {required bool isFavorite});

  /// FR-014
  Future<Result<Unit>> setArchived(String id, {required bool isArchived});

  /// FR-015 — çöp kutusuna taşır (geri alınabilir).
  Future<Result<Unit>> moveToTrash(String id);

  Future<Result<Unit>> restoreFromTrash(String id);

  /// Saklama süresi dolmuş çöp kayıtlarını kalıcı siler. Kaç kayıt
  /// silindiğini döner.
  Future<Result<int>> purgeExpiredTrash();

  /// FR-080 — "Bugünün İzi" kartları.
  Future<Result<List<Memory>>> findOnThisDay(DateTime day);

  /// Ana ekran istatistiği / boş durum kontrolü.
  Future<Result<int>> countAll();
}
