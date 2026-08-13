/// Kişiler sekmesi — FR-060..FR-065.
///
/// İKİ HÂL, TEK EKRAN:
///   • kişi VARSA  → arama + liste (`_PeopleList`)
///   • kişi YOKSA  → illüstrasyonlu davet (`_EmptyState`)
/// Boş durum, dolu listeden daha çok iş yapıyor: ne olduğunu anlatıyor ve ilk
/// adımı atmaya davet ediyor. O yüzden bir "yakında" yer tutucusu değil, tam
/// tasarlanmış bir hâl.
///
/// ⚠️ VERİ KAYNAĞI YOK. `PersonDao`/`PersonRepository` yazılmadı; liste
/// `PeoplePreviewData`dan geliyor. Veri bağlandığında iki şey değişecek
/// ([hasPeople] bir `ref.watch` olacak ve liste kaynağı repository'ye
/// dönecek); ekranın geri kalanı aynı kalacak.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_add_menu.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/people/presentation/person_l10n.dart';
import 'package:iz/features/people/presentation/views/people_preview_data.dart';
import 'package:iz/features/people/presentation/widgets/people_empty_illustration.dart';
import 'package:iz/features/people/presentation/widgets/people_search_field.dart';
import 'package:iz/features/people/presentation/widgets/person_row.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';
import 'package:iz/shared/widgets/iz_divided_card.dart';
import 'package:iz/shared/widgets/iz_screen_header.dart';

class PeopleView extends ConsumerWidget {
  const PeopleView({this.hasPeople = true, super.key});

  /// Kullanıcının kaydedilmiş kişisi var mı?
  ///
  /// ⚠️ GEÇİCİ. Veri kaynağı yok; testler iki hâli de açıkça kurabilsin diye
  /// parametre — yoksa boş hâli sınamak imkânsız olurdu (aynı desen
  /// `HomeView.hasMemories`ta da var).
  final bool hasPeople;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        // ÜST GÜVENLİ ALANI ŞERİT KENDİ YÖNETİYOR, alt güvenli alanı da
        // `IzBottomNav` kendi içinde ekliyor. `SafeArea` burada ikisini de
        // açık bıraksaydı paylar İKİ KEZ eklenirdi ve başlık tasarımdakinden
        // ~50 piksel aşağıda kalırdı — `my_life_view.dart` aynı tuzağı bir
        // kez yaşayıp not düşmüş, buraya yazarken bir kez daha düştük.
        //
        // Sol/sağ AÇIK kalıyor: çentikli bir telefon yatay tutulduğunda
        // içerik çentiğin altına girmesin.
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Başlık şeridi "Hayatım"la AYNI bileşen: aynı kenar marjı, aynı
            // durum çubuğu payı, aynı yazı ölçüsü (bkz. `IzScreenHeader`).
            IzScreenHeader(
              title: l10n.peopleTitle,
              subtitle: l10n.peopleSubtitle,
              // Referansta "+ Kişi Ekle" — ikon değil, ikon + METİN.
              //
              // Yalnızca DOLU listede: boş durumda aynı eylem ortada büyük bir
              // düğme olarak duruyor ve ikisi birden olsa hangisine basacağı
              // belirsiz kalırdı.
              trailing: hasPeople
                  ? TextButton.icon(
                      onPressed: () => _openNewPerson(context),
                      icon: const Icon(AppIcons.add, size: AppIconSize.md),
                      label: Text(l10n.peopleAddAction),
                    )
                  : null,
            ),

            Expanded(
              child: hasPeople ? const _PeopleList() : const _EmptyState(),
            ),
          ],
        ),
      ),

      // ALT ÇUBUK — bu ekran kabuğun DIŞINDA olduğu hâlde.
      //
      // Kişiler alt çubukta bir sekme DEĞİL: halka menüden ve ilişki
      // satırlarından açılıyor, yani tam ekran bir sayfa. Ama referansta çubuk
      // duruyor ve haklı: kullanıcı buraya menüden geldi, çıkışı görebilmeli.
      //
      // ⚠️ AYNI BLOK `memory_detail_view.dart`ta da var (o da kabuk dışında).
      // İki kopya bilinçli: üçüncü ekran gelirse ortak bir yere çıkarılmalı.
      // Şimdilik kopyalanan tek şey ÇAĞRI; sekme listesi
      // (`IzBottomNav.appTabs`) ve sıra (`AppRoute.tabs`) tek kaynakta.
      bottomNavigationBar: IzBottomNav(
        destinations: IzBottomNav.appTabs(l10n),
        // Kullanıcı hiçbir sekmede değil; birini vurgulamak "buradasın" diye
        // yanlış bir şey söylerdi.
        currentIndex: IzBottomNav.noSelection,
        // `go`, `push` DEĞİL: sekmeye dokunmak bu sayfadan ÇIKMAK demek.
        onSelect: (index) => context.go(AppRoute.tabs[index].path),
        addIcon: AppIcons.add,
        addLabel: l10n.navAdd,
        // Kabukta bu düğme halka menü açıyor; menünün içeriğini ancak her şeyi
        // bilen katman (`app/`) kurabiliyor ve bu ekran onu göremiyor.
        onAdd: () => showAppAddMenu(context),
      ),
    );
  }
}

/// Yeni kişi ekranını açar.
///
/// İKİ YERDEN çağrılıyor: dolu listede başlığın sağındaki "+ Kişi Ekle" ve boş
/// durumdaki büyük düğme. Aynı ekrana gittikleri için tek yerde duruyor.
void _openNewPerson(BuildContext context) =>
    context.pushNamed(AppRoute.personNew.name);

/// Arama + kişi listesi.
class _PeopleList extends StatefulWidget {
  const _PeopleList();

  @override
  State<_PeopleList> createState() => _PeopleListState();
}

class _PeopleListState extends State<_PeopleList> {
  final _searchController = TextEditingController();

  /// Kullanıcının yazdığı arama metni.
  ///
  /// Widget'ta tutuluyor, ViewModel'de değil: bu bir GÖRÜNÜM durumu, kaydı
  /// olan bir iş verisi değil. Ekran kapanınca kaybolması doğru.
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Süzme SAF bir fonksiyonda (`filterPeople`); ilişki adı dile bağlı
    // olduğu için oraya geri çağırma olarak geçiyor.
    final people = filterPeople(
      PeoplePreviewData.people,
      query: _query,
      // Aramada da EKRANDA GÖRÜNEN metin aranıyor: kullanıcı "Annem" yazıp
      // bulamıyorsa arama bozuktur.
      relationNameOf: (person) => relationDisplay(person, l10n),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        IzScreenHeader.kPageInset,
        AppSpacing.md,
        IzScreenHeader.kPageInset,
        AppSpacing.xxl,
      ),
      children: [
        PeopleSearchField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: AppSpacing.md),

        if (people.isEmpty)
          _SearchEmpty(query: _query)
        else
          IzDividedCard(
            // Çizgi AVATARIN hizasından başlıyor, kartın kenarından değil:
            // avatarın altından geçen bir çizgi onu kesik gösteriyordu.
            dividerInset: PersonRow.kInset + PersonRow.kAvatarSize,
            rows: [
              for (final person in people)
                PersonRow(
                  person: person,
                  onTap: () => context.pushNamed(
                    AppRoute.personDetail.name,
                    pathParameters: {'id': person.id},
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Arama hiçbir şey bulamadığında.
class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(
            AppIcons.searchEmpty,
            size: AppIconSize.xl,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.peopleSearchEmptyTitle,
            style: context.text.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            // ARANAN METNİ GERİ GÖSTERİYORUZ: kullanıcı ne yazdığını görüyor
            // ve yazım hatasını fark ediyor. Kuru bir "sonuç yok" bunu
            // yapmıyor.
            l10n.peopleSearchEmptyMessage(query),
            style: context.text.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// "Burası onlarla dolacak."
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  /// Metin bloğunun genişliği.
  ///
  /// Sayfa marjına kadar yaymıyoruz: açıklama üç satıra bölünsün ve düğme
  /// ekranın tamamını kaplamasın. Referansta da başlık, açıklama ve düğme
  /// AYNI ölçüyü paylaşıyor — ortalanmış tek bir sütun gibi okunuyor.
  static const double kContentWidth = 300;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return SingleChildScrollView(
      // Küçük ekranda ve büyük yazı ölçeğinde içerik sığmayabilir; kırpmak
      // yerine kaydırılsın (NFR-032).
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: PeopleEmptyIllustration()),
              const SizedBox(height: AppSpacing.lg),

              Text(
                l10n.peopleEmptyTitle,
                // POPPINS, serif DEĞİL.
                //
                // İllüstrasyonun hemen altındaki bu satır bir başlık değil,
                // bir DURUM bildirimi. Serif onu markanın sesiyle
                // söyletiyordu ve altındaki açıklamayla aynı aileden
                // görünmüyordu. (Ekranın adı — "Kişilerim" — ayrı bir stil.)
                style: context.text.titleLarge?.copyWith(height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                l10n.peopleEmptyMessage,
                style: context.text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              // Açıklama ile düğme arası, başlık–açıklama arasından GENİŞ:
              // ilk ikisi "durum nedir"i anlatan tek blok, düğme ise ayrı bir
              // şey — kullanıcının atacağı adım.
              const SizedBox(height: AppSpacing.xl),

              FilledButton(
                onPressed: () => _openNewPerson(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(l10n.peopleEmptyAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
