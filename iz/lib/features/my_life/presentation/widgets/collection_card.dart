/// KOLEKSİYONLAR sekmesindeki katlanır kart.
///
/// İKİ HÂLİ VAR ve ikisi de tasarlandı:
///   kapalı → 86 yüksek. Solda küçük kapak, ortada ad + özet, sağda ‹v›.
///   açık   → kapak şeridi + başlık satırı + anı satırları. Yüksekliği
///            anı sayısına göre büyür.
///
/// SAF WIDGET: koleksiyonun nereden geldiğini bilmez, açık mı kapalı mı
/// olduğunu bile DIŞARIDAN alır. Katlama durumunu kartın kendi içinde
/// tutmadık; liste "aynı anda tek kart açık" kuralını uyguluyor ve bunu
/// ancak durum listede yaşarsa yapabilir.
///
/// NEDEN `features/my_life/` ALTINDA, `features/collections/` DEĞİL?
/// ARCHITECTURE.md: bir feature başka bir feature'ın yalnızca `domain/`
/// klasörünü import edebilir. Bu kart "Hayatım" ekranının bir sekmesi olarak
/// yaşıyor; `collections/presentation/` altına koysaydık `my_life` → başka
/// feature'ın presentation'ı bağımlılığı doğardı. Koleksiyonun kendi
/// ekranı yazıldığında ortak parça `shared/`a taşınabilir.
///
/// ÖLÇÜLER (Figma, 390 genişlikte çerçeve)
///
/// Dış kart (iki hâlde de aynı): 350 genişlik, dolgu 4, köşe 8,
/// 1px Brand-Default kenarlık, zemin Background-Card.
/// İç genişlik = 350 − 2×4 − 2×1 = 340 — aşağıdaki bütün "340"ların sebebi.
///
///   KAPALI (86 = 1 + 4 + 76 + 4 + 1)
///     iç satır → 340 × 76, dolgu (4, 8, 4, 8)
///     kapak    → 64 × 64, köşe 8
///     yazılar  → başlık Poppins SemiBold 14/20 Text-Primary
///                özet   Poppins Medium   12/16 Text-Secondary
///     ikon     → chevron-down 28
///
///   AÇIK (370 = 1 + 4 + 120 + 72 + 3×56 + 4 + 1)
///     kapak şeridi → 340 × 120, köşe 4
///     başlık satırı→ 340 × 72, dolgu (4, 8, 4, 8)
///                    başlık Poppins SemiBold 20/16 Text-Primary
///                    özet   Poppins Medium   12/16 Text-Secondary
///                    ikon   chevron-up 28
///     anı satırı   → 340 × 56, dolgu 4, ÜST kenarlık 1px Brand-Default
///
/// 370 KAZARA DEĞİL: üç anı satırı üzerine kurulmuş. Ama kartı 370'e
/// SABİTLEMİYORUZ — bir koleksiyonda kaç anı olacağını bilemeyiz, dördüncü
/// satır taşardı. Kart içeriğiyle büyüyor, liste kayıyor.
///
/// BAŞLIK SATIRININ ALT KENARLIĞI ÇİZİLMİYOR — bilerek. Tasarımda hem
/// başlık satırının `border-bottom`u hem anı satırının `border-top`u 1px;
/// ikisini de çizsek aynı yere iki çizgi düşerdi. Çizgiyi anı satırları
/// taşıyor, böylece kapalı hâlde başlığın altında sahipsiz bir çizgi kalmıyor.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/shared/widgets/iz_icon_action.dart';

/// Kartta gösterilecek koleksiyon.
///
/// [summary] hazır METİN olarak geliyor ("18 anı • 10-14 Mayıs 2026"):
/// sayıyı çoğullamak ve tarih aralığını biçimlemek birer sunum kararıdır ve
/// bu widget'ın üstünde çözülür (bkz. `AppDateFormats.range`).
typedef CollectionCardData = ({
  String id,
  String coverAsset,
  String title,
  String summary,
  List<CollectionMemoryData> memories,
});

/// Açık kartta listelenen tek anı.
typedef CollectionMemoryData = ({
  String id,
  String imageAsset,
  String title,
  String dateLabel,
});

class CollectionCard extends StatelessWidget {
  const CollectionCard({
    required this.collection,
    required this.isExpanded,
    required this.onToggle,
    required this.onOpenMemory,
    required this.onMemoryActions,
    super.key,
  });

  final CollectionCardData collection;
  final bool isExpanded;

  final VoidCallback onToggle;
  final ValueChanged<CollectionMemoryData> onOpenMemory;

  /// Satırın üç nokta düğmesi. Menüyü AÇAN taraf burası değil: widget
  /// yalnızca haber verir, menüyü ekran açar (bkz. ARCHITECTURE.md —
  /// `widgets/` navigasyon yapmaz).
  ///
  /// İkinci parametre dokunulan düğmenin EKRAN koordinatlarındaki kutusu.
  /// Menü ona çıpalanıyor; `BuildContext` taşımak yerine hazır bir [Rect]
  /// veriyoruz ki çağıran tarafın render ağacıyla uğraşması gerekmesin.
  final void Function(CollectionMemoryData memory, Rect anchor) onMemoryActions;

  /// Figma: kapalı 86, açık 370 (üç anıyla).
  static const double kCollapsedHeight = 86;

  /// Figma: dış kart dolgusu 4, köşe 8.
  static const double _kPadding = AppSpacing.xs;
  static const Radius _kRadius = AppRadius.sm;

  /// Figma: kapalı satır 76, başlık satırı 72, kapak şeridi 120.
  static const double kCollapsedRowHeight = 76;
  static const double kHeaderHeight = 72;
  static const double kCoverStripHeight = 120;

  /// Figma: kapalı hâldeki küçük kapak 64, köşe 8.
  static const double kCollapsedCoverSize = 64;

  /// Figma: satırların kendi yatay dolgusu 8, dikey 4.
  static const double _kRowPaddingH = AppSpacing.sm;
  static const double _kRowPaddingV = AppSpacing.xs;

  /// Figma: durum ikonu 28.
  static const double _kChevronSize = AppIconSize.lg;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      expanded: isExpanded,
      label: isExpanded
          ? context.l10n.collectionCollapse
          : context.l10n.collectionExpand,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: const BorderRadius.all(_kRadius),
          border: Border.all(color: colors.outlineVariant),
        ),
        padding: const EdgeInsets.all(_kPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: isExpanded ? _expanded(context) : [_collapsed(context)],
        ),
      ),
    );
  }

  // --- KAPALI ---------------------------------------------------------------

  Widget _collapsed(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      // Kartın TAMAMI tıklanabilir; chevron ayrı bir düğme DEĞİL.
      // Bu yüzden ikonun kendi 48'lik dokunma kutusuna ihtiyacı yok ve
      // tasarımdaki 8'lik kenar boşluğuna tam oturabiliyor (NFR-033 zaten
      // 76 yüksekliğindeki satırla fazlasıyla karşılanıyor).
      child: SizedBox(
        height: kCollapsedRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _kRowPaddingH,
            vertical: _kRowPaddingV,
          ),
          child: Row(
            children: [
              _Cover(
                asset: collection.coverAsset,
                width: kCollapsedCoverSize,
                height: kCollapsedCoverSize,
                radius: AppRadius.sm,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TitleBlock(
                  title: collection.title,
                  summary: collection.summary,
                  // FIGMA: kapalı başlık Poppins SemiBold 14/20 → labelLarge.
                  titleStyle: context.text.labelLarge,
                ),
              ),
              Icon(
                AppIcons.expand,
                size: _kChevronSize,
                color: context.colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- AÇIK -----------------------------------------------------------------

  List<Widget> _expanded(BuildContext context) => [
    // Kapak şeridi de başlıkla birlikte tıklanabilir: kullanıcı kartı
    // kapatmak için ille de küçük chevron'u bulmak zorunda kalmasın.
    InkWell(
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Cover(
            asset: collection.coverAsset,
            height: kCoverStripHeight,
            // Figma: kapak şeridinin köşesi 4 — karttan (8) daha küçük,
            // çünkü şerit kartın içinde duruyor ve iç köşe daha keskin olur.
            radius: AppRadius.xs,
          ),
          SizedBox(
            height: kHeaderHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _kRowPaddingH,
                vertical: _kRowPaddingV,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TitleBlock(
                      title: collection.title,
                      summary: collection.summary,
                      // FIGMA: açık başlık Poppins SemiBold 20/16 →
                      // `titleLarge`. Açık kart ekranın odağı olduğu için
                      // başlık kapalı hâlden (14) belirgin şekilde büyük.
                      titleStyle: context.text.titleLarge,
                    ),
                  ),
                  Icon(
                    AppIcons.collapse,
                    size: _kChevronSize,
                    color: context.colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),

    for (final memory in collection.memories)
      _MemoryRow(
        memory: memory,
        onTap: () => onOpenMemory(memory),
        onActions: (anchor) => onMemoryActions(memory, anchor),
      ),
  ];
}

/// Başlık + altındaki özet satırı. İki hâlde de aynı, yalnızca başlığın
/// puntosu değişiyor.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.summary,
    required this.titleStyle,
  });

  final String title;
  final String summary;
  final TextStyle? titleStyle;

  /// Figma: yazı kutusunun dikey dolgusu 8, satırlar arası 16.
  static const double _kPaddingVertical = AppSpacing.sm;
  static const double _kGap = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: _kPaddingVertical,
        // Figma: yatayda 2 — yazının kutuya yapışmasını engelleyen incelik.
        horizontal: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: titleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: _kGap),
          Text(
            summary,
            // FIGMA: Poppins Medium 12/16 → `labelMedium`.
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Açık kartın içindeki tek anı satırı.
///
/// `Stateful` OLMAK ZORUNDA: üç nokta menüsü bu düğmeye çıpalanıyor ve
/// düğmenin ekrandaki yerini okumak için ömrü boyunca AYNI kalan bir
/// [GlobalKey] gerekiyor. `build` içinde üretilen bir anahtar her karede
/// yenilenir ve `currentContext` boş döner.
class _MemoryRow extends StatefulWidget {
  const _MemoryRow({
    required this.memory,
    required this.onTap,
    required this.onActions,
  });

  final CollectionMemoryData memory;
  final VoidCallback onTap;
  final ValueChanged<Rect> onActions;

  /// Figma: satır 56 = 4 + 48 + 4.
  static const double kHeight = 56;

  /// Figma: küçük kapak 48 × 48, köşe 8.
  static const double kThumbSize = 48;

  /// Figma: satır dolgusu 4, kapak–yazı arası 12, başlık–tarih arası 4.
  static const double _kPadding = AppSpacing.xs;
  static const double _kThumbGap = 12;
  static const double _kTextGap = AppSpacing.xs;

  /// Figma: üç nokta 24.
  static const double _kActionIconSize = 24;

  @override
  State<_MemoryRow> createState() => _MemoryRowState();
}

class _MemoryRowState extends State<_MemoryRow> {
  /// Üç nokta düğmesinin ekrandaki yerini okumak için.
  final _actionKey = GlobalKey();

  /// Düğmenin EKRAN koordinatlarındaki kutusunu ölçüp yukarı bildirir.
  ///
  /// Anahtar `IzIconAction`ın kendisinde, sarmalayan `IzIconActionRow`da
  /// DEĞİL: satır bir `Transform.translate` uyguluyor ve `localToGlobal` bir
  /// render nesnesinin KENDİ dönüşümünü hesaba katmaz. Anahtar dönüşümün
  /// altındaki düğmede olduğu için ölçtüğümüz kutu ekranda GÖRÜNEN yer.
  void _reportAnchor() {
    final box = _actionKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    widget.onActions(box.localToGlobal(Offset.zero) & box.size);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final memory = widget.memory;

    return DecoratedBox(
      decoration: BoxDecoration(
        // Figma: her anı satırının ÜST kenarlığı 1px. Başlık satırıyla
        // arasındaki çizgiyi de bu veriyor (bkz. dosya başındaki not).
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SizedBox(
        height: _MemoryRow.kHeight,
        child: Row(
          children: [
            // Satırın kendisi anıya gider; üç nokta AYRI bir eylem olduğu
            // için `InkWell` yalnızca sol kısmı kapsıyor. Tamamını sarsaydık
            // üç noktaya dokunmak da satırı açardı.
            Expanded(
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(_MemoryRow._kPadding),
                  child: Row(
                    children: [
                      _Cover(
                        asset: memory.imageAsset,
                        width: _MemoryRow.kThumbSize,
                        height: _MemoryRow.kThumbSize,
                        radius: AppRadius.sm,
                      ),
                      const SizedBox(width: _MemoryRow._kThumbGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              memory.title,
                              // 14/20 ama MEDIUM (500) — Figma "Regular"
                              // diyordu, ekranda fazla ince duruyordu.
                              //
                              // Ölçekte üç ağırlık var ve üçü de Poppins'in
                              // gömülü dosyalarına karşılık geliyor:
                              //   bodyMedium  → Regular  (400) — çok ince
                              //   titleMedium → Medium   (500) ← burası
                              //   labelLarge  → SemiBold (600) — koleksiyon
                              //                                  başlığıyla
                              //                                  yarışırdı
                              // Anı satırı kartın İÇERİĞİ; başlığın altında
                              // ikinci sırada durmalı ama silik de olmamalı.
                              style: context.text.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: _MemoryRow._kTextGap),
                            Text(
                              memory.dateLabel,
                              // FIGMA: Poppins Regular 10/18 → `bodyTiny`.
                              style: context.textStyles.bodyTiny,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ÜÇ NOKTA — kendi dokunma hedefi olan GERÇEK bir düğme.
            //
            // `IzIconActionRow` sarmalı ölçü için şart: `IconButton`ın kutusu
            // 48, ikonu 24, yani her yanda 12 görünmez pay var. Satır
            // hizalamayı bu paya göre düzeltmezsek ikonun GÖRÜNEN sağ kenarı
            // tasarımdakinden 12 px içeride kalır.
            IzIconActionRow(
              actions: [
                IzIconAction(
                  key: _actionKey,
                  icon: AppIcons.more,
                  tooltip: context.l10n.memoryMoreActions,
                  onPressed: _reportAnchor,
                  size: _MemoryRow._kActionIconSize,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kapak görseli — üç ölçüde de aynı davranış.
///
/// ⚠️ Şimdilik asset. Veri bağlandığında `Memory.coverMedia`den gelecek;
/// değişecek tek yer bu widget (bkz. `MediaThumbnail`).
class _Cover extends StatelessWidget {
  const _Cover({
    required this.asset,
    required this.height,
    required this.radius,
    this.width,
  });

  final String asset;

  /// null → kalan genişliği doldur (açık karttaki kapak şeridi).
  final double? width;
  final double height;
  final Radius radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.all(radius),
      child: Image.asset(
        asset,
        width: width,
        height: height,
        // Figma: `scale: crop` — oranı bozmadan kutuyu doldur.
        fit: BoxFit.cover,
        // Kapak bulunamazsa kart çökmesin.
        errorBuilder: (context, error, stack) => ColoredBox(
          color: context.colors.surfaceContainerHigh,
          child: SizedBox(
            width: width,
            height: height,
            child: Icon(
              AppIcons.photo,
              size: AppIconSize.md,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
