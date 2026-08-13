/// Timeline'daki anı kartı.
///
/// SAF WIDGET: Riverpod'a bağlı değil, sadece verilen [Memory]'yi çizer ve
/// geri çağırmaları (callback) yukarı bildirir.
///
/// NEDEN ÖNEMLİ?
/// Widget'ı `ref.watch` yapmadan yazarsan:
///   • widget testi yazmak için ProviderScope kurmana gerek kalmaz
///   • aynı kartı farklı ekranlarda (kişi yaşam çizgisi, koleksiyon,
///     arama sonucu) yeniden kullanabilirsin
///   • gereksiz yeniden çizim (rebuild) olmaz
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/extensions/date_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/shared/widgets/media_thumbnail.dart';

class MemoryCard extends StatelessWidget {
  const MemoryCard({
    required this.memory,
    this.onTap,
    this.onFavoriteToggle,
    super.key,
  });

  final Memory memory;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MediaThumbnail(media: memory.coverMedia, size: 84),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      memory.displayTitle(l10n.memoryNew),
                      style: context.text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppDateFormats.long(memory.occurredAt),
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _MetaRow(memory: memory),
                  ],
                ),
              ),
              // FR-019 — favori işareti
              //
              // Lucide çizgi setidir; Material'daki dolu/boş kalp ikilisi yok.
              // Durumu ÜÇ sinyalle veriyoruz: dolu zemin (şekil), renk ve
              // ekran okuyucu etiketi. NFR-031 gereği renk tek başına
              // bilgi taşımamalı — zemin farkı bunu sağlıyor.
              IconButton(
                onPressed: onFavoriteToggle,
                icon: const Icon(AppIcons.favorite),
                color: memory.isFavorite
                    ? context.colors.onSecondaryContainer
                    : context.colors.onSurfaceVariant,
                style: memory.isFavorite
                    ? IconButton.styleFrom(
                        backgroundColor: context.colors.secondaryContainer,
                      )
                    : null,
                // NFR-032 — ekran okuyucu etiketi
                tooltip: memory.isFavorite
                    ? l10n.memoryUnfavorite
                    : l10n.memoryFavorite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartın alt satırı: medya sayısı, kişi sayısı, konum, kayıp medya uyarısı.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.memory});

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (memory.mediaCount > 0)
        _MetaChip(icon: AppIcons.photo, label: '${memory.mediaCount}'),
      if (memory.personCount > 0)
        _MetaChip(icon: AppIcons.people, label: '${memory.personCount}'),
      if (memory.locationLabel != null)
        _MetaChip(
          icon: AppIcons.location,
          label: memory.locationLabel!,
          flexible: true,
        ),
      // BR-007 — orijinal medya kayıpsa kullanıcı bunu kartta görmeli.
      if (memory.coverMedia?.isMissing ?? false)
        _MetaChip(
          icon: AppIcons.mediaMissing,
          label: context.l10n.mediaMissingTitle,
          color: context.semanticColors.warning,
          flexible: true,
        ),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: chips,
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.color,
    this.flexible = false,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final bool flexible;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.colors.onSurfaceVariant;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIconSize.sm, color: effectiveColor),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: context.text.labelSmall?.copyWith(color: effectiveColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return flexible
        ? ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: content,
          )
        : content;
  }
}
