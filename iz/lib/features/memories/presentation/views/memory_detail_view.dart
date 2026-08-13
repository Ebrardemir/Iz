/// Anı detay ekranı.
///
/// YERLEŞİM (referans tasarım):
///   ┌──────────────────────────────┐
///   │ ←      Anı Detay             │  üç nokta YOK
///   │ İlk İzmir Tatilimiz       ♡  │  serif başlık + favori
///   │ ┌──────────────────────────┐ │
///   │ │       kapak 16:9         │ │  ilk fotoğraf, büyük
///   │ └──────────────────────────┘ │
///   │ 📅 12 Mayıs 2024  📍 Kordon  │  tek satır meta
///   │ Kordon'da gün batımı ve…  ⌄  │  not: 2 satır + aç/kapa
///   │ [foto] [foto] [foto]         │  bütün kareler
///   │ ┌──────────────────────────┐ │
///   │ │ 👥 Kişiler  Annem…  ◍◍◍ │ │  ilişki kartı
///   │ │ 🏷 Kategori Seyahat      │ │
///   │ └──────────────────────────┘ │
///   │ [Paylaş][Kolaj][Düzenle]     │
///   └──────────────────────────────┘
///
/// İLİŞKİ KARTI FORMLA AYNI BİLEŞEN ([MemoryInfoCard]). Kullanıcı forma
/// hangi sırayla girdiyse detayda aynı sırayla, aynı hizada, aynı ikonlarla
/// görüyor. İki ayrı kart yazmak bu eşleşmeyi ilk değişiklikte bozardı.
///
/// FR-020: "Anı detay ekranında ilgili kişi, koleksiyon, ritüel ve konuma
/// geçiş bağlantıları bulunmalıdır." Kişilere avatarlar, koleksiyon/seri/konum
/// satırın kendisi üzerinden gidiyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_add_menu.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/extensions/date_x.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/l10n/locale_case.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/categories/domain/entities/memory_category.dart';
import 'package:iz/features/categories/presentation/category_l10n.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/presentation/view_models/memory_detail_view_model.dart';
import 'package:iz/features/memories/presentation/widgets/expandable_note.dart';
import 'package:iz/features/memories/presentation/widgets/memory_info_card.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/shared/widgets/app_empty_state.dart';
import 'package:iz/shared/widgets/async_value_view.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';
import 'package:iz/shared/widgets/media_thumbnail.dart';

class MemoryDetailView extends ConsumerWidget {
  const MemoryDetailView({
    required this.memoryId,
    this.previewDetail,
    super.key,
  });

  final String memoryId;

  /// TASARIM ÖNİZLEMESİNDEN GELEN HAZIR KAYIT.
  ///
  /// ⚠️ GEÇİCİ. Ana sayfa ve "Hayatım" henüz hiçbir veri kaynağına bağlı
  /// değil; gösterdikleri anılar `*_preview_data.dart` dosyalarındaki sahte
  /// kayıtlar. O kartlara dokunulduğunda kimlikleri veritabanında bulunmadığı
  /// için ekran "Bulunamadı" derdi — kullanıcı bunu bir hata sanardı.
  ///
  /// Bu yüzden o ekranlar kaydı yanında getiriyor (`extra` ile; aynı desen
  /// fotoğraf seçimi → form geçişinde de var). Dolu geldiğinde depoya hiç
  /// sorulmuyor.
  ///
  /// Veri bağlandığında burası ve `app_router.dart`taki `extra` okuması
  /// silinecek; ekranın geri kalanı değişmeyecek.
  final MemoryDetail? previewDetail;

  /// Kapak görselinin oranı.
  ///
  /// Sabit YÜKSEKLİK değil oran: aynı ekran 390 ve 430 piksellik telefonlarda
  /// da, tablette de aynı görünmeli. Referanstaki kapak ~1.75:1; en yakın
  /// standart oran 16:9.
  static const double kCoverAspectRatio = 16 / 9;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final preview = previewDetail;

    return Scaffold(
      // APPBAR'DA EYLEM YOK.
      //
      // Referansta bir "…" duruyordu, biz de silmeyi oradan çıkarıp açık bir
      // çöp ikonuna almıştık. İkisi de gitti: bu ekranın işi anıyı GÖSTERMEK
      // ve alttaki şerit (Paylaş · Kolaj · Düzenle) eylemlerin adresi. Sağ
      // üstte tek başına duran bir çöp ikonu, kullanıcının en çok yaptığı
      // şeyin (okumak) yanında en yıkıcı eylemi bekletiyordu.
      appBar: AppBar(centerTitle: true, title: Text(l10n.memoryDetailTitle)),

      // Önizleme kaydı geldiyse depoya HİÇ SORMUYORUZ (`ref.watch` bile
      // çağrılmıyor): beklenecek bir yükleme, düşecek bir hata yok.
      body: preview != null
          ? _DetailBody(
              detail: preview,
              onToggleFavorite: () => _comingSoon(context),
            )
          : _RepositoryBody(
              memoryId: memoryId,
              onToggleFavorite: () => _toggleFavorite(context, ref),
            ),

      // ALT ÇUBUK — bu ekran kabuğun DIŞINDA olduğu hâlde.
      //
      // Rota `_rootNavigatorKey` altında, yani tam ekran açılıyor ve
      // `AppShell`in çubuğu burada yok. Rotayı kabuğun içine taşımak
      // çözmüyordu: `StatefulShellRoute` her rotayı bir SEKMEYE bağlıyor ve
      // detay hangi sekmeye konsa öteki sekmelerden gidildiğinde alt çubuk
      // yanlış sekmeyi vurguluyor, geri tuşu da yanlış yere dönüyordu.
      //
      // Bunun yerine çubuğu burada kuruyoruz. Sekme listesi kopyalanmıyor
      // (`IzBottomNav.appTabs`), sıra da kopyalanmıyor (`AppRoute.tabs`).
      bottomNavigationBar: IzBottomNav(
        destinations: IzBottomNav.appTabs(l10n),
        // Kullanıcı hiçbir sekmede değil, bir anıya bakıyor: birini
        // vurgulamak "buradasın" diye yanlış bir şey söylerdi.
        currentIndex: IzBottomNav.noSelection,
        // `go`, `push` DEĞİL: sekmeye dokunmak detaydan ÇIKMAK demek.
        // `push` olsaydı sekme detayın üstüne binerdi ve geri tuşu
        // kullanıcıyı ana sayfadan anı detayına düşürürdü.
        onSelect: (index) => context.go(AppRoute.tabs[index].path),
        addIcon: AppIcons.add,
        addLabel: l10n.navAdd,
        // Kabukta bu düğme halka menü açıyor; menünün içeriğini ancak her
        // şeyi bilen katman (`app/`) kurabiliyor ve bu ekran onu göremiyor.
        // Doğrudan yeni anıya gidiyoruz: bir anıya bakarken "+" zaten büyük
        // olasılıkla "yeni anı" demek.
        onAdd: () => showAppAddMenu(context),
      ),
    );
  }

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(memoryDetailProvider(memoryId).notifier)
        .toggleFavorite();
    if (!context.mounted) return;

    // Başarıda hiçbir bildirim YOK: kalbin dolması zaten geri bildirim.
    // Yalnızca başarısızlık haber değeri taşıyor.
    result.fold(
      onOk: (_) {},
      onErr: (failure) =>
          context.showSnack(failure.localizedMessage(context.l10n)),
    );
  }
}

/// Depodan okuyan gövde.
///
/// AYRI WIDGET çünkü `ref.watch` yalnızca burada çağrılıyor: önizleme kaydıyla
/// açıldığında depoya hiç abone olmuyoruz. Aynı `build` içinde `watch` etseydik
/// önizlemede de gereksiz bir sorgu başlardı.
class _RepositoryBody extends ConsumerWidget {
  const _RepositoryBody({
    required this.memoryId,
    required this.onToggleFavorite,
  });

  final String memoryId;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return AsyncValueView<MemoryDetail?>(
      value: ref.watch(memoryDetailProvider(memoryId)),
      onRetry: () => ref.invalidate(memoryDetailProvider(memoryId)),
      isEmpty: (detail) => detail == null,
      emptyBuilder: () =>
          AppEmptyState(icon: AppIcons.searchEmpty, title: l10n.errorNotFound),
      data: (detail) =>
          _DetailBody(detail: detail!, onToggleFavorite: onToggleFavorite),
    );
  }
}

/// Koleksiyon / seri / konum / kategori detay ekranları HENÜZ YOK.
///
/// Rotaları `AppRoute` içinde duruyor ama `app_router.dart`ta karşılıkları
/// tanımlı değil; `pushNamed` çağırmak kullanıcıyı "sayfa bulunamadı"
/// ekranına düşürürdü. Boş bir `onTap: () {}` ise daha kötüsü: satır
/// tıklanabilir görünür, dokunulur, hiçbir şey olmaz.
///
/// Uygulamanın geri kalanıyla aynı yolu izliyoruz (bkz. home_view.dart,
/// my_life_view.dart, memory_editor_view.dart): "yakında" diyoruz.
void _comingSoon(BuildContext context) =>
    context.showSnack(context.l10n.screenComingSoonMessage);

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.onToggleFavorite});

  final MemoryDetail detail;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final memory = detail.memory;
    final l10n = context.l10n;
    final relations = _relationRows(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        _TitleRow(
          title: memory.displayTitle(l10n.memoryNew),
          isFavorite: memory.isFavorite,
          onToggleFavorite: onToggleFavorite,
        ),

        // ARADA AYRI BİR BOŞLUK YOK — bilerek.
        //
        // Favori düğmesi başlıktan yüksek (dokunma hedefi 48, başlık satırı
        // 34) ve satırı kendisi şişiriyor; o fazlalık zaten ~14 piksellik bir
        // nefes veriyor. Üstüne bir de `SizedBox` koyunca başlıkla kapak
        // arasında kocaman bir delik açılıyordu.

        // --- Kapak: İLK fotoğraf, büyük -------------------------------------
        //
        // Neden ilki? Kullanıcı fotoğraf seçim adımında sıralamayı kendisi
        // belirliyor ve `MemoryMedia.sortOrder` bunu koruyor. Kapağı ayrıca
        // seçtirmek (FR-018) sonra gelecek; o zaman `memory.coverMedia`
        // doluysa o kazanacak — aşağıdaki sıra bunu şimdiden yapıyor.
        if (detail.media.isNotEmpty)
          _Cover(media: memory.coverMedia ?? detail.media.first),

        // BR-007 — kayıp medya uyarısı
        if (detail.missingMediaCount > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _WarningBanner(
            icon: AppIcons.mediaMissing,
            title: l10n.mediaMissingTitle,
            message: l10n.mediaMissingMessage,
          ),
        ],

        const SizedBox(height: AppSpacing.md),

        // --- Tarih + konum: TEK satır ---------------------------------------
        _MetaRow(
          // DİLİ AÇIKÇA GEÇİYORUZ. Boş bırakılırsa `AppDateFormats`
          // `Intl.defaultLocale` genel değişkenine düşer; o da uygulama
          // açılışında ayarlanıyor ama ekranı tek başına kurunca (test,
          // önizleme) ayarlanmamış oluyor ve ay adı İngilizce çıkıyor —
          // "12 Mayıs 2024" yerine "May 12, 2024". Aynı tuzağa
          // `month_navigator.dart`ta da düşmüştük.
          date: AppDateFormats.long(
            memory.occurredAt,
            locale: Localizations.localeOf(context).toLanguageTag(),
          ),
          location: detail.location?.label ?? memory.locationLabel,
          onLocationTap: () => _comingSoon(context),
        ),

        // --- Not: zorunlu değil ---------------------------------------------
        if (memory.note case final note? when note.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ExpandableNote(note: note.trim()),
        ],

        // --- Bütün kareler ---------------------------------------------------
        //
        // Kapak burada TEKRAR görünüyor ve bu bilinçli: şerit "bu anıda şu
        // kareler var" diyor, kapak ise "bu anı böyle görünüyor" diyor. Şeritten
        // kapağı çıkarmak, üç fotoğraf seçen kullanıcıya ikisini gösterirdi.
        if (detail.media.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          _MediaStrip(media: detail.media),
        ],

        // --- İlişkiler: yalnızca DOLU olanlar -------------------------------
        //
        // Boş satır göstermiyoruz. Detay ekranı bir form değil, bir kayıt:
        // "Koleksiyon —" yazan bir satır bilgi taşımıyor, sadece eksiklik
        // duyuruyor. Hiçbiri yoksa kart hiç çıkmıyor.
        if (relations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          MemoryInfoCard(rows: relations),
        ],

        const SizedBox(height: AppSpacing.lg),

        _DetailActions(
          onShare: () => _comingSoon(context),
          onCollage: () => _comingSoon(context),
          onEdit: () => context.pushNamed(
            AppRoute.memoryEdit.name,
            pathParameters: {'id': detail.id},
          ),
        ),
      ],
    );
  }

  /// Dolu ilişkileri kart satırlarına çevirir.
  List<Widget> _relationRows(BuildContext context) {
    final l10n = context.l10n;
    final memory = detail.memory;

    return [
      if (detail.people.isNotEmpty)
        MemoryInfoRow(
          icon: AppIcons.people,
          label: l10n.relationPeople,
          // Avatarlar HEM süs HEM geçiş yolu: her biri o kişinin ekranına
          // gidiyor (FR-020). Satırın tamamını tek bir kişiye bağlamak
          // yanlış olurdu — satırda birden fazla kişi var.
          trailing: _AvatarStack(people: detail.people),
          child: MemoryInfoValue(
            value: detail.people.map((p) => p.name).join(', '),
          ),
        ),

      if (_categoryName(memory.categoryId, l10n) case final name?)
        MemoryInfoRow(
          icon: AppIcons.fallbackCategory,
          label: l10n.memoryFieldCategory,
          child: MemoryInfoValue(value: name),
        ),

      if (detail.collections.isNotEmpty)
        MemoryInfoRow(
          icon: AppIcons.collection,
          label: l10n.memoryFieldCollection,
          onTap: () => _comingSoon(context),
          child: MemoryInfoValue(
            value: detail.collections.map((c) => c.title).join(', '),
          ),
        ),

      if (detail.ritual case final ritual?)
        MemoryInfoRow(
          icon: AppIcons.forKey(ritual.iconKey),
          label: l10n.memoryFieldSeries,
          onTap: () => _comingSoon(context),
          child: MemoryInfoValue(
            // Yıl varsa ekliyoruz: "Yaz Tatilleri · 2024". Aynı serinin
            // birden çok yılı olabiliyor (BR-012) ve hangisine baktığı
            // kullanıcı için bilgi.
            value: detail.ritualYear == null
                ? ritual.title
                : '${ritual.title} · ${detail.ritualYear}',
          ),
        ),
    ];
  }

  /// Sistem kategorisinin çevrilmiş adı.
  ///
  /// Kullanıcının kendi açtığı kategoriler burada `null` dönüyor: adlarını
  /// okuyacak katman (`CategoryDao`) henüz yok ve kimliği ekranda göstermek
  /// bilgi değil gürültü olurdu. O hat kurulunca burası repository'den
  /// gelen adı kullanacak.
  static String? _categoryName(String? categoryId, AppL10n l10n) {
    if (categoryId == null) return null;

    final category = SystemCategory.values
        .where((c) => c.id == categoryId)
        .firstOrNull;
    if (category == null) return null;

    return systemCategoryName(category.nameKey, l10n);
  }
}

/// Anı başlığının punto ve renk ayarı.
///
/// Ayrı sabitler: ikisi de "ne kadar" sorusunun cevabı ve tek yerde durunca
/// ileride birlikte ayarlanabiliyorlar.
const double _kTitleFontSize = 22;
const double _kTitleGreenBlend = 0.4;

/// Başlık + favori.
class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final String title;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            // POPPINS, Cormorant DEĞİL.
            //
            // Serif yazı markanın duygusal sesi ("Bu anıdan geriye hangi
            // kareler kalsın?") ama buradaki metin kullanıcının kendi yazdığı
            // bir başlık, yani VERİ. Süslü bir yazıyla gösterince altındaki
            // notla aynı aileden olmuyordu ve sayfa iki sesli okunuyordu.
            //
            // 26 DEĞİL 22: ekran başlıklarının ("Hayatım", "Kişilerim") ölçüsü
            // buraya fazla geliyordu — orada başlık sayfanın ADI, burada
            // hemen altındaki kapak fotoğrafıyla yer paylaşıyor.
            //
            // RENK: koyu mürekkeple marka yeşilinin arası (%40 yeşil).
            // Tam yeşil, ekran başlıklarıyla aynı ağırlığı verirdi; bu metin
            // ise kullanıcının kendi sözü. Hafif yeşil, sayfayı markaya
            // bağlarken "bu bir etiket değil, senin başlığın" demeyi
            // sürdürüyor. Karşıtlık iki uçtan da yüksek (iki renk de
            // zeminden AA üstünde), aradaki karışım da öyle.
            style: context.textStyles.screenTitle.copyWith(
              fontSize: _kTitleFontSize,
              height: 30 / _kTitleFontSize,
              color: Color.lerp(
                context.colors.onSurface,
                context.colors.primary,
                _kTitleGreenBlend,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),

        // FAVORİ AppBar'DA DEĞİL, BAŞLIĞIN YANINDA.
        //
        // Kalp bir ekran eylemi değil, bu anıya ait bir işaret; adının
        // yanında durması onu neye vurduğunu belirsiz bırakmıyor.
        //
        // Lucide çizgi setidir; dolu/boş kalp ikilisi yok. Durumu ÜÇ
        // sinyalle veriyoruz: dolu zemin (şekil), renk ve ekran okuyucu
        // etiketi — `memory_card.dart` ile aynı desen. NFR-031 gereği renk
        // tek başına bilgi taşımamalı.
        IconButton(
          onPressed: onToggleFavorite,
          icon: const Icon(AppIcons.favorite),
          color: isFavorite
              ? context.colors.onSecondaryContainer
              : context.colors.onSurface,
          style: isFavorite
              ? IconButton.styleFrom(
                  backgroundColor: context.colors.secondaryContainer,
                )
              : null,
          tooltip: isFavorite ? l10n.memoryUnfavorite : l10n.memoryFavorite,
        ),
      ],
    );
  }
}

/// Kapak görseli.
class _Cover extends StatelessWidget {
  const _Cover({required this.media});

  final MediaItem media;

  @override
  Widget build(BuildContext context) {
    // `LayoutBuilder`: `MediaThumbnail` somut ölçü istiyor, biz oranı
    // korumak istiyoruz. Genişliği ebeveynden alıp yüksekliği hesaplıyoruz.
    return LayoutBuilder(
      builder: (context, constraints) => MediaThumbnail(
        media: media,
        width: constraints.maxWidth,
        height: constraints.maxWidth / MemoryDetailView.kCoverAspectRatio,
        borderRadius: AppRadius.lg,
      ),
    );
  }
}

/// Tarih ve konum — tek satır.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.date,
    required this.location,
    required this.onLocationTap,
  });

  final String date;
  final String? location;
  final VoidCallback onLocationTap;

  @override
  Widget build(BuildContext context) {
    final place = location;

    return Wrap(
      // `Wrap`, `Row` DEĞİL: uzun bir konum adı ("Ürgüp, Nevşehir,
      // Kapadokya") büyük yazı ölçeğinde tarihle aynı satıra sığmıyor.
      // `Row` orada taşma çizgileri gösterirdi; `Wrap` alt satıra iniyor.
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        _MetaItem(icon: AppIcons.date, label: date),
        if (place != null && place.isNotEmpty)
          // FR-020 — konuma geçiş bağlantısı.
          _MetaItem(
            icon: AppIcons.location,
            label: place,
            onTap: onLocationTap,
          ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIconSize.sm, color: colors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: context.text.bodySmall?.copyWith(color: colors.onSurface),
        ),
      ],
    );

    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// Anının bütün kareleri — satırı dolduran eşit kutular.
///
/// Anı formundaki şeritle AYNI ölçü mantığı: `Wrap` + hesaplanmış kenar.
/// Kullanıcı fotoğraflarını nasıl seçtiyse burada da öyle görüyor.
class _MediaStrip extends StatelessWidget {
  const _MediaStrip({required this.media});

  final List<MediaItem> media;

  static const double _kGap = AppSpacing.sm;
  static const int _kPerRow = 3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = (constraints.maxWidth - _kGap * (_kPerRow - 1)) / _kPerRow;

        return Wrap(
          spacing: _kGap,
          runSpacing: _kGap,
          children: [
            for (final item in media) MediaThumbnail(media: item, size: side),
          ],
        );
      },
    );
  }
}

/// Kişiler satırının sağındaki üst üste binmiş yuvarlaklar.
///
/// KİŞİ FOTOĞRAFI YOK, baş harf var: `Person` bir avatar taşımıyor ve
/// taşıyacak katman da (`PersonDao`) yazılmadı. Baş harf, gerçek fotoğraf
/// geldiğinde de kullanılacak bir yer tutucudur (kişinin fotoğrafı olmayabilir)
/// — yani atılacak bir geçici çözüm değil.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.people});

  final List<Person> people;

  /// Yuvarlağın çapı.
  ///
  /// 28'den 24'e indirildi: üç avatar + isim listesi ("Annem, Babam, Elif")
  /// aynı satıra sığmıyordu ve isim ikinci satıra düşüyordu. Avatarlar
  /// satırın ASIL bilgisi değil, isimler öyle — daralması gereken taraf bu.
  static const double _kSize = 24;

  /// Yuvarlaklar birbirinin üstüne biniyor; bu kadarı görünüyor.
  static const double _kStep = 16;

  /// En çok kaç yuvarlak? Fazlası "+2" olarak toplanıyor.
  static const int _kMaxVisible = 3;

  @override
  Widget build(BuildContext context) {
    final visible = people.take(_kMaxVisible).toList();
    final overflow = people.length - visible.length;
    final count = visible.length + (overflow > 0 ? 1 : 0);

    return SizedBox(
      width: _kSize + _kStep * (count - 1),
      height: _kSize,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: _kStep * i,
              child: _Avatar(
                label: _initial(
                  visible[i].name,
                  Localizations.localeOf(context),
                ),
                // FR-020 — kişi detayına geçiş.
                onTap: () => context.pushNamed(
                  AppRoute.personDetail.name,
                  pathParameters: {'id': visible[i].id},
                ),
                semanticLabel: visible[i].name,
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: _kStep * visible.length,
              child: _Avatar(label: '+$overflow'),
            ),
        ],
      ),
    );
  }

  /// Adın ilk harfi, dile duyarlı büyütmeyle.
  ///
  /// `toUpperCase()` DEĞİL: Türkçede "i" harfinin büyüğü "İ"dir, varsayılan
  /// dönüşüm "I" verir. "İrem" adının baş harfi "I" görünürdü.
  static String _initial(String name, Locale locale) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return localeUpperCase(trimmed.characters.first, locale);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, this.onTap, this.semanticLabel});

  final String label;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final circle = Container(
      width: _AvatarStack._kSize,
      height: _AvatarStack._kSize,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        shape: BoxShape.circle,
        // Kenarlık, üst üste binen yuvarlakları birbirinden ayırıyor —
        // olmadan tek bir bulanık lekeye dönüşüyorlardı.
        border: Border.all(color: colors.surfaceContainerLow, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(
          color: colors.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (onTap == null) return circle;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(onTap: onTap, child: circle),
    );
  }
}

/// Alt eylem şeridi: Paylaş · Kolaj Oluştur · Düzenle.
class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.onShare,
    required this.onCollage,
    required this.onEdit,
  });

  final VoidCallback onShare;
  final VoidCallback onCollage;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: AppIcons.share,
            label: l10n.commonShare,
            onTap: onShare,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionTile(
            icon: AppIcons.collage,
            label: l10n.memoryActionCollage,
            onTap: onCollage,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionTile(
            icon: AppIcons.edit,
            label: l10n.commonEdit,
            onTap: onEdit,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: AppRadius.card,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.card,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.card,
              border: Border.all(color: colors.outlineVariant),
            ),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              children: [
                Icon(icon, size: AppIconSize.lg, color: colors.onSurface),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = context.semanticColors.warning;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(color: color),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(message, style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
