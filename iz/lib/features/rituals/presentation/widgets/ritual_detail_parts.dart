/// Seri detayının parçaları: kapak, üç istatistik kutusu, anı satırı.
///
/// KAPAĞIN ALTINDA YAZI YOK.
/// Referansta kapağın altında bir slogan vardı ("Her yaz, birlikte biriken
/// anılar"); kullanıcı kaldırılmasını istedi ve doğrusu bu — o cümleyi kimse
/// yazmıyor, uygulamanın uydurması olurdu. Serinin adı zaten AppBar'da.
///
/// ÜÇ KUTU SAYILARI TÜRETİYOR, sormuyor: yıl, anı ve şehir sayısı anılardan
/// geliyor (bkz. `ritual_stats.dart`). Seri formunda tarih sormamamızla aynı
/// fikir — kullanıcıya iki kez iş çıkarmıyoruz.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/rituals/presentation/views/ritual_detail_preview_data.dart';
import 'package:iz/shared/widgets/media_thumbnail.dart';

/// Serinin kapak görseli.
class RitualDetailCover extends StatelessWidget {
  const RitualDetailCover({required this.cover, super.key});

  /// null ise kapak hiç çizilmiyor: boş gri bir dikdörtgen, kapağı olmayan
  /// seride sayfanın en üstünde bir "eksik" duygusu bırakıyordu.
  final MediaItem? cover;

  /// Referanstaki oran — geniş, alçak bir şerit (yaklaşık 2:1).
  static const double kAspectRatio = 2;

  @override
  Widget build(BuildContext context) {
    final media = cover;
    if (media == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: const BorderRadius.all(AppRadius.lg),
      child: AspectRatio(
        aspectRatio: kAspectRatio,
        child: MediaThumbnail(media: media, borderRadius: Radius.zero),
      ),
    );
  }
}

/// Üç kutu: "4 yıl / Birlikte", "12 anı / Toplam", "4 şehir / Keşfedildi".
class RitualStatBoxes extends StatelessWidget {
  const RitualStatBoxes({
    required this.yearCount,
    required this.memoryCount,
    required this.cityCount,
    super.key,
  });

  final int yearCount;
  final int memoryCount;
  final int cityCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final boxes = <Widget>[
      _StatBox(
        icon: AppIcons.date,
        value: l10n.ritualStatYears(yearCount),
        label: l10n.ritualStatYearsLabel,
      ),
      _StatBox(
        icon: AppIcons.photo,
        value: l10n.ritualStatMemories(memoryCount),
        label: l10n.ritualStatMemoriesLabel,
      ),
      // ŞEHİR KUTUSU YALNIZCA VERİ VARSA.
      //
      // "0 şehir / Keşfedildi" bir bilgi değil, bir boşluğun süslenmiş hâli.
      // Konum opsiyonel (rapor 20.1); hiçbir anıda konum yoksa kutu hiç
      // çizilmiyor ve kalan ikisi genişliği paylaşıyor.
      if (cityCount > 0)
        _StatBox(
          icon: AppIcons.location,
          value: l10n.ritualStatCities(cityCount),
          label: l10n.ritualStatCitiesLabel,
        ),
    ];

    // INTRINSIC HEIGHT: üç kutu EŞİT YÜKSEKLİKTE olmalı — biri iki satıra
    // düşünce ötekiler de onunla büyümeli, yoksa sıra kırık görünüyor.
    // `stretch` tek başına yetmiyor: kaydırılabilir bir listede yükseklik
    // sınırsız ve stretch sonsuz kısıt üretiyor (ekranda tam bu hatayı aldık).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, box) in boxes.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: box),
          ],
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSize.md, color: colors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),

            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    // Sayı KALIN ve koyu, etiket ince ve soluk: göz üç kutuyu
                    // tararken önce sayıları okuyor.
                    style: context.text.titleMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Listedeki tek anı: solda görsel, sağda ad + tarih + kategori çipi.
///
/// ÜÇ NOKTA YOK — kullanıcının kararı. Satırın tek bir işi var: o anıya
/// gitmek. Satır içinde ikinci bir eylem, dokunma hedefini ikiye bölüyor ve
/// "hangisine bassam" sorusunu üretiyordu.
class RitualMemoryRow extends StatelessWidget {
  const RitualMemoryRow({required this.memory, required this.onTap, super.key});

  final RitualDetailMemory memory;
  final VoidCallback onTap;

  /// Referanstaki kapak: yatay dikdörtgen (~72×56).
  static const double kCoverWidth = 72;
  static const double kCoverHeight = 56;

  static const Radius kRadius = Radius.circular(14);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: memory.title,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: const BorderRadius.all(kRadius),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(kRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.all(AppRadius.sm),
                  child: Image.asset(
                    memory.imageAsset,
                    width: kCoverWidth,
                    height: kCoverHeight,
                    fit: BoxFit.cover,
                    // Kapak bulunamazsa liste çökmesin (NFR-021).
                    errorBuilder: (context, error, stack) => ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: const SizedBox(
                        width: kCoverWidth,
                        height: kCoverHeight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md - 4),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        memory.title,
                        style: context.text.titleMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              memory.dateLabel,
                              style: context.text.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Kategori çipi VARSA: kategori opsiyonel ve boş
                          // bir çip satırda anlamsız bir leke bırakırdı.
                          if (memory.categoryLabel case final category?) ...[
                            const SizedBox(width: AppSpacing.sm),
                            _CategoryChip(label: category),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.xs),
                // Ok: satırın bir yere GÖTÜRDÜĞÜNÜ söyleyen tek işaret
                // (üç nokta kalkınca sağ taraf boş kalıyordu).
                Icon(
                  AppIcons.forward,
                  size: AppIconSize.md,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Anının kategorisini gösteren küçük hap.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: AppRadius.pill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        child: Text(
          label,
          style: context.textStyles.bodyTiny.copyWith(
            color: colors.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
