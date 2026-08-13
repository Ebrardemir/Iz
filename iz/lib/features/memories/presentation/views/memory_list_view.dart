/// Timeline ekranı — MVVM'in **View** katmanı.
///
/// VIEW'IN KURALLARI:
///   ✔ `ref.watch` ile ViewModel state'ini okur
///   ✔ `ref.read(...).komut()` ile kullanıcı eylemini iletir
///   ✔ Navigasyon yapar (ViewModel değil, View yönlendirir)
///   ✘ İş kuralı içermez
///   ✘ Repository/DAO'ya doğrudan erişmez
///
/// `ConsumerWidget` = StatelessWidget + `ref`. Yerel widget state'i
/// gerekiyorsa (TextEditingController gibi) `ConsumerStatefulWidget` kullan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/extensions/date_x.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/presentation/view_models/memory_filter_view_model.dart';
import 'package:iz/features/memories/presentation/view_models/memory_list_view_model.dart';
import 'package:iz/features/memories/presentation/widgets/memory_card.dart';
import 'package:iz/shared/widgets/app_empty_state.dart';
import 'package:iz/shared/widgets/async_value_view.dart';

class MemoryListView extends ConsumerWidget {
  const MemoryListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ViewModel'in ürettiği state. Filtre veya veritabanı değişince
    // bu satır kendiliğinden yeniden çalışır.
    final memoriesState = ref.watch(memoryListProvider);
    final filter = ref.watch(memoryFilterProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.memoriesTitle),
        actions: [
          // FAVORİ FİLTRESİ AÇIK MI?
          //
          // Lucide'da dolu/boş kalp çifti yok (bkz. app_icons.dart), bu yüzden
          // durumu RENKLE gösteriyoruz. NFR-031 "renk tek başına bilgi
          // taşımamalı" diyor; ikinci kanal `Semantics.selected` ve duruma
          // göre değişen ipucu metni.
          IconButton(
            onPressed: () =>
                ref.read(memoryFilterProvider.notifier).toggleFavoritesOnly(),
            isSelected: filter.onlyFavorites,
            color: filter.onlyFavorites
                ? context.semanticColors.danger
                : context.colors.onSurfaceVariant,
            icon: const Icon(AppIcons.favorite),
            tooltip: filter.onlyFavorites
                ? l10n.memoryFilterFavoritesOn
                : l10n.memoryFilterFavoritesOff,
          ),
        ],
      ),

      body: AsyncValueView<List<Memory>>(
        value: memoriesState,
        onRetry: () => ref.invalidate(memoryListProvider),

        // NFR-035 — boş durumda ne yapılacağını anlat.
        emptyBuilder: () => AppEmptyState(
          icon: AppIcons.memory,
          title: l10n.memoryEmptyTitle,
          message: l10n.memoryEmptyMessage,
          actionLabel: l10n.memoryEmptyAction,
          onAction: () => context.pushNamed(AppRoute.memoryNew.name),
        ),

        data: (memories) => _MemoryTimeline(memories: memories),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoute.memoryNew.name),
        icon: const Icon(AppIcons.add),
        label: Text(l10n.memoryNew),
      ),
    );
  }
}

/// Anıları aya göre gruplayıp yapışkan başlıklarla listeler.
class _MemoryTimeline extends ConsumerWidget {
  const _MemoryTimeline({required this.memories});

  final List<Memory> memories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = _groupByMonth(memories);

    return CustomScrollView(
      slivers: [
        for (final group in groups) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                AppDateFormats.monthYear(group.month),
                style: context.text.titleSmall?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverList.separated(
            itemCount: group.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final memory = group.items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: MemoryCard(
                  memory: memory,
                  onTap: () => context.pushNamed(
                    AppRoute.memoryDetail.name,
                    pathParameters: {'id': memory.id},
                  ),
                  onFavoriteToggle: () => _toggleFavorite(context, ref, memory),
                ),
              );
            },
          ),
        ],
        // FAB'ın son kartı örtmemesi için alt boşluk.
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    Memory memory,
  ) async {
    final result = await ref
        .read(memoryListProvider.notifier)
        .toggleFavorite(memory);

    // `context.mounted` kontrolü ŞART: await sonrası widget ağaçtan
    // kalkmış olabilir (use_build_context_synchronously lint kuralı).
    if (!context.mounted) return;

    result.onFailure(
      (failure) => context.showSnack(failure.localizedMessage(context.l10n)),
    );
  }

  List<({DateTime month, List<Memory> items})> _groupByMonth(
    List<Memory> memories,
  ) {
    final groups = <DateTime, List<Memory>>{};
    for (final memory in memories) {
      final key = memory.occurredAt.startOfMonth;
      groups.putIfAbsent(key, () => []).add(memory);
    }
    return groups.entries.map((e) => (month: e.key, items: e.value)).toList();
  }
}
