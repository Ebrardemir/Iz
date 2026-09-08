/// Ana sayfanın gerçek verisi: sayaçlar, kapak anısı ve son anılar.
///
/// NEDEN `features/home/` ALTINDA DEĞİL?
/// Dört feature'ı birleştiriyor — anı, kişi, koleksiyon ve seri. Bir feature
/// başka feature'ın yalnız `domain/`ini görebilir (TR-C-03); ana sayfa
/// tarafına koysaydık ötekilerin veri katmanlarına uzanmak zorunda kalırdı.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/features/collections/presentation/view_models/collections_list_view_model.dart';
import 'package:iz/features/home/presentation/widgets/home_stats_grid.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';
import 'package:iz/features/memories/presentation/view_models/memory_list_view_model.dart';
import 'package:iz/features/my_life/presentation/widgets/my_life_tab_bar.dart';
import 'package:iz/features/people/presentation/view_models/people_list_view_model.dart';
import 'package:iz/features/rituals/presentation/view_models/rituals_list_view_model.dart';

/// Ana sayfadaki dört sayaç.
///
/// GÜNLÜK SAYACI HENÜZ GERÇEK DEĞİL: `JournalDao` yazılmadı, günlük kayıtları
/// oturum belleğinde duruyor. Sıfır göstermek yalan olmazdı ama eksik olanın
/// ne olduğu kodda görünmeli — o yüzden burada açıkça yazılı ve tek satırda
/// düzelecek.
typedef HomeCounts = ({int journal, int people, int series, int collections});

/// Ana sayfanın son anıları — en yeniden eskiye, en fazla üç tane.
///
/// LİMİT SORGUDA, sonradan kırpma DEĞİL: 2.000 anısı olan kullanıcıda tümünü
/// çekip üçünü almak boşa iş olurdu (NFR-003).
final homeRecentMemoriesProvider = StreamProvider<List<Memory>>((ref) {
  return ref
      .watch(memoryRepositoryProvider)
      .watchMemories(const MemoryFilter(limit: _kRecentLimit))
      .unwrap();
});

/// Referans tasarımda üç satır var; dördüncüsü paneli taşırıyor.
const int _kRecentLimit = 3;

/// Kapaktaki "bugünün izi".
///
/// EN YENİ ANI: "bugün" adı geçse de tam olarak bugüne ait bir kayıt aramak,
/// çoğu günde kapağı boş bırakırdı. Kullanıcının en son bıraktığı iz, "şu an
/// neredeyim" sorusunun en iyi cevabı.
final homeHeroMemoryProvider = Provider<AsyncValue<Memory?>>((ref) {
  return ref
      .watch(homeRecentMemoriesProvider)
      .whenData((memories) => memories.firstOrNull);
});

/// Sayaçların ham değerleri.
final homeCountsProvider = Provider<HomeCounts>((ref) {
  final memories = ref.watch(memoryCountProvider).value ?? 0;
  final people = ref.watch(peopleListProvider).value?.length ?? 0;
  final series = ref.watch(ritualsListProvider).value?.length ?? 0;
  final collections = ref.watch(collectionsListProvider).value?.length ?? 0;

  return (
    // ⚠️ ANI sayısını gösteriyoruz, GÜNLÜK değil: günlüğün veri katmanı
    // yazılmadı ve elimizde sayılacak bir şey yok. İkisi de "kaç kayıt
    // bıraktım" sorusunu cevapladığı için ekran anlamlı kalıyor; hat
    // kurulunca burası `journalCountProvider` olacak.
    journal: memories,
    people: people,
    series: series,
    collections: collections,
  );
});

/// Ana sayfadaki dört sayaç — hazır liste.
///
/// NEDEN BURADA, EKRANDA DEĞİL?
/// Sayaçlar dokununca "Hayatım"ın SEKMELERİNE götürüyor (`MyLifeTab`) ve o
/// tip başka feature'ın presentation'ında. Bir feature başka feature'ın
/// presentation'ını import edemez (TR-C-03); her şeyi bilebilen tek katman
/// burası.
List<HomeStat> homeStats(
  AppL10n l10n,
  HomeCounts counts, {
  required void Function(AppRoute route, {Map<String, String> query}) onOpen,
}) {
  return [
    (
      icon: AppIcons.navJournal,
      label: l10n.homeStatJournal,
      value: '${counts.journal}',
      unit: l10n.homeStatJournalUnit(counts.journal),
      onTap: () => onOpen(AppRoute.journal),
    ),
    (
      icon: AppIcons.people,
      label: l10n.homeStatPeople,
      value: '${counts.people}',
      unit: l10n.homeStatPeopleUnit(counts.people),
      onTap: () => onOpen(AppRoute.people),
    ),
    // SERİLER ve KOLEKSİYONLAR ayrı ekran DEĞİL, "Hayatım"ın sekmeleri:
    // sayaç doğrudan o sekmeye götürüyor (bkz. `MyLifeTab.fromQuery`).
    (
      icon: AppIcons.series,
      label: l10n.homeStatSeries,
      value: '${counts.series}',
      unit: l10n.homeStatSeriesUnit(counts.series),
      onTap: () =>
          onOpen(AppRoute.myLife, query: {'tab': MyLifeTab.series.name}),
    ),
    (
      icon: AppIcons.collection,
      label: l10n.homeStatCollections,
      value: '${counts.collections}',
      unit: l10n.homeStatCollectionsUnit(counts.collections),
      onTap: () =>
          onOpen(AppRoute.myLife, query: {'tab': MyLifeTab.collections.name}),
    ),
  ];
}
