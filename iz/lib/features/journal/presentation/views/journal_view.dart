/// Günlük ana sayfası — FR-030..FR-035.
///
/// YERLEŞİM (referans tasarım, kullanıcının çıkardıklarıyla):
///   ┌──────────────────────────────┐
///   │ Günlük                       │  arama/bildirim YOK
///   │ ┌──────────────────────────┐ │
///   │ │ Hoş geldin        (🌿)   │ │  fotoğraf zeminli kart
///   │ │ Kendine birkaç satır…    │ │
///   │ │ [ Yazmaya Başla ]        │ │
///   │ └──────────────────────────┘ │
///   │ Son Yazılarım    Tümünü Gör  │
///   │ ┌──────────────────────────┐ │
///   │ │ 26 │[img]│ Sessiz akşam ⭐│ │
///   │ │Tem │     │ Günün sonunda…│ │
///   │ │2026│     │ 21:30         │ │
///   │ └──────────────────────────┘ │
///   └──────────────────────────────┘
///
/// REFERANSTAN ÇIKARILANLAR (kullanıcının kararı):
///   • AppBar'daki arama ve bildirim ikonları
///   • "Bugün kendine ne söylemek istersin?" alıntı kutusu — aynı davet zaten
///     yazma ekranının karşılama kartında var ve orada işe yarıyor; burada
///     kullanıcıyı yazıya değil bir alıntıya bakmaya çağırıyordu.
///
/// ⚠️ VERİ KAYNAĞI GEÇİCİ. Listelediği şey bu oturumda yazılan kayıtlar
/// (`createdJournalEntriesProvider`) — uygulama kapanınca gidiyorlar.
/// Doldurmak için ARCHITECTURE.md'deki "Yeni feature ekleme reçetesi":
///   1. journal/data/daos/journal_dao.dart
///   2. journal/domain/repositories/journal_repository.dart
///   3. journal/data/repositories/journal_repository_impl.dart
///   4. journal/presentation/view_models/journal_list_view_model.dart
///   5. buradaki `ref.watch`ı ona çevir — liste widget'ları aynı kalacak
///
/// Tablolar ve domain modeli ZATEN HAZIR:
///   • journal/data/tables/journal_tables.dart
///   • journal/domain/entities/journal_entry.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_add_menu.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/journal/presentation/view_models/created_journal_entries_view_model.dart';
import 'package:iz/features/journal/presentation/widgets/journal_empty_illustration.dart';
import 'package:iz/features/journal/presentation/widgets/journal_entry_row.dart';
import 'package:iz/features/journal/presentation/widgets/journal_hero_card.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';

class JournalView extends ConsumerWidget {
  const JournalView({super.key});

  /// Ana sayfada gösterilen kayıt sayısı.
  ///
  /// ÜÇ: referanstaki kadar. Ana sayfa bir ARŞİV değil, "en son ne yazmışım"
  /// sorusunun cevabı; gerisi "Tümünü Gör"ün arkasında.
  static const int kRecentCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entries = ref.watch(createdJournalEntriesProvider);
    final recent = entries.take(kRecentCount).toList();

    return Scaffold(
      // ARAMA VE BİLDİRİM YOK (kullanıcının kararı): ikisi de henüz bir yere
      // bağlanmıyordu ve bir ekranın en üstünde çalışmayan iki düğme,
      // uygulamanın geri kalanına olan güveni de aşındırıyor.
      appBar: AppBar(title: Text(l10n.navJournal)),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          // ÜSTTE DAR: AppBar'ın kendi boşluğu zaten var, üstüne 16 daha
          // eklenince kart ekranın ortasına doğru kayıyordu.
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          JournalHeroCard(
            // Profil verisi yok; ad geldiğinde burası dolacak ve kart
            // "Hoş geldin, Ebrar" diyecek.
            onStartWriting: () => context.pushNamed(AppRoute.journalNew.name),
          ),
          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.journalRecentTitle,
                  style: context.text.titleMedium?.copyWith(
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // HER ZAMAN görünüyor (kullanıcının kararı): bölüm başlığının
              // yanındaki bu bağlantı, listenin devamı olduğunu söyleyen
              // sabit bir işaret. Kayıt yokken de duruyor — açtığı sayfa o
              // zaman boş durumu gösteriyor.
              TextButton(
                onPressed: () => context.pushNamed(AppRoute.journalAll.name),
                child: Text(l10n.commonSeeAll),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          if (recent.isEmpty)
            const _EmptyState()
          else
            for (final entry in recent) ...[
              JournalEntryRow(
                entry: journalRowOf(entry),
                // Kaydın kendi ekranı henüz tasarlanmadı.
                onTap: () => context.showSnack(l10n.screenComingSoonMessage),
                onToggleFavorite: () => ref
                    .read(createdJournalEntriesProvider.notifier)
                    .toggleFavorite(entry.entry.id),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),

      bottomNavigationBar: IzBottomNav(
        destinations: IzBottomNav.appTabs(l10n),
        // Günlük alt çubuktaki dört sekmeden biri DEĞİL (ana sayfa, hayatım,
        // mağaza, profil): hiçbirini vurgulamıyoruz.
        currentIndex: IzBottomNav.noSelection,
        onSelect: (index) => context.go(AppRoute.tabs[index].path),
        addIcon: AppIcons.add,
        addLabel: l10n.navAdd,
        // Günlük ekranındayken "+" en çok "yeni günlük" demek.
        onAdd: () => showAppAddMenu(context),
      ),
    );
  }
}

/// Oturum kaydını satırın beklediği hâle çevirir.
///
/// AYRI BİR FONKSİYON: aynı çeviriyi "Tüm Yazılarım" ekranı da yapıyor ve
/// ikisinin ayrışması, aynı kaydın iki listede farklı görünmesi demekti.
JournalRowData journalRowOf(CreatedJournalEntry item) => (
  id: item.entry.id,
  date: item.entry.entryDate,
  createdAt: item.entry.createdAt,
  title: item.entry.title,
  // `preview` domainde: kısaltma kuralı ekranın değil kaydın bilgisi.
  preview: item.entry.preview,
  photo: item.photos.firstOrNull,
  isFavorite: item.entry.isFavorite,
);

/// Hiç kayıt yokken: çizim + iki kısa satır.
///
/// Önce uzun bir paragraftı ve kimse okumuyordu. Boş bir listede kullanıcının
/// ihtiyacı açıklama değil DAVET — kişiler ekranındaki illüstrasyonla aynı
/// fikir.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.lg),
      child: Column(
        children: [
          const JournalEmptyIllustration(),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.journalRecentEmptyTitle,
            // POPPINS (titleLarge): karşılama kartındaki selamla aynı aile.
            // Küçük bir ekranda iki yazı ailesi tasarımı "iki sesli" yapıyor.
            style: context.text.titleLarge?.copyWith(color: colors.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.journalRecentEmptyBody,
            style: context.text.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
