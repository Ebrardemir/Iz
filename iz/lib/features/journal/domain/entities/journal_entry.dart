/// Günlük kaydı — "Günün İzi".
///
/// BR-011 (KRİTİK AYRIM): "Günlük kaydı Anı değildir; kullanıcı isterse
/// dönüştürür. Dönüşüm orijinal günlük kaydını otomatik silmez."
///
/// Rapor 7.3: günlük serbest ve sık; Anı seçilmiş ve anlamlandırılmış.
/// R-012 riski: bu ayrım UX'te bulanıklaşırsa ürünün çekirdeği dağılır.
library;

import 'package:equatable/equatable.dart';

/// FR-035 — bir günlük kaydı özel olarak kilitlenebilir veya sadece
/// cihazda tutulabilir şekilde işaretlenebilir.
enum JournalPrivacyMode {
  /// Normal: senkronizasyona dahil (V1.5).
  standard,

  /// Uygulama kilidi (FR-005) açılmadan görünmez.
  locked,

  /// Asla buluta gitmez — bu cihazda kalır.
  deviceOnly,
}

final class JournalEntry extends Equatable {
  const JournalEntry({
    required this.id,
    required this.entryDate,
    required this.text,
    required this.privacyMode,
    this.title,
    this.createdAt,
    this.promptId,
    this.mediaIds = const [],
    this.convertedMemoryId,
    this.moodKey,
    this.moodScore,
    this.isFavorite = false,
  });

  final String id;

  /// Hangi güne ait. Saat taşımaz — takvim görünümü (FR-033) bunu kullanır.
  final DateTime entryDate;

  final String text;

  /// Kullanıcının bugüne verdiği ad ("Uzun bir gün").
  ///
  /// OPSİYONEL: günlük serbest ve sık yazılıyor (rapor 7.3); başlık zorunlu
  /// olsaydı yazma eşiği yükselirdi. Boşsa liste tarihi gösteriyor.
  final String? title;

  /// Kaydın YAZILDIĞI an — saatiyle birlikte.
  ///
  /// [entryDate] ile ikisi ayrı: biri günlüğün AİT OLDUĞU gün (takvim onu
  /// grupluyor, FR-033), bu ise kaydın oluşturulma anı. Liste satırında
  /// "21:30" yazan yer burası; gün bazlı bir tarihten saat üretilemezdi.
  ///
  /// Veritabanında zaten var (`SyncableTable.createdAt`); domain nesnesi
  /// şimdiye kadar taşımıyordu.
  final DateTime? createdAt;

  /// FR-032 — hangi prompta cevap verildi ("Bugün neyin izini bırakmak
  /// istersin?"). null ise serbest yazım.
  final String? promptId;

  /// FR-031 — MVP sınırları içinde fotoğraf.
  final List<String> mediaIds;

  /// FR-034 — anıya dönüştürüldüyse hedef anının id'si.
  /// Dolu olması günlüğün silindiği anlamına GELMEZ (BR-011).
  final String? convertedMemoryId;

  final String? moodKey;

  /// FR-030 — bugünkü ruh hâli, 1..10.
  ///
  /// [moodKey] ile birlikte YAŞIYOR, onun yerine geçmiyor: anahtar bir DUYGU
  /// ("huzurlu"), puan ise bir ŞİDDET. Ekranda şimdilik yalnızca puan var
  /// (kullanıcı duygu etiketlerini istemedi) ama anahtar veri modelinde
  /// duruyor — ileride "en huzurlu günlerim" gibi bir arama onsuz olmuyor.
  ///
  /// null = kullanıcı kaydırıcıya hiç dokunmadı. Sıfır DEĞİL: "0" ölçekte
  /// olmayan bir değer ve "hiç işaretlemedim" ile "en kötü gün" aynı şey
  /// değil.
  final int? moodScore;
  final JournalPrivacyMode privacyMode;

  /// Kullanıcının YILDIZLADIĞI yazı.
  ///
  /// Anılardaki `isFavorite` (kalp) ile aynı fikir ama ayrı alan: biri
  /// "sevdiğim anı", öteki "sık döndüğüm yazı". Aynı kovaya koymak ikisini de
  /// anlamsızlaştırırdı.
  final bool isFavorite;

  bool get isConverted => convertedMemoryId != null;
  bool get isLocked => privacyMode == JournalPrivacyMode.locked;
  bool get syncable => privacyMode != JournalPrivacyMode.deviceOnly;

  /// Liste görünümünde gösterilecek kısa özet.
  String get preview {
    final trimmed = text.trim();
    if (trimmed.length <= 120) return trimmed;
    return '${trimmed.substring(0, 117)}...';
  }

  JournalEntry copyWith({
    DateTime? entryDate,
    String? text,
    String? title,
    DateTime? createdAt,
    String? promptId,
    List<String>? mediaIds,
    String? convertedMemoryId,
    String? moodKey,
    int? moodScore,
    JournalPrivacyMode? privacyMode,
    bool? isFavorite,
  }) => JournalEntry(
    id: id,
    entryDate: entryDate ?? this.entryDate,
    text: text ?? this.text,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    promptId: promptId ?? this.promptId,
    mediaIds: mediaIds ?? this.mediaIds,
    convertedMemoryId: convertedMemoryId ?? this.convertedMemoryId,
    moodKey: moodKey ?? this.moodKey,
    moodScore: moodScore ?? this.moodScore,
    privacyMode: privacyMode ?? this.privacyMode,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  @override
  List<Object?> get props => [
    id,
    entryDate,
    text,
    title,
    createdAt,
    promptId,
    mediaIds,
    convertedMemoryId,
    moodKey,
    moodScore,
    privacyMode,
    isFavorite,
  ];
}
