/// Kişi detay ekranı — FR-062, FR-063.
///
/// YERLEŞİM (referans tasarım):
///   ┌──────────────────────────────┐
///   │ ←                        ⋮  │
///   │ (◕)  Annem                   │
///   │      Anne / Baba             │
///   │      🎂 18 Nisan             │
///   │ Koleksiyonlarımız            │
///   │ ┌──────────────────────────┐ │
///   │ │ [img] Kapadokya 2026   › │ │  → o kişiye süzülmüş koleksiyonlar
///   │ │       8 anı              │ │
///   │ └──────────────────────────┘ │
///   │ Ritüellerimiz                │
///   │ ┌──────────────────────────┐ │
///   │ │ 🎂 Doğum Günleri   5 yıl │ │  ok YOK: bilgi, bağlantı değil
///   │ └──────────────────────────┘ │
///   └──────────────────────────────┘
///
/// REFERANSTAN ÇIKARILANLAR (kullanıcının kararı):
///   • "Yaşam Çizgisi"
///   • "Birlikte Anılarımız" şeridi
///   • "+ Birlikte Anı Ekle" düğmesi
/// Sayfa böylece tek bir soruya cevap veriyor: bu kişiyle NELERİ paylaşıyoruz?
/// Anıların kendisi koleksiyonların içinde ve anı listesinde duruyor.
///
/// KİŞİ DEPODAN geliyor ve akış canlı. KOLEKSİYON ve RİTÜELLER hâlâ
/// önizleme verisinde: `CollectionDao` ve `RitualDao` yazılmadı (M6).
/// O iki bölüm bağlandığında `PersonDetailPreviewData` da silinecek.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_add_menu.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/my_life/presentation/widgets/my_life_tab_bar.dart';
import 'package:iz/features/people/data/repositories/person_repository_impl.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/people/presentation/view_models/people_list_view_model.dart';
import 'package:iz/features/people/presentation/views/person_detail_preview_data.dart';
import 'package:iz/features/people/presentation/widgets/person_detail_header.dart';
import 'package:iz/features/people/presentation/widgets/person_detail_rows.dart';
import 'package:iz/shared/widgets/app_empty_state.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';
import 'package:iz/shared/widgets/iz_divided_card.dart';
import 'package:iz/shared/widgets/iz_popover_menu.dart';
import 'package:iz/shared/widgets/iz_screen_header.dart';

class PersonDetailView extends ConsumerStatefulWidget {
  const PersonDetailView({required this.personId, super.key});

  final String personId;

  @override
  ConsumerState<PersonDetailView> createState() => _PersonDetailViewState();
}

class _PersonDetailViewState extends ConsumerState<PersonDetailView> {
  /// Üç noktanın ekrandaki yerini ölçmek için.
  ///
  /// Menü o düğmenin ALTINDA açılıyor ve `showIzPopoverMenu` ekran
  /// koordinatlarında bir dikdörtgen istiyor; widget'ın kendi kutusunu ancak
  /// bir anahtarla bulabiliyoruz.
  final _actionsKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Kişi DEPODAN geliyor ve akış canlı: düzenleme ekranında ad değişince
    // bu ekran kendiliğinden güncelleniyor.
    //
    // `asData` kullanıyoruz çünkü yükleme karesinde `person` henüz yok ve
    // aşağıdaki "bulunamadı" ekranı bir an için parlardı. Yüklenirken
    // hiçbir şey göstermemek, yanlış bir şey göstermekten iyi.
    final personAsync = ref.watch(personDetailProvider(widget.personId));
    if (personAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final person = personAsync.asData?.value;

    if (person == null) {
      // Kimlik tanınmıyor (eski bağlantı, elle yazılmış rota). Çökmek yerine
      // ne olduğunu söylüyoruz.
      return Scaffold(
        appBar: AppBar(),
        body: AppEmptyState(
          icon: AppIcons.searchEmpty,
          title: l10n.errorNotFound,
        ),
      );
    }

    final collections = PersonDetailPreviewData.collectionsOf(person.id);
    final rituals = PersonDetailPreviewData.ritualsOf(person.id);

    return Scaffold(
      appBar: AppBar(
        // BAŞLIK YOK: kişinin adı hemen altta, büyük ve kalın duruyor.
        // AppBar'a da yazmak aynı bilgiyi iki kez göstermek olurdu.
        actions: [
          IconButton(
            key: _actionsKey,
            onPressed: () => _openActions(person),
            icon: const Icon(AppIcons.more),
            tooltip: l10n.personActions,
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
          PersonDetailHeader(person: person),
          const SizedBox(height: AppSpacing.xl),

          _SectionTitle(l10n.personDetailCollections),
          const SizedBox(height: AppSpacing.sm),
          if (collections.isEmpty)
            _EmptyNote(l10n.personDetailNoCollections)
          else
            IzDividedCard(
              // Çizgi KAPAĞIN hizasından başlıyor: altından geçen bir çizgi
              // görseli kesik gösteriyordu (kişi listesinde de aynı karar).
              dividerInset:
                  PersonCollectionRow.kInset + PersonCollectionRow.kCoverWidth,
              rows: [
                for (final collection in collections)
                  PersonCollectionRow(
                    collection: collection,
                    onTap: () => _openCollections(person),
                  ),
              ],
            ),

          const SizedBox(height: AppSpacing.xl),

          _SectionTitle(l10n.personDetailRituals),
          const SizedBox(height: AppSpacing.sm),
          if (rituals.isEmpty)
            _EmptyNote(l10n.personDetailNoRituals)
          else
            IzDividedCard(
              dividerInset: PersonRitualRow.kInset,
              rows: [
                for (final ritual in rituals) PersonRitualRow(ritual: ritual),
              ],
            ),
        ],
      ),

      // Anı detayıyla AYNI karar: detay ekranı bir sekmenin içinde değil ama
      // alt çubuk yine duruyor — kullanıcı bir kişiye bakarken uygulamanın
      // dışına düşmüş gibi hissetmemeli (anı detayında da bunu istedi).
      bottomNavigationBar: IzBottomNav(
        destinations: IzBottomNav.appTabs(l10n),
        // Hiçbir sekmede değil: birini vurgulamak yanlış bir yer bildirirdi.
        currentIndex: IzBottomNav.noSelection,
        // `go`: sekmeye dokunmak detaydan ÇIKMAK demek.
        onSelect: (index) => context.go(AppRoute.tabs[index].path),
        addIcon: AppIcons.add,
        addLabel: l10n.navAdd,
        // Bir kişiye bakarken "+" büyük olasılıkla "onunla bir anı" demek;
        // halka menüyü ancak kabuk kurabildiği için doğrudan yeni anıya
        // gidiyoruz.
        onAdd: () => showAppAddMenu(context),
      ),
    );
  }

  /// "Hayatım"ın koleksiyonlar sekmesini BU KİŞİYE süzülmüş açar.
  ///
  /// TÜM koleksiyonlar değil: kullanıcı buraya bir kişinin sayfasından geldi
  /// ve o bağlamı kaybetmemeli. Süzme rotada taşınıyor
  /// (`?tab=collections&person=…`) ki geri gelip yenilendiğinde de sürsün.
  void _openCollections(Person person) => context.goNamed(
    AppRoute.myLife.name,
    queryParameters: {'tab': MyLifeTab.collections.name, 'person': person.id},
  );

  /// Üç noktanın altında açılan menü: düzenle ve sil.
  ///
  /// AYRI BİR YAPI YAZMADIK. `IzPopoverMenu` zaten bu işi yapıyor ("Hayatım"
  /// ekranındaki anı satırında) ve yıkıcı eylemi sona alıp kırmızıya boyama
  /// kuralını taşıyor. İkinci bir menü bileşeni iki ayrı görünüm demekti.
  Future<void> _openActions(Person person) async {
    final l10n = context.l10n;
    final box = _actionsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    await showIzPopoverMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      actions: [
        (
          icon: AppIcons.edit,
          label: l10n.personEditAction,
          isDestructive: false,
          // Form kimlik alınca dolu açılıyor (bkz. `PersonEditorView`).
          // `push`, `go` DEĞİL: düzenlemeyi kapatan kullanıcı baktığı kişiye
          // geri dönmeli.
          onPressed: () => context.pushNamed(
            AppRoute.personEdit.name,
            pathParameters: {'id': person.id},
          ),
        ),
        // Yıkıcı eylem SONDA: parmak listede aşağı inerken yanlışlıkla ona
        // denk gelmesin.
        (
          icon: AppIcons.delete,
          label: l10n.personDeleteAction,
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
      title: l10n.personDeleteTitle,
      // FR-063 — kişiyi silmek ANILARI SİLMİYOR. Kullanıcı bunu onaydan önce
      // bilmeli; yoksa silmeye cesaret edemez ya da yanlış şeyi bekler.
      message: l10n.personDeleteMessage,
      confirmLabel: l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final result = await ref
        .read(personRepositoryProvider)
        .softDelete(widget.personId);
    if (!mounted) return;

    switch (result) {
      case Ok():
        // Silinen kişinin detay sayfasında kalmanın anlamı yok; listeye
        // dönüyoruz ve kişi orada da yok.
        context.pop();
      case Err(:final failure):
        // Silinemedi: sayfada kalıyoruz ki kullanıcı tekrar deneyebilsin.
        context.showSnack(failure.localizedMessage(l10n));
    }
  }
}

/// Bölüm başlığı — "Koleksiyonlarımız", "Ritüellerimiz".
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.text.titleMedium?.copyWith(
      color: context.colors.onSurface,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// Bölüm boşken tek satırlık açıklama.
///
/// Bölümü tamamen gizlemek de bir seçenekti; göstermeyi seçtik çünkü başlığın
/// varlığı "burada böyle bir şey olabilir" diyor — kullanıcı ortak bir
/// koleksiyon oluşturabileceğini böyle öğreniyor.
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
