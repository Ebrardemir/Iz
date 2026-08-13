/// "Tüm Günlükler" ekranının üstündeki süzgeç çipleri: Tümü · Bu Hafta ·
/// Bu Ay · Favoriler.
///
/// SEKME DEĞİL ÇİP.
/// "Hayatım"daki sekme çubuğu (`MyLifeTabBar`) ekranın İÇERİĞİNİ değiştiriyor
/// — takvim, koleksiyonlar, seriler ayrı dünyalar. Buradaki dördü ise aynı
/// listeyi DARALTIYOR; çip bunu söylüyor, sekme söylemiyor.
///
/// YATAY KAYDIRILABİLİR: dört etiket dar bir telefonda (320) sığmıyor ve 2x
/// yazı ölçeğinde hiç sığmıyor. Kısaltmak yerine kaydırıyoruz — "Bu Hafta"yı
/// "Hafta"ya indirmek anlamı buğulandırırdı.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/journal/domain/journal_filter.dart';

class JournalFilterChips extends StatelessWidget {
  const JournalFilterChips({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final JournalFilter selected;
  final ValueChanged<JournalFilter> onSelected;

  /// Referanstaki sıra: geniş olandan dara doğru, sonda favoriler.
  static const List<JournalFilter> kOrder = [
    JournalFilter.all,
    JournalFilter.thisWeek,
    JournalFilter.thisMonth,
    JournalFilter.favorites,
  ];

  static const double kHeight = 38;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: kOrder.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final filter = kOrder[index];

          return _Chip(
            label: _labelOf(filter, context),
            isSelected: filter == selected,
            onTap: () => onSelected(filter),
          );
        },
      ),
    );
  }

  String _labelOf(JournalFilter filter, BuildContext context) {
    final l10n = context.l10n;

    return switch (filter) {
      JournalFilter.all => l10n.journalFilterAll,
      JournalFilter.thisWeek => l10n.journalFilterThisWeek,
      JournalFilter.thisMonth => l10n.journalFilterThisMonth,
      JournalFilter.favorites => l10n.journalFilterFavorites,
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? colors.primary : colors.surfaceContainerLowest,
        borderRadius: AppRadius.pill,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pill,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.pill,
              // Seçili olmayanların İNCE KENARLIĞI var: düz zeminde
              // sınırları kaybolup birbirine yapışıyorlardı.
              border: Border.all(
                color: isSelected ? colors.primary : colors.outlineVariant,
              ),
            ),
            child: Text(
              label,
              style: context.text.labelLarge?.copyWith(
                color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
                // Seçili olan KALIN: renk tek başına yeterli bir sinyal değil
                // (NFR-031 — renk körlüğü).
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
