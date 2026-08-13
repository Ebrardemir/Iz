/// Arama sekmesi — FR-090..FR-092.
///
/// Bu ekran ÇALIŞIYOR: FTS5 indeksi ve filtre ViewModel'i hazır olduğu için
/// arama kutusu doğrudan `memoryFilterProvider`ı besliyor ve sonuçlar
/// `memoryListProvider`dan geliyor.
///
/// Yani aynı ViewModel iki farklı ekranı besliyor — MVVM'in getirisi budur.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/presentation/view_models/memory_filter_view_model.dart';
import 'package:iz/features/memories/presentation/view_models/memory_list_view_model.dart';
import 'package:iz/features/memories/presentation/widgets/memory_card.dart';
import 'package:iz/shared/widgets/app_empty_state.dart';
import 'package:iz/shared/widgets/async_value_view.dart';

class SearchView extends ConsumerStatefulWidget {
  const SearchView({super.key});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Her tuşa basışta FTS sorgusu çalıştırmak gereksiz yük yaratır.
  /// 300 ms bekleyip son değeri gönderiyoruz (NFR-002).
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(AppDuration.debounce, () {
      ref.read(memoryFilterProvider.notifier).setQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(memoryListProvider);
    final filter = ref.watch(memoryFilterProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          onChanged: _onChanged,
          autofocus: false,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '${l10n.commonSearch}…',
            prefixIcon: const Icon(AppIcons.search),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(AppIcons.clear),
                    onPressed: () {
                      _controller.clear();
                      ref.read(memoryFilterProvider.notifier).setQuery(null);
                      setState(() {});
                    },
                  ),
          ),
        ),
      ),

      body: AsyncValueView<List<Memory>>(
        value: results,
        onRetry: () => ref.invalidate(memoryListProvider),
        emptyBuilder: () => AppEmptyState(
          icon: filter.hasTextQuery ? AppIcons.searchEmpty : AppIcons.search,
          title: filter.hasTextQuery
              ? l10n.searchNoResultsTitle
              : l10n.searchPromptTitle,
          message: filter.hasTextQuery
              ? l10n.searchNoResultsMessage
              : l10n.searchPromptMessage,
        ),
        data: (memories) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: memories.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final memory = memories[index];
            return MemoryCard(
              memory: memory,
              onTap: () => context.pushNamed(
                AppRoute.memoryDetail.name,
                pathParameters: {'id': memory.id},
              ),
            );
          },
        ),
      ),
    );
  }
}
