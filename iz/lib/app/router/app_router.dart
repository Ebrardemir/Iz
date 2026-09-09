/// Uygulama navigasyonu — **composition root**'un ikinci parçası.
///
/// `app/` katmanı tüm feature'ları bilebilir; feature'lar birbirinin
/// ekranını doğrudan import etmez, sadece rota adıyla gider.
/// Bu, feature'ları birbirinden bağımsız tutan en önemli kuraldır.
///
/// StatefulShellRoute.indexedStack kullanıyoruz: sekmeler arası geçişte
/// her sekmenin kendi navigasyon yığını ve scroll pozisyonu KORUNUR.
/// Basit bir `BottomNavigationBar` + `IndexedStack` bunu vermez.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/composition/collections_with_memories.dart';
import 'package:iz/app/composition/home_data.dart';
import 'package:iz/app/composition/person_detail_data.dart';
import 'package:iz/app/composition/rituals_with_memories.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/app/router/app_shell.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/extensions/date_x.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/storage/app_preferences.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/auth/presentation/views/sign_in_view.dart';
import 'package:iz/features/auth/presentation/views/sign_up_view.dart';
import 'package:iz/features/collections/presentation/views/collection_editor_view.dart';
import 'package:iz/features/home/presentation/views/home_view.dart';
import 'package:iz/features/journal/presentation/views/journal_all_entries_view.dart';
import 'package:iz/features/journal/presentation/views/journal_editor_view.dart';
import 'package:iz/features/journal/presentation/views/journal_view.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/presentation/view_models/memory_list_view_model.dart';
import 'package:iz/features/memories/presentation/views/memory_detail_view.dart';
import 'package:iz/features/memories/presentation/views/memory_editor_view.dart';
import 'package:iz/features/memories/presentation/views/memory_list_view.dart';
import 'package:iz/features/memories/presentation/views/memory_new_photos_view.dart';
import 'package:iz/features/my_life/presentation/views/my_life_view.dart';
import 'package:iz/features/my_life/presentation/widgets/collection_card.dart';
import 'package:iz/features/my_life/presentation/widgets/my_life_tab_bar.dart';
import 'package:iz/features/my_life/presentation/widgets/series_card.dart';
import 'package:iz/features/onboarding/presentation/views/onboarding_view.dart';
import 'package:iz/features/people/presentation/view_models/people_list_view_model.dart';
import 'package:iz/features/people/presentation/views/people_view.dart';
import 'package:iz/features/people/presentation/views/person_detail_view.dart';
import 'package:iz/features/people/presentation/views/person_editor_view.dart';
import 'package:iz/features/people/presentation/widgets/person_detail_rows.dart';
import 'package:iz/features/rituals/presentation/ritual_l10n.dart';
import 'package:iz/features/rituals/presentation/views/ritual_detail_view.dart';
import 'package:iz/features/rituals/presentation/views/ritual_editor_view.dart';
import 'package:iz/features/search/presentation/views/search_view.dart';
import 'package:iz/features/settings/presentation/views/settings_view.dart';
import 'package:iz/shared/widgets/coming_soon_view.dart';
import 'package:iz/shared/widgets/iz_memory_picker_view.dart';

/// `?person=` parametresini "Hayatım" ekranının anlayacağı süzgece çevirir.
///
/// KİŞİ ARTIK DEPODAN geliyor. Koleksiyon bağı hâlâ önizleme verisinde:
/// `CollectionRepository` yazılmadı (M6). O gelince ikinci yarı da düşecek.
///
/// TANINMAYAN KİMLİK null DÖNÜYOR: eski ya da elle yazılmış bir bağlantı
/// kullanıcıyı boş bir listeyle karşılamasın — süzgeç hiç uygulanmıyor.
/// Liste henüz yüklenmediyse de null: bir kare süzgeçsiz göstermek,
/// yanlış süzgeç göstermekten iyidir.
({String label, Set<String> ids})? _collectionFilterFor(
  WidgetRef ref,
  String? personId,
) {
  if (personId == null) return null;

  final person = ref
      .watch(peopleListProvider)
      .asData
      ?.value
      .where((p) => p.id == personId)
      .firstOrNull;
  if (person == null) return null;

  return (
    label: person.name,
    // KİMLİKLER TÜRETİLİYOR: kişinin koleksiyonları anılarından çıkıyor
    // (bkz. `app/composition/person_detail_data.dart`). Süzgeç de kişi
    // detayındaki listeyle aynı kaynaktan besleniyor, ikisi ayrışmıyor.
    ids: {
      for (final collection
          in ref.watch(personCollectionsProvider(personId)).value ??
              const <PersonCollection>[])
        collection.id,
    },
  );
}

/// Bu oturumda oluşturulan ritüelleri "Serilerim" kartlarına çevirir.
///
/// ⚠️ GEÇİCİ: `RitualDao` yazıldığında liste repository'den gelecek ve bu
/// fonksiyon silinecek (bkz. `created_rituals_view_model.dart`).
///
/// YILLAR VE KAPAKLAR ANILARDAN geliyor: kullanıcı forma tarih girmiyor,
/// seçtiği anıların yılları şeridi kuruyor. Anı seçilmemişse şerit boş kalıyor
/// — kart yine görünüyor, çünkü ritüel oluştu ve kullanıcı onu görmeli.
List<SeriesCardData> _seriesCards(
  BuildContext context,
  List<RitualWithMemories> rituals,
) {
  final l10n = context.l10n;

  return [
    for (final entry in rituals)
      (
        id: entry.ritual.id,
        iconKey: entry.ritual.iconKey,
        title: entry.ritual.title,
        // Alt satır tekrar açıklaması ("Her yıl"): seri kartlarının geri
        // kalanıyla aynı köprüden geçiyor, metin iki yerde ayrışmıyor.
        subtitle: entry.ritual.recurrenceLabel(l10n),
        years: [
          for (final occurrence in entry.years)
            (
              memoryId: occurrence.memory.id,
              // YIL BAĞDAN geliyor, anının tarihinden değil (BR-012): 31
              // Aralık'ta çekilen bir fotoğraf bir sonraki yılın kutlamasına
              // ait olabilir.
              year: occurrence.year,
              cover: occurrence.memory.coverMedia,
              placeLabel: occurrence.memory.locationLabel,
            ),
        ],
      ),
  ];
}

/// Seri detayının kaydını çıkarır.
///
/// İKİ KAYNAK: bu oturumda oluşturulan seriler (`createdRitualsProvider`) ve
/// tasarım önizlemesindeki seriler (`RitualDetailPreviewData`). Ekran ikisini
/// de bilmiyor; ayrımı burada, her şeyi bilebilen katmanda yapıyoruz.
///
/// ⚠️ GEÇİCİ: `RitualDao` yazıldığında tek bir repository çağrısı kalacak.
///
/// TANINMAYAN KİMLİK null DÖNÜYOR — ekran "bulunamadı" gösteriyor, çökmüyor.
RitualDetailData? _ritualDetail(
  String id,
  List<RitualWithMemories> rituals,
  AppL10n l10n,
) {
  final entry = rituals.where((r) => r.ritual.id == id).firstOrNull;
  if (entry == null) return null;

  return (
    id: entry.ritual.id,
    title: entry.ritual.title,
    // Kapak, serinin EN YENİ anısının görseli: serinin kendi kapağı yok
    // (TRD M6.1) ve en yeni anı "bu seri şu an neye benziyor" sorusunun
    // cevabı.
    cover: entry.years.lastOrNull?.memory.coverMedia,
    memories: [
      for (final occurrence in entry.years)
        (
          id: occurrence.memory.id,
          cover: occurrence.memory.coverMedia,
          title: occurrence.memory.displayTitle(l10n.memoryNew),
          dateLabel: AppDateFormats.long(occurrence.memory.occurredAt),
          // YIL BAĞDAN geliyor, anının tarihinden değil (BR-012).
          year: occurrence.year,
          // Kategori seri formunda SORULMUYOR: anının kendi alanı.
          categoryLabel: null,
          placeLabel: occurrence.memory.locationLabel,
        ),
    ],
  );
}

/// Önizleme anısının detay kaydı — hangi listede olduğunu bilmeden arıyoruz.
///
/// Sırayla seri şeridi, koleksiyon ve ana sayfa kayıtlarına bakıyor. Hiçbiri
/// tutmazsa null: detay ekranı o zaman repository'ye düşüyor.
// `_previewMemoryDetail` KALDIRILDI: bir zamanlar tasarım önizlemesindeki
// anıların kaydını `extra` ile taşıyordu, çünkü o kimliklerin veritabanında
// karşılığı yoktu ve düz bir geçiş kullanıcıyı "Bulunamadı" ekranına
// düşürürdü. Artık her ekran gerçek anıları gösteriyor; detay ekranı da
// anıyı kimlikten kendisi yüklüyor.

/// Veritabanındaki koleksiyonları "Hayatım" kartlarına çevirir.
///
/// NEDEN BURADA, "Hayatım" EKRANINDA DEĞİL?
/// Kart hem koleksiyonu hem anılarını gösteriyor; ikisi ayrı feature.
/// "Hayatım" koleksiyonları import edemez (ARCHITECTURE.md §2), ama
/// composition root her şeyi bilebilir — dönüşüm burada.
///
/// ÖZET SATIRI ("3 anı • 10-14 Mayıs 2026") burada kuruluyor çünkü hem
/// çoğullama hem tarih biçimi bir SUNUM kararı; kart onu hazır metin bekliyor.
List<CollectionCardData> _collectionCards(
  BuildContext context,
  List<CollectionWithMemories> collections,
) {
  final l10n = context.l10n;
  final locale = l10n.localeName;

  return [
    for (final entry in collections)
      (
        id: entry.collection.id,
        cover: entry.cover,
        title: entry.collection.title,
        summary: [
          l10n.memoryCount(entry.memories.length),
          if (entry.collection.startDate case final start?)
            AppDateFormats.range(
              start,
              entry.collection.endDate,
              locale: locale,
            ),
        ].join(' • '),
        memories: [
          for (final memory in entry.memories)
            (
              id: memory.id,
              cover: memory.coverMedia,
              title: memory.displayTitle(l10n.memoryNew),
              dateLabel: AppDateFormats.long(memory.occurredAt, locale: locale),
            ),
        ],
      ),
  ];
}

/// Kök navigator anahtarı — shell dışına (tam ekran) açılan sayfalar için.
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(appPreferencesProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    // Uygulama giriş ekranıyla açılır. (İlk kurulumda aşağıdaki `redirect`
    // önce onboarding'e yönlendirir; o bitince yine buraya döner.)
    initialLocation: AppRoute.signIn.path,
    debugLogDiagnostics: true,

    /// FR-001/FR-004 — onboarding tamamlanmadıysa oraya yönlendir.
    ///
    /// `redirect` her navigasyonda çalışır; ağır iş YAPMA.
    redirect: (context, state) {
      final goingToOnboarding =
          state.matchedLocation == AppRoute.onboarding.path;

      if (!prefs.onboardingCompleted && !goingToOnboarding) {
        return AppRoute.onboarding.path;
      }
      if (prefs.onboardingCompleted && goingToOnboarding) {
        return AppRoute.signIn.path;
      }
      return null; // yönlendirme yok
    },

    routes: [
      GoRoute(
        path: AppRoute.onboarding.path,
        name: AppRoute.onboarding.name,
        builder: (context, state) => const OnboardingView(),
      ),

      // --- Giriş ------------------------------------------------------------
      //
      // DİKKAT: Giriş ekranı tanımlı ama HENÜZ ZORUNLU DEĞİL. Yukarıdaki
      // `redirect` içine "oturum yoksa /sign-in'e gönder" kuralını bilerek
      // koymuyoruz: backend (Firebase mi kendi API mi) seçilmeden oturumun
      // nasıl saklanacağı belli değil ve yarım bir kapı kullanıcıyı
      // uygulamadan kilitler.
      //
      // Backend seçildiğinde eklenecek kural:
      //   if (!hasSession && !goingToSignIn) return AppRoute.signIn.path;
      GoRoute(
        path: AppRoute.signIn.path,
        name: AppRoute.signIn.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignInView(),
      ),
      GoRoute(
        path: AppRoute.signUp.path,
        name: AppRoute.signUp.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignUpView(),
      ),

      // --- Alt sekmeli ana kabuk -----------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        // SIRA ÖNEMLİ: bu liste alt çubuktaki sekme sırasıyla BİREBİR aynı
        // olmalı (bkz. app_shell.dart). `navigationShell.currentIndex`
        // doğrudan bu sıraya karşılık geliyor.
        branches: [
          // 0 — Ana Sayfa
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.home.path,
                name: AppRoute.home.name,
                // SAYAÇLARI BURASI KURUYOR: hedefleri "Hayatım"ın
                // sekmeleri ve o tip başka feature'ın presentation'ında.
                builder: (context, state) => Consumer(
                  builder: (context, ref, _) => HomeView(
                    stats: homeStats(
                      context.l10n,
                      ref.watch(homeCountsProvider),
                      onOpen: (route, {query = const {}}) =>
                          context.goNamed(route.name, queryParameters: query),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // 1 — Hayatım (tasarımı bekliyor)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.myLife.path,
                name: AppRoute.myLife.name,
                // `?tab=` ile hangi sekmenin açılacağı belirtilebiliyor:
                // ana sayfadaki "SERİLER" ve "KOLEKSİYONLAR" sayaçları
                // doğrudan o sekmeye götürüyor.
                //
                // TANINMAYAN DEĞER SESSİZCE YOK SAYILIYOR (`fromQuery` null
                // döner, varsayılan takvim): eski ya da elle yazılmış bir
                // bağlantı kullanıcıyı hata ekranına düşürmemeli.
                // CONSUMER: bu oturumda oluşturulan ritüeller "Serilerim"e
                // buradan giriyor. `MyLifeView` ritüel feature'ını görmüyor
                // (ARCHITECTURE.md — feature'lar birbirinin `presentation`ını
                // import etmez); composition root ikisini de bildiği için
                // dönüşümü burada yapıyoruz. Koleksiyon süzgecinde de aynı yol.
                builder: (context, state) => Consumer(
                  builder: (context, ref, _) => MyLifeView(
                    initialTab:
                        MyLifeTab.fromQuery(state.uri.queryParameters['tab']) ??
                        MyLifeTab.calendar,
                    // Oturumda oluşturulan seriler ve koleksiyonlar listenin
                    // BAŞINA giriyor.
                    series: _seriesCards(
                      context,
                      ref.watch(ritualsWithMemoriesProvider).value ?? const [],
                    ),
                    collections: _collectionCards(
                      context,
                      ref.watch(collectionsWithMemoriesProvider).value ??
                          const [],
                    ),
                    // KİŞİYİ KOLEKSİYON KİMLİKLERİNE ÇEVİREN YER BURASI.
                    //
                    // "Hayatım" ekranı kişileri bilmiyor ve bilmemeli: iki
                    // ayrı feature ve biri ötekinin verisini import edemez.
                    // Ama composition root her şeyi bilebilir
                    // (bkz. ARCHITECTURE.md bölüm 2) — kişiyi burada çözüp
                    // ekrana hazır liste veriyoruz.
                    collectionFilter: _collectionFilterFor(
                      ref,
                      state.uri.queryParameters['person'],
                    ),
                    // Süzgeci kaldırmak = aynı sekmeye kişisiz gitmek.
                    onClearFilter: () => context.goNamed(
                      AppRoute.myLife.name,
                      queryParameters: {'tab': MyLifeTab.collections.name},
                    ),
                    // Sekmeye dokunmak URL'yi de güncelliyor.
                    //
                    // Sekme durumunun tek doğru kaynağı rota olmasa derin
                    // bağlantı bir kez çalışıp susuyordu: kullanıcı sayaçla
                    // serilere gidip elle takvime geçtiğinde URL hâlâ
                    // `?tab=series` kalıyor ve sayaca ikinci kez basmak
                    // hiçbir değişiklik üretmiyordu.
                    onTabChanged: (tab) => context.goNamed(
                      AppRoute.myLife.name,
                      queryParameters: {'tab': tab.name},
                    ),
                  ),
                ),
              ),
            ],
          ),
          // 2 — Mağaza (V2.5 Atölye; tasarımı bekliyor)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.store.path,
                name: AppRoute.store.name,
                builder: (context, state) => ComingSoonView(
                  title: context.l10n.navStore,
                  icon: AppIcons.navStore,
                ),
              ),
            ],
          ),
          // 3 — Profilim
          //
          // GEÇİCİ: profil ekranı tasarlanana kadar mevcut AYARLAR ekranını
          // gösteriyoruz. Yer tutucu koysaydık tema ve dil anahtarına erişim
          // kaybolurdu; ikisi de tasarım aşamasında sürekli lazım.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.profile.path,
                name: AppRoute.profile.name,
                builder: (context, state) => const SettingsView(),
              ),
            ],
          ),
        ],
      ),

      // --- Alt çubukta olmayan, ekranı duran bölümler --------------------
      GoRoute(
        path: AppRoute.memories.path,
        name: AppRoute.memories.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MemoryListView(),
      ),
      GoRoute(
        path: AppRoute.journal.path,
        name: AppRoute.journal.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const JournalView(),
      ),
      GoRoute(
        path: AppRoute.people.path,
        name: AppRoute.people.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PeopleView(),
      ),
      GoRoute(
        path: AppRoute.search.path,
        name: AppRoute.search.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SearchView(),
      ),
      GoRoute(
        path: AppRoute.settings.path,
        name: AppRoute.settings.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsView(),
      ),

      // --- Tam ekran sayfalar (alt sekme çubuğu olmadan) -----------------
      //
      // DİKKAT: `/memory/new` rotası `/memory/:id`den ÖNCE gelmeli,
      // yoksa "new" bir id sanılır.
      // Yeni anı AKIŞININ İLK ADIMI: fotoğraf seçimi.
      //
      // DİKKAT: `/memory/new/details` bu yoldan DAHA UZUN olduğu için
      // go_router onu ayrı bir rota olarak doğru eşliyor; sıra da uzun
      // yoldan kısaya doğru yazıldı ki karışmasın.
      GoRoute(
        path: AppRoute.memoryNewDetails.path,
        name: AppRoute.memoryNewDetails.name,
        parentNavigatorKey: _rootNavigatorKey,
        // `extra` ile ilk adımda seçilen fotoğrafların dosya yolları geliyor.
        //
        // TİP KONTROLÜ ŞART: `extra` `Object?`tir, derleyici bir şey garanti
        // etmiyor. Rotaya doğrudan (deep link ya da test) `extra` vermeden
        // girilebilir; o durumda boş liste ile devam ediyoruz, çökmüyoruz.
        builder: (context, state) => MemoryEditorView(
          pickedPhotoPaths: switch (state.extra) {
            final List<String> paths => paths,
            _ => const [],
          },
        ),
      ),
      GoRoute(
        path: AppRoute.memoryNew.path,
        name: AppRoute.memoryNew.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MemoryNewPhotosView(),
      ),
      GoRoute(
        path: AppRoute.memoryEdit.path,
        name: AppRoute.memoryEdit.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            MemoryEditorView(memoryId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoute.memoryPicker.path,
        name: AppRoute.memoryPicker.name,
        parentNavigatorKey: _rootNavigatorKey,
        // Formda ZATEN seçili olan anılar `extra` ile geliyor: ekran ikinci
        // kez açıldığında kullanıcı seçimlerini işaretli bulmalı. Tip kontrolü
        // şart — `extra` `Object?` ve yanlış tip gelirse çökerdi.
        // SORGUYU BURASI YAPIYOR: seçici `shared/` altında ve hiçbir
        // feature'ın veri katmanını tanımıyor (ARCHITECTURE.md §2).
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => IzMemoryPickerView(
            memories: ref.watch(pickableMemoriesProvider),
            initialSelection: switch (state.extra) {
              final Set<String> selected => selected,
              _ => const {},
            },
          ),
        ),
      ),
      GoRoute(
        path: AppRoute.memoryDetail.path,
        name: AppRoute.memoryDetail.name,
        parentNavigatorKey: _rootNavigatorKey,
        // `extra` ile TASARIM ÖNİZLEMESİNDEN gelen hazır kayıt taşınabiliyor.
        //
        // ⚠️ GEÇİCİ — bkz. `MemoryDetailView.previewDetail`. Ana sayfa ve
        // "Hayatım" sahte anılar gösteriyor; kimlikleri veritabanında yok ve
        // düz bir geçiş kullanıcıyı "Bulunamadı" ekranına düşürürdü.
        //
        // TİP KONTROLÜ ŞART: `extra` `Object?`tir, derleyici bir şey garanti
        // etmiyor. `extra` verilmeden girilen her çağrı (derin bağlantı, liste
        // ekranı, arama) eskisi gibi depodan okuyor.
        builder: (context, state) => MemoryDetailView(
          memoryId: state.pathParameters['id']!,
          previewDetail: switch (state.extra) {
            final MemoryDetail detail => detail,
            _ => null,
          },
        ),
      ),
      GoRoute(
        path: AppRoute.personNew.path,
        name: AppRoute.personNew.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PersonEditorView(),
      ),
      GoRoute(
        path: AppRoute.personDetail.path,
        name: AppRoute.personDetail.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            PersonDetailView(personId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoute.journalAll.path,
        name: AppRoute.journalAll.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const JournalAllEntriesView(),
      ),
      GoRoute(
        path: AppRoute.journalNew.path,
        name: AppRoute.journalNew.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const JournalEditorView(),
      ),
      GoRoute(
        path: AppRoute.collectionNew.path,
        name: AppRoute.collectionNew.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CollectionEditorView(),
      ),
      GoRoute(
        // AYNI EKRAN, DÜZENLEME KİPİ. Kimlik yoldan geliyor: derin bağlantı
        // ve geri tuşu kendiliğinden çalışsın (anı ve kişi formlarında da
        // aynı).
        path: AppRoute.collectionEdit.path,
        name: AppRoute.collectionEdit.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            CollectionEditorView(collectionId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoute.ritualNew.path,
        name: AppRoute.ritualNew.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RitualEditorView(),
      ),
      GoRoute(
        path: AppRoute.ritualDetail.path,
        name: AppRoute.ritualDetail.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;

          return Consumer(
            builder: (context, ref, _) => RitualDetailView(
              ritual: _ritualDetail(
                id,
                ref.watch(ritualsWithMemoriesProvider).value ?? const [],
                context.l10n,
              ),
              // Detay ekranı anıyı KİMLİKTEN yüklüyor; kayıt yanında
              // taşınmıyor.
              onOpenMemory: (memoryId) => unawaited(
                context.pushNamed(
                  AppRoute.memoryDetail.name,
                  pathParameters: {'id': memoryId},
                ),
              ),
            ),
          );
        },
      ),
      // Düzenleme, yeni kişiyle AYNI ekran: kimlik gelince form dolu açılıyor.
      GoRoute(
        path: AppRoute.personEdit.path,
        name: AppRoute.personEdit.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            PersonEditorView(personId: state.pathParameters['id']!),
      ),
    ],

    // NOT: `state.error` teknik bir mesajdır (stack trace içerir) ve
    // kullanıcıya gösterilmez — sadece çevrilmiş metni basıyoruz.
    errorBuilder: (context, state) => const _RouteErrorView(),
  );
});

class _RouteErrorView extends StatelessWidget {
  const _RouteErrorView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.routeNotFound, size: AppIconSize.xl),
              const SizedBox(height: 16),
              Text(context.l10n.routeNotFound, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.goNamed(AppRoute.home.name),
                child: Text(context.l10n.routeGoHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
