/// FR-130: "Uygulama Free ve İZ+ entitlement'larını **merkezi bir özellik
/// matrisi** ile yönetebilmelidir."
/// NFR-043: "Ücretli plan sınırları kod içine sabit gömülmek yerine
/// remote config/entitlement tablosuyla yönetilmelidir."
///
/// Bu dosya o merkezi matristir. Kodun hiçbir yerinde
/// `if (plan == IzPlan.plus)` yazmayacağız; her zaman
/// `entitlements.can(IzFeature.video)` veya `entitlements.limit(...)` diyeceğiz.
/// Böylece paketleme stratejisi değiştiğinde tek dosya değişir.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';

/// Rapor 14.1 paket matrisi.
enum IzPlan {
  free('free'),
  plus('plus'),
  family('family');

  const IzPlan(this.key);
  final String key;

  static IzPlan fromKey(String? key) => switch (key) {
    'plus' => IzPlan.plus,
    'family' => IzPlan.family,
    _ => IzPlan.free,
  };
}

/// Plana bağlı kapılanabilen yetenekler.
enum IzFeature {
  videoMemory('video_memory'), // FR-048
  audioMemory('audio_memory'), // FR-049
  cloudBackup('cloud_backup'), // FR-047
  multiDevice('multi_device'), // 14.1
  premiumStudioTemplates('premium_studio_templates'), // FR-104
  hdExport('hd_export'), // FR-104
  removeWatermark('remove_watermark'), // FR-103/104
  sharedCollectionOwner('shared_collection_owner'), // FR-110
  advancedExport('advanced_export'); // FR-135

  const IzFeature(this.key);
  final String key;
}

/// Sayısal sınırlar. Ayrı enum, çünkü bunlar "var/yok" değil "kaç tane".
enum IzLimit {
  /// FR-041: "Ücretsiz planda bir Anı için önerilen başlangıç limiti
  /// 3 öne çıkan fotoğraftır; limit uzaktan yapılandırılabilir olmalıdır."
  photosPerMemory('photos_per_memory'),

  /// BR-005 ile uyumlu: video süresi (saniye).
  videoDurationSeconds('video_duration_seconds'),

  /// FR-072/FR-138: kategori sınırı ANA paywall değil; varsayılan sınırsız.
  maxCategories('max_categories');

  const IzLimit(this.key);
  final String key;
}

/// Sınırsızı temsil eden değer.
const int kUnlimited = -1;

/// Tek bir planın neye izin verdiğini tanımlar.
final class PlanEntitlements {
  const PlanEntitlements({
    required this.plan,
    required this.features,
    required this.limits,
  });

  final IzPlan plan;
  final Set<IzFeature> features;
  final Map<IzLimit, int> limits;
}

/// Merkezi matris. Rapor 14.1'in koda dökülmüş hâli.
///
/// DEĞİŞTİRİRKEN DİKKAT: FR-134 — "Abonelik bittiğinde kullanıcının mevcut
/// anıları silinmemeli". Bu tablo *yeni işlem* yapma iznini belirler,
/// var olan veriye erişimi değil.
final class EntitlementMatrix {
  const EntitlementMatrix(this._table);

  /// Gömülü varsayılan (offline'da ve remote config gelmeden önce geçerli).
  factory EntitlementMatrix.defaults() => const EntitlementMatrix({
    IzPlan.free: PlanEntitlements(
      plan: IzPlan.free,
      features: {},
      limits: {
        IzLimit.photosPerMemory: 3,
        IzLimit.videoDurationSeconds: 0,
        IzLimit.maxCategories: kUnlimited,
      },
    ),
    IzPlan.plus: PlanEntitlements(
      plan: IzPlan.plus,
      features: {
        IzFeature.videoMemory,
        IzFeature.audioMemory,
        IzFeature.cloudBackup,
        IzFeature.multiDevice,
        IzFeature.premiumStudioTemplates,
        IzFeature.hdExport,
        IzFeature.removeWatermark,
        IzFeature.sharedCollectionOwner,
        IzFeature.advancedExport,
      },
      limits: {
        IzLimit.photosPerMemory: 30,
        IzLimit.videoDurationSeconds: 300,
        IzLimit.maxCategories: kUnlimited,
      },
    ),
    IzPlan.family: PlanEntitlements(
      plan: IzPlan.family,
      features: {
        IzFeature.videoMemory,
        IzFeature.audioMemory,
        IzFeature.cloudBackup,
        IzFeature.multiDevice,
        IzFeature.premiumStudioTemplates,
        IzFeature.hdExport,
        IzFeature.removeWatermark,
        IzFeature.sharedCollectionOwner,
        IzFeature.advancedExport,
      },
      limits: {
        IzLimit.photosPerMemory: 50,
        IzLimit.videoDurationSeconds: 600,
        IzLimit.maxCategories: kUnlimited,
      },
    ),
  });

  final Map<IzPlan, PlanEntitlements> _table;

  PlanEntitlements of(IzPlan plan) => _table[plan] ?? _table[IzPlan.free]!;

  /// Bir özelliğin açık olduğu en düşük planı bulur — paywall ekranında
  /// "Bu özellik İZ+ ile gelir" demek için.
  IzPlan? lowestPlanWith(IzFeature feature) {
    for (final plan in IzPlan.values) {
      if (of(plan).features.contains(feature)) return plan;
    }
    return null;
  }
}

/// Uygulamanın "şu an ne yapabilirim?" sorusuna cevap veren servis.
final class Entitlements {
  const Entitlements({required this.plan, required this.matrix});

  final IzPlan plan;
  final EntitlementMatrix matrix;

  bool can(IzFeature feature) => matrix.of(plan).features.contains(feature);

  int limit(IzLimit key) => matrix.of(plan).limits[key] ?? 0;

  /// Sınır aşıldı mı? `kUnlimited` her zaman false döner.
  bool exceeds(IzLimit key, int count) {
    final max = limit(key);
    return max != kUnlimited && count > max;
  }

  /// UseCase'lerde kapı görevi görür:
  /// ```dart
  /// final gate = entitlements.require(IzFeature.videoMemory);
  /// if (gate case Err(:final failure)) return Err(failure);
  /// ```
  Result<Unit> require(IzFeature feature) {
    if (can(feature)) return okUnit;
    final required = matrix.lowestPlanWith(feature) ?? IzPlan.plus;
    return Err(
      EntitlementFailure(featureKey: feature.key, requiredPlan: required.key),
    );
  }
}

/// Kullanıcının aktif planı. Gerçek uygulamada abonelik feature'ı bunu
/// store (IAP) doğrulamasından besleyecek; şimdilik Free.
final currentPlanProvider = Provider<IzPlan>((ref) => IzPlan.free);

final entitlementMatrixProvider = Provider<EntitlementMatrix>(
  (ref) => EntitlementMatrix.defaults(),
);

/// Her yerden okunacak ana provider.
final entitlementsProvider = Provider<Entitlements>((ref) {
  return Entitlements(
    plan: ref.watch(currentPlanProvider),
    matrix: ref.watch(entitlementMatrixProvider),
  );
});
