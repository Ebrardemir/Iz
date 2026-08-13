/// "Hayatım" ekranı — MVVM'in **View** katmanı.
///
/// ⚠️ BU EKRAN HİÇBİR VERİ KAYNAĞINA BAĞLI DEĞİL — ana sayfayla aynı
/// gerekçe. Önce tasarım bitecek, veri bağlantısına sonra karar verilecek.
///
/// ⚠️ YAPIM AŞAMASINDA. Üst şerit, sekme çubuğu, ay gezinmesi, gün
/// başlıkları ve takvim ızgarası var. Sırada seçili günün anı listesi var.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/my_life/presentation/views/my_life_preview_data.dart';
import 'package:iz/features/my_life/presentation/widgets/calendar_grid.dart';
import 'package:iz/features/my_life/presentation/widgets/calendar_week_header.dart';
import 'package:iz/features/my_life/presentation/widgets/collection_card.dart';
import 'package:iz/features/my_life/presentation/widgets/collections_section.dart';
import 'package:iz/features/my_life/presentation/widgets/day_memories_panel.dart';
import 'package:iz/features/my_life/presentation/widgets/month_navigator.dart';
import 'package:iz/features/my_life/presentation/widgets/my_life_tab_bar.dart';
import 'package:iz/features/my_life/presentation/widgets/my_life_top_bar.dart';
import 'package:iz/features/my_life/presentation/widgets/series_card.dart';
import 'package:iz/features/my_life/presentation/widgets/series_section.dart';
import 'package:iz/shared/widgets/iz_popover_menu.dart';
import 'package:iz/shared/widgets/iz_screen_header.dart';

class MyLifeView extends ConsumerStatefulWidget {
  const MyLifeView({
    this.initialTab = MyLifeTab.calendar,
    this.onTabChanged,
    this.collectionFilter,
    this.onClearFilter,
    this.extraSeries = const [],
    this.extraCollections = const [],
    super.key,
  });

  /// Ekran hangi sekmeyle açılsın?
  ///
  /// Ana sayfadaki "SERİLER" ve "KOLEKSİYONLAR" sayaçları buraya derin
  /// bağlantıyla geliyor (`/my-life?tab=series`); rotayı okuyup bu değere
  /// çeviren yer `app_router.dart`. Varsayılan takvim — sekmeye dokunarak
  /// gelen kullanıcı her zaman onu görüyor.
  final MyLifeTab initialTab;

  /// Sekme değiştiğinde haber verilir.
  ///
  /// NEDEN GEREKLİ? Bu ekran alt çubuğun bir SEKMESİ ve
  /// `StatefulShellRoute.indexedStack` sekme durumunu KORUYOR: kullanıcı bir
  /// kez "Hayatım"a girdikten sonra ekran bir daha kurulmuyor, dolayısıyla
  /// [initialTab] de bir daha okunmuyor. Ana sayfadaki sayaca basmak URL'yi
  /// değiştiriyordu ama sekme takvimde kalıyordu — tam bunu yaşadık.
  ///
  /// Çözüm URL'yi TEK DOĞRU KAYNAK yapmak: sekmeye dokunmak da URL'yi
  /// güncelliyor, böylece "sayaca bas → elle takvime geç → yine sayaca bas"
  /// zincirinde bile iki taraf tutuyor.
  ///
  /// NULL GEÇİLEBİLİR: ekranı tek başına kuran testler router istemiyor, o
  /// durumda seçim yalnızca yerel state'te yaşıyor.
  final ValueChanged<MyLifeTab>? onTabChanged;

  /// Koleksiyonlar sekmesini DARALTAN süzgeç.
  ///
  /// Kullanıcı bir kişinin sayfasından "Kapadokya 2026"ya dokunduğunda tüm
  /// koleksiyonları değil, o kişiyle paylaştıklarını görmeli — geldiği bağlam
  /// kaybolmamalı.
  ///
  /// NEDEN KİŞİ KİMLİĞİ DEĞİL, KOLEKSİYON KİMLİKLERİ?
  /// Bu ekran "Hayatım" feature'ında, kişiler başka bir feature'da ve biri
  /// ötekinin verisini import edemez (bkz. ARCHITECTURE.md). Kimden geldiğini
  /// bilen taraf composition root: rota, kişiyi koleksiyon kimliklerine
  /// çevirip buraya hazır veriyor. Bu ekran yalnızca "şunları göster" duyuyor.
  ///
  /// [label] çipte görünüyor ("Annem ile") — kullanıcı neden az kart gördüğünü
  /// anlamalı, yoksa koleksiyonlarının kaybolduğunu sanır.
  final ({String label, Set<String> ids})? collectionFilter;

  /// Süzgeci kaldırma yolu. Süzülmüş bir listeden çıkışı olmayan kullanıcı
  /// sıkışıp kalır.
  final VoidCallback? onClearFilter;

  /// Listeye ÖNCE eklenecek seriler.
  ///
  /// Şu an tek kaynağı bu oturumda oluşturulan ritüeller: kullanıcı formu
  /// bitirdiğinde ritüelini burada görmeli, yoksa düğmenin çalıştığına dair
  /// hiçbir kanıtı olmuyor.
  ///
  /// NEDEN DIŞARIDAN? Bu ekran ritüel feature'ını görmüyor (ARCHITECTURE.md —
  /// feature'lar birbirinin `presentation`ını import etmez). Dönüşümü
  /// composition root yapıyor; koleksiyon süzgecinde de aynı yol kullanıldı.
  /// `RitualDao` yazıldığında bu parametre kalkacak, liste repository'den
  /// gelecek.
  final List<SeriesCardData> extraSeries;

  /// Listeye ÖNCE eklenecek koleksiyonlar — [extraSeries] ile aynı gerekçe:
  /// kullanıcı formu bitirdiğinde koleksiyonunu burada görmeli.
  final List<CollectionCardData> extraCollections;

  @override
  ConsumerState<MyLifeView> createState() => _MyLifeViewState();
}

class _MyLifeViewState extends ConsumerState<MyLifeView> {
  /// Seçili sekme — EKRANA AİT durum, veriye değil.
  ///
  /// Bu yüzden ViewModel'e taşımadık: hangi sekmenin açık olduğu
  /// repository'yi ilgilendirmiyor. Sekmeye göre İÇERİK gelmeye
  /// başladığında (takvim, koleksiyon listesi...) o içeriğin durumu
  /// ViewModel'e girer; seçim yine burada kalabilir.
  late MyLifeTab _selected = widget.initialTab;

  @override
  void didUpdateWidget(MyLifeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ROTADAN GELEN SEKME DEĞİŞİMİNİ YANSIT.
    //
    // Koşul ŞART: `didUpdateWidget` ebeveyn her yeniden çizildiğinde de
    // çağrılıyor. Koşulsuz atama yapsaydık kullanıcının elle seçtiği sekme
    // her karede varsayılana dönerdi.
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() => _selected = widget.initialTab);
    }
  }

  /// "Bugün" — ekran açıldığında BİR KEZ okunur.
  ///
  /// NEDEN ALANDA TUTULUYOR? Önce `DateTime.now()` üç ayrı yerde
  /// çağrılıyordu; biri `_visibleMonth`ta iki kez üst üste. Gece yarısını
  /// aşan bir karede iki çağrı farklı gün döner ve ekran kendi içinde
  /// tutarsız kalır (seçili gün bir ayda, görünen ay ötekinde).
  ///
  /// `clockProvider` üzerinden okuyoruz: `DateTime.now()` doğrudan
  /// çağrıldığında bu ekranın testi çalıştırıldığı güne göre sonuç
  /// değiştirir (bkz. core/utils/clock.dart).
  late final DateTime _today = ref.read(clockProvider).today();

  /// Takvimde görünen ay.
  ///
  /// Ay gezinmesi ve takvim ızgarası AYNI değere bakıyor, bu yüzden burada
  /// tutuluyor. Yalnızca yıl/ay anlamlı; günü 1'e sabitliyoruz ki ay
  /// sonlarında kayma olmasın (31 Mart'tan bir ay geri gidince 31 Şubat
  /// yoktur, DateTime bunu 3 Mart'a taşır).
  late DateTime _visibleMonth = DateTime(_today.year, _today.month);

  /// Takvimde seçili gün. Ekran açılınca bugün seçili.
  late DateTime _selectedDay = _today;

  void _shiftMonth(int delta) => setState(() {
    _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        // ÜST GÜVENLİ ALANI ŞERİT KENDİ YÖNETİYOR.
        //
        // `SafeArea` burada da açık olsaydı durum çubuğu payı iki kez
        // eklenirdi: bir kez burada, bir kez şeridin kendi hesabında.
        // Başlık tasarımdakinden ~30 px aşağıda kalıyordu.
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyLifeTopBar(
                // Arama ve filtre ekranları henüz tasarlanmadı; tıklanmayan
                // buton bozuk gelir, bu yüzden şimdilik "yakında" diyoruz.
                onSearch: () =>
                    context.showSnack(context.l10n.screenComingSoonMessage),
                onFilter: () =>
                    context.showSnack(context.l10n.screenComingSoonMessage),
              ),

              // ARADA BOŞLUK YOK — bilerek.
              //
              // Figma: üst şerit 24..76, sekme çubuğu 76'da başlıyor. Nefesi
              // şeridin kendi dolgusu veriyor; buraya ayrıca boşluk koyunca
              // çubuk tasarımdakinden 16 px aşağı iniyordu.
              MyLifeTabBar(
                selected: _selected,
                onSelected: (tab) {
                  setState(() => _selected = tab);
                  // URL'yi de güncelle: sekme durumunun tek doğru kaynağı
                  // rota (bkz. [MyLifeView.onTabChanged]).
                  widget.onTabChanged?.call(tab);
                },
              ),

              // SEKMEYE GÖRE İÇERİK.
              //
              // Üç sekme de kendi gövdesini getiriyor; üst şerit ve sekme
              // çubuğu her hâlde yerinde kalıyor. `IndexedStack` KULLANMIYORUZ:
              // o üç gövdeyi birden kurar ve görünmeyenlerin de yüksekliğini
              // hesaplar; sayfa `SingleChildScrollView` içinde olduğu için
              // bu gereksiz iş ve yanlış kaydırma boyu demek.
              switch (_selected) {
                MyLifeTab.calendar => _calendarBody(context),
                MyLifeTab.collections => _collectionsBody(context),
                MyLifeTab.series => _seriesBody(context),
              },
            ],
          ),
        ),
      ),
    );
  }

  // --- TAKVİM sekmesi -------------------------------------------------------

  Widget _calendarBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Figma: sekme çubuğunun altı 116, ay satırı 128 → 12 boşluk.
        const SizedBox(height: 12),
        MonthNavigator(
          month: _visibleMonth,
          onPrevious: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
        ),

        // Figma: ay satırının altı 176, gün başlıkları 180 → 4.
        const SizedBox(height: AppSpacing.xs),
        const CalendarWeekHeader(),

        // Figma: gün başlıklarının altı 204, ızgara 216 → 12.
        const SizedBox(height: 12),
        CalendarGrid(
          month: _visibleMonth,
          today: _today,
          selectedDay: _selectedDay,
          covers: MyLifePreviewData.coversFor(_visibleMonth),
          onDaySelected: (day) => setState(() => _selectedDay = day),
        ),

        // IZGARA İLE PANEL ARASINDA BOŞLUK YOK — bilerek.
        //
        // Figma: ızgara 216'da başlıyor, 336 yüksek → 552'de bitiyor. Panel
        // ise 550'de başlıyor, yani 2px ÜST ÜSTE biniyorlar. O 2px panelin
        // üst kenarlığının kendisi: çizgi ızgaranın dibine oturuyor. Araya
        // boşluk koyunca panel tasarımdakinden aşağı kayıyor ve alt çubukla
        // arasında boş bir şerit kalıyor.
        DayMemoriesPanel(
          day: _selectedDay,
          memories: MyLifePreviewData.memoriesFor(
            _selectedDay,
            // Tarih etiketi ekranın DİLİNDE olmalı; `Intl.defaultLocale`
            // genel değişkenine güvenmiyoruz (bkz. month_navigator.dart).
            locale: Localizations.localeOf(context).toLanguageTag(),
          ),
          onOpenMemory: (memory) => _openMemory(
            memory.id,
            MyLifePreviewData.dayMemoryDetail(memory, _selectedDay),
          ),
          onAddMemory: () => context.pushNamed(AppRoute.memoryNew.name),
        ),
      ],
    );
  }

  // --- KOLEKSİYONLAR sekmesi ------------------------------------------------

  Widget _collectionsBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Figma: sekme çubuğunun altı 116, liste 123'te başlıyor → ~8.
        const SizedBox(height: AppSpacing.sm),
        if (widget.collectionFilter case final filter?) ...[
          _FilterChip(label: filter.label, onClear: widget.onClearFilter),
          const SizedBox(height: AppSpacing.sm),
        ],

        CollectionsSection(
          collections: _visibleCollections(context),
          onOpenMemory: (memory) => _openMemory(
            memory.id,
            MyLifePreviewData.collectionMemoryDetail(memory.id),
          ),
          onMemoryActions: _showMemoryActions,
        ),
      ],
    );
  }

  /// Görünecek koleksiyonlar — süzgeç varsa daraltılmış.
  List<CollectionCardData> _visibleCollections(BuildContext context) {
    final all = [
      // Yeni oluşturulanlar EN ÜSTTE.
      ...widget.extraCollections,
      ...MyLifePreviewData.collections(
        context.l10n,
        locale: Localizations.localeOf(context).toLanguageTag(),
      ),
    ];

    final filter = widget.collectionFilter;
    if (filter == null) return all;

    return [
      for (final collection in all)
        if (filter.ids.contains(collection.id)) collection,
    ];
  }

  // --- SERİLERİM sekmesi ----------------------------------------------------

  Widget _seriesBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Koleksiyonlar sekmesiyle aynı üst boşluk: sekmeler arasında geçerken
        // ilk kart zıplamasın.
        const SizedBox(height: AppSpacing.sm),
        SeriesSection(
          // Yeni oluşturulanlar EN ÜSTTE: kullanıcı az önce kurduğu ritüeli
          // aşağı kaydırıp aramamalı.
          series: [
            ...widget.extraSeries,
            ...MyLifePreviewData.series(context.l10n),
          ],
          // Serinin kendi ekranı: kapak, sayılar ve seriye bağlı anılar.
          onOpenSeries: (series) => unawaited(
            context.pushNamed(
              AppRoute.ritualDetail.name,
              pathParameters: {'id': series.id},
            ),
          ),
          // Şeritteki bir yıla dokunmak O YILIN anısını açıyor: serinin
          // kendi ekranı henüz yok ama tek tek yıllar birer anı ve onlara
          // gidilebilir.
          onOpenYear: (year) => _openMemory(
            year.memoryId,
            MyLifePreviewData.seriesYearDetail(year.memoryId),
          ),
        ),
      ],
    );
  }

  /// Anı detayına gider.
  ///
  /// ÖNİZLEME KAYDINI YANINDA GÖTÜRÜYOR. Bu ekran henüz hiçbir veri kaynağına
  /// bağlı değil; gösterdiği anılar `MyLifePreviewData` içindeki sahte
  /// kayıtlar ve kimliklerinin veritabanında karşılığı yok. Düz bir geçiş
  /// kullanıcıyı "Bulunamadı" ekranına düşürürdü.
  ///
  /// [detail] null gelirse `extra` boş gidiyor ve detay ekranı eskisi gibi
  /// depodan okuyor — gerçek bir anı için doğru davranış bozulmuyor.
  ///
  /// Veri bağlandığında yalnızca `extra` argümanı silinecek.
  void _openMemory(String id, MemoryDetail? detail) => context.pushNamed(
    AppRoute.memoryDetail.name,
    pathParameters: {'id': id},
    extra: detail,
  );

  /// Anı satırındaki üç noktanın açtığı menü.
  ///
  /// MENÜYÜ EKRAN AÇIYOR, KART DEĞİL: `CollectionCard` saf bir widget ve
  /// `Navigator`ı bilmemeli (bkz. ARCHITECTURE.md — `widgets/` mümkün
  /// olduğunca Riverpod'suz ve navigasyonsuz). Kart yalnızca dokunulan
  /// düğmenin ekrandaki kutusunu ([anchor]) bildiriyor; menü ona çıpalanıyor.
  Future<void> _showMemoryActions(
    CollectionMemoryData memory,
    Rect anchor,
  ) async {
    final l10n = context.l10n;

    await showIzPopoverMenu(
      context,
      anchor: anchor,
      actions: [
        (
          icon: AppIcons.goTo,
          label: l10n.memoryOpenDetail,
          isDestructive: false,
          onPressed: () => _openMemory(
            memory.id,
            MyLifePreviewData.collectionMemoryDetail(memory.id),
          ),
        ),
        // Yıkıcı eylem SONDA: kullanıcının parmağı listede aşağı inerken
        // yanlışlıkla ona denk gelmesin.
        (
          icon: AppIcons.delete,
          label: l10n.commonDelete,
          isDestructive: true,
          onPressed: _confirmDelete,
        ),
      ],
    );
  }

  /// NFR-034: "Kritik silme/paylaşma/sipariş işlemlerinde açık onay ve geri
  /// bildirim bulunmalıdır." Silme eylem sayfasından DOĞRUDAN çalışmıyor;
  /// araya onay giriyor.
  Future<void> _confirmDelete() async {
    final l10n = context.l10n;

    final confirmed = await context.confirm(
      title: l10n.memoryDeleteTitle,
      message: l10n.memoryDeleteMessage,
      confirmLabel: l10n.memoryDeleteConfirm,
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    // Silinecek gerçek bir kayıt yok; veri bağlandığında burası
    // `memoryListProvider.notifier.moveToTrash(id)` olacak ve dönüşte
    // "Geri al" eylemli bir bildirim çıkacak (FR-015).
    context.showSnack(l10n.screenComingSoonMessage);
  }
}

/// Koleksiyonların bir kişiye süzüldüğünü gösteren çip.
///
/// GÖRÜNÜR OLMAK ZORUNDA. Süzgeci sessizce uygulamak, kullanıcıya
/// koleksiyonlarının silindiğini düşündürür — çip hem sebebi söylüyor hem
/// çıkışı gösteriyor.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IzScreenHeader.kPageInset,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              top: 6,
              bottom: 6,
              right: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.filter,
                  size: AppIconSize.sm,
                  color: colors.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.myLifeFilteredByPerson(label),
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                // Kapatma ÇİPİN İÇİNDE: süzgeç ve onu kaldırma yolu tek bir
                // nesne olarak okunuyor.
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(AppIcons.clear),
                  iconSize: AppIconSize.sm,
                  color: colors.onSecondaryContainer,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 24,
                    height: 24,
                  ),
                  tooltip: context.l10n.myLifeClearFilter,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
