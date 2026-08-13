/// Kişi detayındaki iki satır tipi: koleksiyon ve ritüel.
///
/// İKİSİ AYRI, ÇÜNKÜ İŞLERİ AYRI:
///   • koleksiyon satırı bir YERE GÖTÜRÜYOR → görsel, sayı ve ok taşıyor
///   • ritüel satırı bir BİLGİ veriyor → ikon, ad ve süre taşıyor, ok YOK
/// Kullanıcı ritüel için "bunda detay olmaz" dedi; oku koymak dokunulup
/// hiçbir şey olmayan bir satır üretirdi.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/people/presentation/views/person_detail_preview_data.dart';

/// Koleksiyon satırı: görsel + ad + anı sayısı + ok.
class PersonCollectionRow extends StatelessWidget {
  const PersonCollectionRow({
    required this.collection,
    required this.onTap,
    super.key,
  });

  final PersonCollection collection;
  final VoidCallback onTap;

  /// Kapak görselinin ölçüsü.
  ///
  /// Referansta kare değil YATAY dikdörtgen (yaklaşık 3:2): koleksiyon bir
  /// kişi değil bir yer/dönem, ve manzara kadrajı ona daha yakışıyor.
  static const double kCoverWidth = 72;
  static const double kCoverHeight = 52;

  /// Satırın yatay dolgusu — çizgiler de bu hizadan başlıyor.
  static const double kInset = AppSpacing.sm + 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: collection.title,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kInset,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.all(AppRadius.sm),
                child: Image.asset(
                  collection.coverAsset,
                  width: kCoverWidth,
                  height: kCoverHeight,
                  fit: BoxFit.cover,
                  // Görsel paketten geliyor ama yine de çökmeye izin
                  // vermiyoruz (NFR-021).
                  errorBuilder: (context, error, stack) => ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: SizedBox(
                      width: kCoverWidth,
                      height: kCoverHeight,
                      child: Icon(
                        AppIcons.mediaMissing,
                        size: AppIconSize.md,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      collection.title,
                      style: context.text.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // Sayı ÇEVİRİDEN geliyor: Türkçede sayıdan sonra çoğul
                      // eki yok ("8 anı"), İngilizcede var ("8 memories").
                      context.l10n.memoryCount(collection.memoryCount),
                      style: context.text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.sm),
              Icon(
                AppIcons.forward,
                size: AppIconSize.md,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ritüel satırı: ikon + ad + kaç yıldır sürdüğü.
class PersonRitualRow extends StatelessWidget {
  const PersonRitualRow({required this.ritual, super.key});

  final PersonRitual ritual;

  /// Satırın yatay dolgusu.
  static const double kInset = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kInset,
        vertical: AppSpacing.md - 2,
      ),
      child: Row(
        children: [
          Icon(
            // Anahtardan çiziliyor: ikon seti değişse bile veri bozulmuyor.
            AppIcons.forKey(ritual.iconKey),
            size: AppIconSize.md,
            color: colors.onSurface,
          ),
          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Text(
              ritual.title,
              style: context.text.bodyMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Text(
            // "5 yıl" — ritüelin ne kadar sürdüğü, kaç kez kutlandığı değil.
            context.l10n.ritualDurationYears(ritual.years),
            style: context.text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
