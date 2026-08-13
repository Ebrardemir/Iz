/// "Tüm Günlükler" — günlük ana sayfasındaki "Tümünü Gör"ün açtığı ekran.
///
/// YERLEŞİM (referans tasarım):
///   ┌──────────────────────────────┐
///   │ ‹      Tüm Günlükler         │  arama/süzme ikonu YOK
///   │ (Tümü)(Bu Hafta)(Bu Ay)(⭐)  │  çipler
///   │ 26 Temmuz 2026               │  gün başlığı
///   │ ┌──────────────────────────┐ │
///   │ │ [img] Sessiz bir akşam ⭐│ │
///   │ │       Günün sonunda…     │ │
///   │ └──────────────────────────┘ │
///   │ 25 Temmuz 2026               │
///   │ …                            │
///   └──────────────────────────────┘
///
/// TARİH SATIRDA DEĞİL BAŞLIKTA (kullanıcının kararı).
/// Ana sayfada her satır kendi tarihini taşıyor çünkü orada karışık günler
/// var. Burada kayıtlar güne göre gruplanıyor; aynı tarihi her satırda tekrar
/// etmek kutuyu daraltıyordu. Saat de aynı gerekçeyle kalktı — kutu artık
/// satırın tamamını kaplıyor.
///
/// APPBAR'DA ARAMA/SÜZME İKONU YOK: referansta iki ikon vardı ama süzme işini
/// zaten çipler yapıyor ve arama henüz hiçbir yere bağlanmıyor. Ana sayfada da
/// aynı kararı verdik — çalışmayan düğmeler güveni aşındırıyor.
///
/// ⚠️ VERİ KAYNAĞI GEÇİCİ: bu oturumda yazılan kayıtlar
/// (`createdJournalEntriesProvider`). Repository geldiğinde yalnızca
/// `ref.watch` satırı değişecek.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/extensions/date_x.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/journal/domain/journal_filter.dart';
import 'package:iz/features/journal/presentation/view_models/created_journal_entries_view_model.dart';
import 'package:iz/features/journal/presentation/views/journal_view.dart';
import 'package:iz/features/journal/presentation/widgets/journal_empty_illustration.dart';
import 'package:iz/features/journal/presentation/widgets/journal_entry_row.dart';
import 'package:iz/features/journal/presentation/widgets/journal_filter_chips.dart';

class JournalAllEntriesView extends ConsumerStatefulWidget {
  const JournalAllEntriesView({super.key});

  @override
  ConsumerState<JournalAllEntriesView> createState() =>
      _JournalAllEntriesViewState();
}

class _JournalAllEntriesViewState extends ConsumerState<JournalAllEntriesView> {
  /// Açılışta TÜMÜ: kullanıcı "tümünü gör"e bastı, gördüğü ilk şey de tümü
  /// olmalı.
  JournalFilter _filter = JournalFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = ref.watch(createdJournalEntriesProvider);

    final visible = filterJournalEntries(
      entries,
      _filter,
      // Saati ENJEKTE EDİYORUZ: "bu hafta"nın testte de sabit bir anlamı
      // olsun (bkz. `clockProvider`).
      today: ref.read(clockProvider).now(),
      dateOf: (item) => item.entry.entryDate,
      isFavoriteOf: (item) => item.entry.isFavorite,
    );

    final groups = groupJournalEntriesByDay(
      visible,
      dateOf: (item) => item.entry.entryDate,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.journalAllTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          JournalFilterChips(
            selected: _filter,
            onSelected: (filter) => setState(() => _filter = filter),
          ),
          const SizedBox(height: AppSpacing.md),

          Expanded(
            child: groups.isEmpty
                ? _EmptyState(filter: _filter)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.xxl,
                    ),
                    children: [
                      for (final group in groups) ...[
                        _DayHeader(day: group.day),
                        const SizedBox(height: AppSpacing.sm),
                        for (final row in group.entries) ...[
                          JournalEntryRow(
                            entry: journalRowOf(row),
                            // Tarih başlıkta yazıyor; satırda tekrar etmiyor.
                            showTimestamp: false,
                            onTap: () =>
                                context.showSnack(l10n.screenComingSoonMessage),
                            onToggleFavorite: () => ref
                                .read(createdJournalEntriesProvider.notifier)
                                .toggleFavorite(row.entry.id),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Gün başlığı — "26 Temmuz 2026".
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) => Text(
    // DİLİ AÇIKÇA GEÇİYORUZ: boş bırakılırsa ay adı İngilizce çıkabiliyor.
    AppDateFormats.long(day, locale: context.l10n.localeName),
    style: context.text.titleSmall?.copyWith(
      color: context.colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// Süzgece göre değişen boş durum.
///
/// TEK BİR "kayıt yok" METNİ YETMİYOR: "bu hafta yazmadın" ile "hiç
/// yazmadın" aynı şey değil ve ikincisini görüp de arşivinin silindiğini
/// sanan kullanıcı olurdu.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final JournalFilter filter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    final message = switch (filter) {
      JournalFilter.all => l10n.journalRecentEmptyBody,
      JournalFilter.thisWeek => l10n.journalAllEmptyWeek,
      JournalFilter.thisMonth => l10n.journalAllEmptyMonth,
      JournalFilter.favorites => l10n.journalAllEmptyFavorites,
    };

    return SingleChildScrollView(
      // Kaydırılabilir: 2x yazı ölçeğinde çizim + metin kısa ekrana sığmıyor.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        children: [
          // Yıldız süzgecinde farklı bir çizim daha doğru olurdu; şimdilik
          // aynı boş sayfa kullanılıyor — mesaj farkı taşıyor.
          const JournalEmptyIllustration(),
          const SizedBox(height: AppSpacing.md),
          Text(
            filter == JournalFilter.favorites
                ? l10n.journalFilterFavorites
                : l10n.journalRecentEmptyTitle,
            style: context.text.titleLarge?.copyWith(color: colors.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: context.text.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
