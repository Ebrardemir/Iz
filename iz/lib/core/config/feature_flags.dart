/// Faz bayrakları — NFR-061: "Feature flag/remote config ile premium limitler
/// ve deneysel özellikler güvenli biçimde açılıp kapatılabilmelidir."
///
/// NEDEN VAR?
/// Rapor MVP → V1.5 → V2 → V2.5 → V3 diye ilerliyor. Yarım kalmış bir V2
/// özelliğini `main` dalında tutabilmek için kodu silmek yerine bayrağı
/// kapatırız. Bu, R-004 riskini (aşırı özellik yükü) yönetmenin yolu.
///
/// KULLANIM (ViewModel/View içinde):
/// ```dart
/// final flags = ref.watch(featureFlagsProvider);
/// if (flags.sharedCollections) { ... }
/// ```
///
/// İleride: [FeatureFlags.remote] fabrikası bir remote-config yanıtından
/// beslenecek; çağrı yerlerinin hiçbiri değişmeyecek.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

final class FeatureFlags {
  const FeatureFlags({
    this.cloudSync = false,
    this.videoMemories = false,
    this.audioMemories = false,
    this.memoryMap = false,
    this.yearInReview = false,
    this.sharedCollections = false,
    this.comments = false,
    this.workshop = false,
    this.sponsoredContent = false,
    this.timeCapsule = false,
    this.aiAssist = false,
    this.semanticSearch = false,
  });

  /// MVP (İZ 1.0) — rapor 16.1. Sadece çekirdek açık.
  const FeatureFlags.mvp() : this();

  /// V1.5 — bulut ve zengin medya (rapor 16.2).
  const FeatureFlags.v15()
    : this(
        cloudSync: true,
        videoMemories: true,
        audioMemories: true,
        memoryMap: true,
        yearInReview: true,
      );

  /// V2 — yakınlarla birlikte (rapor 16.3).
  const FeatureFlags.v2()
    : this(
        cloudSync: true,
        videoMemories: true,
        audioMemories: true,
        memoryMap: true,
        yearInReview: true,
        sharedCollections: true,
        comments: true,
      );

  /// Uzaktan gelen JSON'dan üretir (NFR-061). Bilinmeyen anahtarlar yok sayılır,
  /// eksik anahtarlar varsayılana düşer — sunucu hatası uygulamayı kırmaz.
  factory FeatureFlags.fromMap(Map<String, Object?> map) {
    bool read(String key, {bool fallback = false}) =>
        map[key] is bool ? map[key]! as bool : fallback;

    return FeatureFlags(
      cloudSync: read('cloud_sync'),
      videoMemories: read('video_memories'),
      audioMemories: read('audio_memories'),
      memoryMap: read('memory_map'),
      yearInReview: read('year_in_review'),
      sharedCollections: read('shared_collections'),
      comments: read('comments'),
      workshop: read('workshop'),
      sponsoredContent: read('sponsored_content'),
      timeCapsule: read('time_capsule'),
      aiAssist: read('ai_assist'),
      semanticSearch: read('semantic_search'),
    );
  }

  // --- V1.5 ---
  final bool cloudSync; // FR-047, FR-050
  final bool videoMemories; // FR-048
  final bool audioMemories; // FR-049
  final bool memoryMap; // FR-093
  final bool yearInReview; // FR-084

  // --- V2 ---
  final bool sharedCollections; // FR-110..116
  final bool comments; // FR-115

  // --- V2.5 ---
  final bool workshop; // FR-120 İZ Atölye
  final bool sponsoredContent; // FR-140

  // --- V3 ---
  final bool timeCapsule; // FR-170
  final bool aiAssist; // FR-175
  final bool semanticSearch; // FR-095
}

/// Aktif bayraklar. `main.dart` içinde faz değiştirmek için override edilir:
/// ```dart
/// ProviderScope(overrides: [featureFlagsProvider.overrideWithValue(
///   const FeatureFlags.v15())])
/// ```
final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => const FeatureFlags.mvp(),
);
