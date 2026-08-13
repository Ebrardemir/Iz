/// Seri detay ekranı — FR-075, FR-076.
///
/// YERLEŞİM (referans tasarım, kullanıcının çıkardıklarıyla):
///   ┌──────────────────────────────┐
///   │ ‹    Yaz Tatillerimiz     ⋮ │  ⋮ → Düzenle / Sil
///   │ ┌──────────────────────────┐ │
///   │ │        kapak             │ │  altında YAZI YOK
///   │ └──────────────────────────┘ │
///   │ [4 yıl] [12 anı] [4 şehir]   │  sayılar anılardan türetiliyor
///   │ Bu Serideki Anılar  Tümünü › │
///   │ ┌──────────────────────────┐ │
///   │ │ [img] Kaş'ta gün batımı ›│ │  dokun → anı detayı
///   │ │       20 Tem 2025 (Seyahat)│ │
///   │ └──────────────────────────┘ │
///   └──────────────────────────────┘
///
/// REFERANSTAN ÇIKARILANLAR (kullanıcının kararı):
///   • kapağın altındaki slogan
///   • "Yıllar" şeridi
///   • satırlardaki üç nokta
///   • alttaki "Kolaj Oluştur" ve "Bu Yıla Anı Ekle" düğmeleri
/// Geriye tek bir soruya cevap veren bir sayfa kalıyor: bu seride NELER var?
///
/// "TÜMÜNÜ GÖR" AYRI SAYFA AÇMIYOR, LİSTEYİ YERİNDE AÇIYOR.
/// Ayrı bir sayfa aynı satırların aynı sırada durduğu ikinci bir ekran olurdu
/// — kullanıcıya bir dokunuş daha, bize bakımı gereken bir ekran daha. Üstelik
/// yukarıdaki kapak ve sayılar orada kaybolurdu; oysa "12 anıdan 6'sını
/// görüyorum" bilgisini veren şey tam olarak onlar. Sayfada başka içerik
/// olmadığı için liste uzasa da ekran karmaşıklaşmıyor: aşağı kaydırmak zaten
/// tek yapılacak şey.
///
/// KISALTMA YİNE DE VAR ([kCollapsedCount]): on yıllık bir seride sayfayı
/// açar açmaz beş ekran boyu liste görmek, kapağı ve sayıları anlamsız
/// kılıyordu. İlk altı satır bir örnek; gerisi bir dokunuş uzakta.
///
/// ⚠️ VERİ KAYNAĞI YOK. `RitualDao` yazılmadı; ekran dışarıdan hazır bir kayıt
/// alıyor ([RitualDetailData]) ve onu composition root dolduruyor —
/// önizleme serilerinde `RitualDetailPreviewData`dan, bu oturumda oluşturulan
/// serilerde `createdRitualsProvider`dan.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_add_menu.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/rituals/domain/ritual_stats.dart';
import 'package:iz/features/rituals/presentation/views/ritual_detail_preview_data.dart';
import 'package:iz/features/rituals/presentation/widgets/ritual_detail_parts.dart';
import 'package:iz/shared/widgets/app_empty_state.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';
import 'package:iz/shared/widgets/iz_popover_menu.dart';
import 'package:iz/shared/widgets/iz_screen_header.dart';

/// Ekranın beklediği kayıt.
///
/// DÜZ BİR KAYIT, entity değil: ekranın ihtiyacı olan her şey burada ve
/// nereden geldiğini bilmiyor. `RitualDao` yazıldığında bu kaydı repository
/// dolduracak, ekran değişmeyecek.
typedef RitualDetailData = ({
  String id,
  String title,
  MediaItem? cover,
  List<RitualDetailMemory> memories,
});

class RitualDetailView extends StatefulWidget {
  const RitualDetailView({
    required this.ritual,
    required this.onOpenMemory,
    super.key,
  });

  /// null ise seri bulunamadı (eski bağlantı, elle yazılmış rota).
  final RitualDetailData? ritual;

  /// Bir anıya gitmek.
  ///
  /// EKRAN KENDİ GİTMİYOR: önizleme anılarının veritabanında karşılığı yok ve
  /// detay ekranına kaydı yanında götürmek gerekiyor. Bunu bilen taraf
  /// composition root (bkz. `app_router.dart`).
  final void Function(String memoryId) onOpenMemory;

  /// Liste kısaltıldığında gösterilen satır sayısı.
  ///
  /// DÖRT: referansta üç satır görünüyordu. Altı denendi ve kısaltmanın
  /// anlamı kalmıyordu — telefon ekranına zaten o kadarı sığıyor, "Tümünü
  /// Gör" hiç görünmüyordu. Dört satır serinin ritmini gösteriyor, gerisi tek
  /// dokunuş.
  static const int kCollapsedCount = 4;

  @override
  State<RitualDetailView> createState() => _RitualDetailViewState();
}

class _RitualDetailViewState extends State<RitualDetailView> {
  /// Üç noktanın ekrandaki yerini ölçmek için — menü onun altında açılıyor.
  final _actionsKey = GlobalKey();

  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ritual = widget.ritual;

    if (ritual == null) {
      return Scaffold(
        appBar: AppBar(),
        body: AppEmptyState(
          icon: AppIcons.searchEmpty,
          title: l10n.errorNotFound,
        ),
      );
    }

    final memories = ritual.memories;
    final stats = ritualStats([
      for (final memory in memories)
        (year: memory.year, placeLabel: memory.placeLabel),
    ]);

    final isTruncated =
        !_showAll && memories.length > RitualDetailView.kCollapsedCount;
    final visible = isTruncated
        ? memories.take(RitualDetailView.kCollapsedCount).toList()
        : memories;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        // BAŞLIK APPBAR'DA: kişi detayında tersini yaptık (ad büyük, altta)
        // çünkü orada sayfanın konusu bir KİŞİYDİ ve fotoğrafıyla birlikte
        // duruyordu. Burada sayfanın konusu kapak fotoğrafı; serinin adını
        // onun üstüne yazmak ikisini birbiriyle yarıştırırdı.
        title: Text(ritual.title),
        actions: [
          IconButton(
            key: _actionsKey,
            onPressed: () => _openActions(ritual),
            icon: const Icon(AppIcons.more),
            tooltip: l10n.ritualDetailActions,
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          IzScreenHeader.kPageInset,
          AppSpacing.sm,
          IzScreenHeader.kPageInset,
          AppSpacing.xxl,
        ),
        children: [
          RitualDetailCover(cover: ritual.cover),
          if (ritual.cover != null) const SizedBox(height: AppSpacing.md),

          RitualStatBoxes(
            yearCount: stats.yearCount,
            memoryCount: stats.memoryCount,
            cityCount: stats.cityCount,
          ),
          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.ritualDetailMemories,
                  style: context.text.titleMedium?.copyWith(
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Düğme YALNIZCA gereğinde: altı satırın altında duran bir
              // "Tümünü Gör" hiçbir şey açmıyor ve kullanıcıyı bir şey
              // kaçırdığına inandırıyordu.
              if (memories.length > RitualDetailView.kCollapsedCount)
                TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(
                    _showAll
                        ? l10n.ritualDetailShowLess
                        : l10n.ritualDetailShowAll,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          if (memories.isEmpty)
            _EmptyNote(l10n.ritualDetailNoMemories)
          else
            for (final memory in visible) ...[
              RitualMemoryRow(
                memory: memory,
                onTap: () => widget.onOpenMemory(memory.id),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),

      // Anı ve kişi detaylarıyla AYNI karar: detay ekranı bir sekmenin içinde
      // değil ama alt çubuk yine duruyor — kullanıcı bir seriye bakarken
      // uygulamanın dışına düşmüş gibi hissetmemeli.
      bottomNavigationBar: IzBottomNav(
        destinations: IzBottomNav.appTabs(l10n),
        // Hiçbir sekmede değil: birini vurgulamak yanlış bir yer bildirirdi.
        currentIndex: IzBottomNav.noSelection,
        // `go`: sekmeye dokunmak detaydan ÇIKMAK demek. `push` olsaydı sekme
        // detayın üstüne biner, geri tuşu kullanıcıyı buraya düşürürdü.
        onSelect: (index) => context.go(AppRoute.tabs[index].path),
        addIcon: AppIcons.add,
        addLabel: l10n.navAdd,
        // Halka menüyü ancak kabuk kurabiliyor; bir seriye bakarken "+"
        // büyük olasılıkla "bu seriye bir anı" demek.
        onAdd: () => showAppAddMenu(context),
      ),
    );
  }

  /// Üç noktanın altında açılan menü: düzenle ve sil.
  ///
  /// Kişi detayındaki menüyle AYNI bileşen (`IzPopoverMenu`) ve aynı sıra:
  /// yıkıcı eylem sonda ve kırmızı. İki ekranda iki farklı menü görünümü,
  /// kullanıcıya iki farklı uygulama gibi gelirdi.
  Future<void> _openActions(RitualDetailData ritual) async {
    final l10n = context.l10n;
    final box = _actionsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    await showIzPopoverMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      actions: [
        (
          icon: AppIcons.edit,
          label: l10n.ritualEditAction,
          isDestructive: false,
          // Düzenleme ekranı mevcut seriyi YÜKLEYEMİYOR: `RitualDao` yok ve
          // form yalnızca yeni kayıt için yazıldı. Kişi formunda olduğu gibi
          // kimlik alan bir kip eklendiğinde burası o rotaya gidecek.
          onPressed: _comingSoon,
        ),
        (
          icon: AppIcons.delete,
          label: l10n.ritualDeleteAction,
          isDestructive: true,
          onPressed: _confirmDelete,
        ),
      ],
    );
  }

  /// NFR-034: kritik silme işleminde açık onay.
  Future<void> _confirmDelete() async {
    final l10n = context.l10n;

    final confirmed = await context.confirm(
      title: l10n.ritualDeleteTitle,
      // Kişi silmedeki sözle aynı: bir KABI silmek içindekini silmiyor.
      // Kullanıcı bunu onaydan önce bilmeli.
      message: l10n.ritualDeleteMessage,
      confirmLabel: l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    // ⚠️ SİLME HATTI YOK (`RitualDao` yazılmadı). Onay akışı yine de kuruluyor
    // ki hat geldiğinde davranış değişmesin.
    _comingSoon();
  }

  void _comingSoon() => context.showSnack(context.l10n.screenComingSoonMessage);
}

/// Seride hiç anı yokken gösterilen not.
///
/// Bölümü gizlemek de bir seçenekti; göstermeyi seçtik çünkü başlığın varlığı
/// "burada böyle bir şey olabilir" diyor — kişi detayındaki boş bölümlerle
/// aynı karar.
class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Text(
      text,
      style: context.text.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}
