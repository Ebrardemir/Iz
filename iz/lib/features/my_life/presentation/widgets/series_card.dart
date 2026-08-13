/// SERİLERİM sekmesindeki kart: bir ritüel ve onun yıl yıl anıları.
///
/// FR-076: "Ritüelin yıllarını YAN YANA karşılaştırma." Kartın alt şeridi tam
/// olarak bu — 2023, 2022, 2021… her yılın kapağı ve yeri.
///
/// SAF WIDGET: veri almaz, verilen [SeriesCardData]'yı çizer ve dokunmayı
/// yukarı bildirir. `ProviderScope` kurmadan test edilebiliyor.
///
/// ÖLÇÜLER (Figma, 390 genişlikte çerçeve)
///
/// Kart → 333 × 202, dolgu (4, 12, 8, 12), köşe 20, 1px Brand-Default
///        kenarlık, zemin Background-Card.
/// İç genişlik = 333 − 12 − 12 − 2 = 307 — aşağıdaki "307"lerin sebebi.
///
///   üst satır  → 307 × 56, dikey dolgu 8, ikon–yazı arası 14
///                ikon    36 × 36
///                başlık  Poppins Medium  14/20, Text-Primary
///                altyazı Poppins Regular 12/16, Text-Secondary
///                chevron-right 28
///   yıl şeridi → 307 × 108, öğeler arası space-between
///                öğe 64 × 108, dikey dolgu 4, satır arası 6
///                yıl   Poppins Regular 12/16, Text-Primary
///                kapak 56 × 56, köşe 12, kırparak sığdır
///                yer   Poppins Medium  10/16, Text-Secondary
///   gösterge   → 307 × 8, yatay dolgu 24
///
/// 202 NEDEN TAM ÇIKIYOR?
///   1 + 4 + 56 + 8 + 108 + 8 + 8 + 8 + 1 = 202
/// yani üst satır, şerit ve gösterge arasında 8'lik boşluklar. Kartı
/// yüksekliğe SABİTLEMİYORUZ; yazı ölçeği büyütülen bir cihazda başlık iki
/// satıra taşabilir ve sabit yükseklik onu kırpardı (NFR-032).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';

/// Kartta gösterilecek seri.
///
/// [subtitle] hazır METİN olarak geliyor ("Her yıl 3 Mart'ta"): tekrar
/// tipinden o cümleyi üretmek dile VE dilbilgisine bağlı bir sunum kararı,
/// bu widget'ın üstünde çözülüyor (bkz. `rituals/presentation/ritual_l10n.dart`).
typedef SeriesCardData = ({
  String id,

  /// Veritabanındaki `iconKey` — çizime [AppIcons.forKey] çeviriyor.
  /// Anahtar taşıyoruz, `IconData` DEĞİL: ikon seti değişse bile kullanıcının
  /// verisi bozulmamalı.
  String iconKey,
  String title,
  String subtitle,
  List<SeriesYearData> years,
});

/// Şeritteki tek yıl.
typedef SeriesYearData = ({
  String memoryId,
  int year,
  String imageAsset,

  /// Konum etiketi ("Çeşme"). Konum opsiyonel (rapor 20.1), boş olabilir.
  String? placeLabel,
});

class SeriesCard extends StatelessWidget {
  const SeriesCard({
    required this.series,
    required this.onOpen,
    required this.onOpenYear,
    super.key,
  });

  final SeriesCardData series;

  /// Kartın tamamına / sağdaki oka dokunuş — serinin kendi ekranına gider.
  final VoidCallback onOpen;

  /// Şeritteki bir yıla dokunuş — o yılın anısına gider.
  final ValueChanged<SeriesYearData> onOpenYear;

  /// Figma: kart dolgusu (4, 12, 8, 12).
  static const EdgeInsets _kPadding = EdgeInsets.fromLTRB(12, 4, 12, 8);

  /// Figma: üst satır 56, yıl şeridi 108, gösterge 8, aralar 8.
  static const double kHeaderHeight = 56;
  static const double kYearStripHeight = 108;
  static const double kIndicatorHeight = 8;
  static const double _kGap = AppSpacing.sm;

  /// Figma: ritüel ikonu 36.
  static const double kIconSize = 36;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: AppRadius.contentCard,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: _kPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(series: series, onOpen: onOpen),
            const SizedBox(height: _kGap),
            _YearStrip(years: series.years, onOpenYear: onOpenYear),
          ],
        ),
      ),
    );
  }
}

/// İkon + başlık/altyazı + sağdaki ok.
class _Header extends StatelessWidget {
  const _Header({required this.series, required this.onOpen});

  final SeriesCardData series;
  final VoidCallback onOpen;

  /// Figma: ikonla yazı arası 14, satırın dikey dolgusu 8.
  static const double _kIconGap = 14;
  static const double _kPaddingVertical = AppSpacing.sm;

  /// Figma: başlıkla altyazı arası 4.
  static const double _kTextGap = AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      // Ekran okuyucu için tek parça: "Yaz Tatillerimiz, Her yıl yaz
      // aylarında, 4 yıl". Yıl şeridi ayrıca gezilebilir kalıyor.
      label:
          '${series.title}, ${series.subtitle}, '
          '${context.l10n.ritualYearCount(series.years.length)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onOpen,
        // Dokunma hedefi satırın tamamı (56); sağdaki ok ayrı bir düğme
        // DEĞİL, bu yüzden kendi 48'lik kutusuna ihtiyacı yok ve tasarımdaki
        // kenara tam oturuyor.
        child: SizedBox(
          height: SeriesCard.kHeaderHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: _kPaddingVertical),
            child: Row(
              children: [
                Icon(
                  AppIcons.forKey(series.iconKey),
                  size: SeriesCard.kIconSize,
                  // Altın aksan: ritüel simgesi kartın sıcak vurgusu.
                  color: colors.tertiary,
                ),
                const SizedBox(width: _kIconGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        series.title,
                        // FIGMA: Poppins Medium 14/20 → `titleMedium`.
                        style: context.text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: _kTextGap),
                      Text(
                        series.subtitle,
                        // FIGMA: Poppins Regular 12/16 → `caption`.
                        // (`bodySmall` de 12 Regular ama satır yüksekliği 18;
                        //  bu satır 16 istiyor — bkz. app_typography.dart.)
                        style: context.textStyles.caption.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  AppIcons.forward,
                  size: AppIconSize.lg,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Yılların yan yana dizildiği şerit ve altındaki kaydırma göstergesi.
///
/// NEDEN KAYDIRILABİLİR?
/// Tasarımda dört yıl görünüyor ve tam sığıyor. Ama bir ritüel on yıl
/// sürebilir; sabit dört öğe göstermek eski yılları ERİŞİLEMEZ yapardı.
/// Şerit yatay kayıyor, altındaki gösterge de nerede olduğunu söylüyor.
class _YearStrip extends StatefulWidget {
  const _YearStrip({required this.years, required this.onOpenYear});

  final List<SeriesYearData> years;
  final ValueChanged<SeriesYearData> onOpenYear;

  /// Öğeler arası boşluk — 17.
  ///
  /// TASARIMDAN TÜRETİLDİ, `space-between`ten DEĞİL. Figma şeridi
  /// "space-between" diyor ve dört öğeyle bu tam 17'ye denk geliyor:
  ///   307 − 4×64 = 51,  51 ÷ 3 = 17
  ///
  /// Ama `space-between`i olduğu gibi almak yanlış sonuç veriyordu: iki yılı
  /// olan bir seride öğeler kartın iki ucuna savruluyor, ortada kocaman bir
  /// boşluk kalıyordu. Ritüellerin yıl sayısı eşit değil — biri on yıl, biri
  /// iki yıl. Sabit aralık + sola hizalama hepsinde AYNI ritmi veriyor ve
  /// dört öğeli durumda tasarımı birebir üretiyor.
  static const double kGap = 17;

  @override
  State<_YearStrip> createState() => _YearStripState();
}

class _YearStripState extends State<_YearStrip> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: SeriesCard.kYearStripHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _controller,
                child: ConstrainedBox(
                  // `minWidth` ŞART: içerik sığmasa da satır en az şerit
                  // genişliğinde olsun, yoksa `SingleChildScrollView` içinde
                  // öğeler kendi genişliğine büzüşür.
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    children: [
                      for (final year in widget.years) ...[
                        if (year != widget.years.first)
                          const SizedBox(width: _YearStrip.kGap),
                        _YearItem(
                          year: year,
                          onTap: () => widget.onOpenYear(year),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.sm),
        _ScrollIndicator(
          controller: _controller,
          yearCount: widget.years.length,
        ),
      ],
    );
  }
}

/// Şeritteki tek yıl: üstte yıl, ortada kapak, altta yer.
class _YearItem extends StatelessWidget {
  const _YearItem({required this.year, required this.onTap});

  final SeriesYearData year;
  final VoidCallback onTap;

  /// Figma: öğe 64 geniş, kapak 56 × 56 köşe 12.
  static const double kWidth = 64;
  static const double kCoverSize = 56;

  /// Figma: dikey dolgu 4, satırlar arası 6.
  static const double _kPaddingVertical = AppSpacing.xs;
  static const double _kGap = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: year.placeLabel == null
          ? '${year.year}'
          : '${year.year}, ${year.placeLabel}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.md),
        child: SizedBox(
          width: kWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: _kPaddingVertical),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${year.year}',
                  // FIGMA: Poppins Regular 12/16 → `caption`.
                  style: context.textStyles.caption,
                  maxLines: 1,
                ),
                const SizedBox(height: _kGap),
                _Cover(asset: year.imageAsset),
                const SizedBox(height: _kGap),

                // Konum OPSİYONEL (rapor 20.1: "kullanıcı kaldırabilmeli").
                // Yokken de yer tutuyoruz ki şeritteki öğeler aynı yükseklikte
                // kalsın ve kapaklar tek hizada dursun.
                SizedBox(
                  height: 16,
                  child: year.placeLabel == null
                      ? null
                      : Text(
                          year.placeLabel!,
                          // FIGMA: Poppins Medium 10/16 → `labelSmall`.
                          style: context.text.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(AppRadius.md),
      child: Image.asset(
        asset,
        width: _YearItem.kCoverSize,
        height: _YearItem.kCoverSize,
        // Figma: `scale: crop` — oranı bozmadan kutuyu doldur.
        fit: BoxFit.cover,
        // Kapak bulunamazsa şerit çökmesin.
        errorBuilder: (context, error, stack) => ColoredBox(
          color: context.colors.surfaceContainerHigh,
          child: SizedBox(
            width: _YearItem.kCoverSize,
            height: _YearItem.kCoverSize,
            child: Icon(
              AppIcons.photo,
              size: AppIconSize.sm,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Şeridin altındaki ince çizgi ve üzerinde kayan nokta.
///
/// NEDEN MATERIAL'IN `Scrollbar`I DEĞİL?
/// Material'ın kaydırma çubuğu kalın bir dikdörtgen ve yalnızca kaydırma
/// SIRASINDA görünüyor. Tasarımdaki şey sürekli duran, ince bir raydaki
/// küçük bir nokta — konumu bir gösterge değil, kartın bir parçası.
class _ScrollIndicator extends StatelessWidget {
  const _ScrollIndicator({required this.controller, required this.yearCount});

  final ScrollController controller;

  /// Kaç nokta çizilecek — her yıl bir nokta.
  final int yearCount;

  /// Figma: gösterge satırının yatay dolgusu 24.
  static const double _kPaddingHorizontal = AppSpacing.lg;

  /// Figma: nokta 8 × 8.
  static const double kDotSize = SeriesCard.kIndicatorHeight;

  /// Kaç yıla kadar NOKTA gösterilir?
  ///
  /// 8'lik noktalar arasında en az 6 boşluk kalması gerekiyor; 259'luk rayda
  /// bu 18 nokta demek (8n + 6(n−1) ≤ 259). Rahat bir pay bırakıp 16'da
  /// kesiyoruz.
  ///
  /// Üstünde ne oluyor? Sürekli göstergeye (kayan tek nokta) dönüyor.
  /// İKİ ÇÖZÜM BİRBİRİNİ TAMAMLIYOR:
  ///   • Az yıl → az kaydırma → kayan nokta parmaktan hızlı gider, ayrık
  ///     noktalar doğru cevap.
  ///   • Çok yıl → çok kaydırma → kayan nokta doğal hızda gider, ama noktalar
  ///     zaten sığmaz.
  /// Yani her aralıkta doğru olan gösterge devrede.
  static const int kMaxDots = 16;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SeriesCard.kIndicatorHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kPaddingHorizontal),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // `AnimatedBuilder` kaydırma boyunca her karede yalnızca BU
            // parçayı yeniden çiziyor — kartın tamamını değil.
            return AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                // GÖSTERGE HER SERİDE VAR — kaydırılamayanlarda da.
                //
                // Önce "kaydırılacak şey yoksa gizle" diyorduk. O karar
                // HAREKETLİ nokta içindi: kaydırılamayan bir şeritte kayan
                // nokta "devamı var" diye yalan söylüyordu. Yıl başına nokta
                // ise yalan söylemiyor — üç nokta gerçekten üç yıl demek ve
                // hepsi doluysa "hepsini görüyorsun" demek. Üstelik gösterge
                // her kartta durunca kartların alt kenarı aynı ritmi tutuyor.
                final position = controller.hasClients
                    ? controller.position
                    : null;

                return Stack(
                  children: [
                    const _Rail(),

                    if (yearCount <= kMaxDots)
                      Positioned.fill(
                        child: _YearDots(
                          yearCount: yearCount,
                          railWidth: constraints.maxWidth,
                          // Şerit henüz ölçülmediyse (ilk kare) baştaki
                          // pencereyi varsayıyoruz; bir kare sonra gerçek
                          // değerle yeniden çiziliyor.
                          visible: resolveVisibleYears(
                            scrollOffset: position?.pixels ?? 0,
                            viewportWidth:
                                position?.viewportDimension ??
                                constraints.maxWidth,
                            yearCount: yearCount,
                            itemWidth: _YearItem.kWidth,
                            gap: _YearStrip.kGap,
                          ),
                        ),
                      )
                    else if (position != null)
                      Positioned(
                        left: resolveSeriesIndicatorOffset(
                          scrollOffset: position.pixels,
                          maxScrollExtent: position.maxScrollExtent,
                          trackWidth: constraints.maxWidth,
                          dotSize: kDotSize,
                        ),
                        child: const _Dot(isFilled: true),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Noktaların üzerinde durduğu saç teli çizgi.
///
/// Rengi Text-Secondary (tasarımdan) ama SOLGUN. Tasarım rayın rengini
/// veriyor, noktaların rengini vermiyor; ikisi aynı olsaydı dolu noktalar
/// kendi raylarının üzerinde kaybolurdu. Ray dekoratif, noktalar bilgi
/// taşıyor.
///
/// `Positioned(left: 0, right: 0)` ŞART, `Align` DEĞİL: Align çocuğuna GEVŞEK
/// yatay kısıt verir ve çocuksuz bir `ColoredBox` kendini 0 genişlikte ölçer —
/// ray hiç çizilmez. Aynı tuzağa `day_memory_card.dart`ın alt çizgisinde de
/// düşmüştük; bu yüzden testte rayın genişliği ölçülüyor.
class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: (SeriesCard.kIndicatorHeight - 1) / 2,
      child: SizedBox(
        height: 1,
        child: ColoredBox(
          color: context.colors.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

/// Yıl başına bir nokta; EKRANDA GÖRÜNEN yıllar dolu.
///
/// "Kaç yılım var ve hangilerine bakıyorum" sorusunun cevabı. Dolu pencere
/// kaydırdıkça sağa kayıyor.
///
/// NOKTALAR SOLA HİZALI VE ARALIK YIL ADIMINA BAĞLI — rayı eşit bölmüyoruz.
/// Sebebi [resolveDotSpacing] açıklamasında: sığdığı sürece noktalar üstteki
/// yıl sütunlarının altına düşüyor, kalan ray düz çizgi olarak kalıyor.
class _YearDots extends StatelessWidget {
  const _YearDots({
    required this.yearCount,
    required this.railWidth,
    required this.visible,
  });

  final int yearCount;
  final double railWidth;
  final ({int first, int count}) visible;

  @override
  Widget build(BuildContext context) {
    final spacing = resolveDotSpacing(
      railWidth: railWidth,
      dotSize: _ScrollIndicator.kDotSize,
      count: yearCount,
      itemStride: _YearItem.kWidth + _YearStrip.kGap,
    );

    return Row(
      children: [
        for (var i = 0; i < yearCount; i++) ...[
          if (i > 0) SizedBox(width: spacing - _ScrollIndicator.kDotSize),
          _Dot(
            isFilled: i >= visible.first && i < visible.first + visible.count,
          ),
        ],
      ],
    );
  }
}

/// Noktaların merkezleri arasındaki mesafe.
///
/// TEK FORMÜL, İKİ İŞ:
///
///   spacing = min(yıl adımı, raya sığan en büyük aralık)
///
/// 1. SIĞDIĞI SÜRECE YIL ADIMI (81 = 64 kutu + 17 aralık). Böylece noktalar
///    üstteki yıl sütunlarının tam altına düşüyor — "yılların altı yuvarlak,
///    gerisi düz çizgi". Dört yıllık bir seride noktalar 251 px tutuyor,
///    kalan ~8 px düz ray olarak kalıyor.
///
/// 2. SIĞMIYORSA SIKIŞIYOR. On iki yıllık bir seride 81'lik aralık 891 px
///    isterdi; formül raya sığan en büyük aralığa iniyor ve noktalar eşit
///    dağılıyor. Hiza bozuluyor ama zaten o durumda şerit kayıyor ve hiza
///    tutturulamaz.
///
/// Rayı `space-between` ile eşit bölmek ilk denenen yoldu ve iki yıllık bir
/// seride noktaları rayın iki ucuna savuruyordu — halter gibi duruyordu.
///
/// Saf fonksiyon: widget kurmadan test edilebilir.
double resolveDotSpacing({
  required double railWidth,
  required double dotSize,
  required int count,
  required double itemStride,
}) {
  if (count <= 1) return itemStride;

  final maxSpacing = (railWidth - dotSize) / (count - 1);
  return math.min(itemStride, maxSpacing);
}

class _Dot extends StatelessWidget {
  const _Dot({required this.isFilled});

  final bool isFilled;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        // Boş nokta İÇİ DOLU ama solgun — 8 px'de 1 px'lik bir halka
        // güvenilir çizilmiyor, kenar yumuşatmada kayboluyor.
        color: isFilled ? color : color.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(dimension: _ScrollIndicator.kDotSize),
    );
  }
}

/// Şu an ekranda GÖRÜNEN yıllar: ilk görünenin indeksi ve kaç tane olduğu.
///
/// Bir yıl, kutusunun en az YARISI pencerede kalıyorsa görünüyor sayılıyor.
/// Eşik olmasaydı kenardan 1 px giren yıl da noktayı doldurur ve gösterge
/// kaydırma boyunca titrerdi.
///
/// Saf fonksiyon: widget kurmadan test edilebilir
/// (bkz. test/unit/series_card_test.dart).
({int first, int count}) resolveVisibleYears({
  required double scrollOffset,
  required double viewportWidth,
  required int yearCount,
  required double itemWidth,
  required double gap,
}) {
  if (yearCount <= 0 || viewportWidth <= 0) return (first: 0, count: 0);

  final stride = itemWidth + gap;
  final windowStart = scrollOffset;
  final windowEnd = scrollOffset + viewportWidth;

  var first = -1;
  var last = -1;

  for (var i = 0; i < yearCount; i++) {
    final left = i * stride;
    final right = left + itemWidth;
    final overlap = math.min(right, windowEnd) - math.max(left, windowStart);

    if (overlap >= itemWidth / 2) {
      if (first < 0) first = i;
      last = i;
    }
  }

  if (first < 0) {
    // Hiçbir yıl yarı yarıya görünmüyor: aşırı kaydırma (bounce) ya da
    // pencere bir öğeden dar. En yakın yılı göstermek, hiçbir şey
    // göstermemekten iyi — gösterge boş kalmasın.
    final nearest = (scrollOffset / stride).round().clamp(0, yearCount - 1);
    return (first: nearest, count: 1);
  }

  return (first: first, count: last - first + 1);
}

/// Sürekli göstergedeki tek noktanın ray üzerindeki SOL kenar konumu.
///
/// Yalnızca [_ScrollIndicator.kMaxDots]'tan ÇOK yılı olan serilerde
/// kullanılıyor; orada noktalar sığmıyor ve kaydırma mesafesi de yeterince
/// uzun olduğu için kayan nokta doğal hızda gidiyor.
///
/// Nokta rayın başından sonuna kadar gider: kaydırma 0'da sol uçta, sonunda
/// sağ uçta. Sağ uçta noktanın kendi genişliği kadar geri çekiliyor, yoksa
/// raydan taşar.
///
/// Saf fonksiyon: widget kurmadan test edilebilir.
double resolveSeriesIndicatorOffset({
  required double scrollOffset,
  required double maxScrollExtent,
  required double trackWidth,
  required double dotSize,
}) {
  final travel = trackWidth - dotSize;
  if (travel <= 0) return 0;

  // `maxScrollExtent` 0 ise kaydırma yok; nokta başta durur. (Çağıran taraf
  // bu durumda göstergeyi hiç çizmiyor ama fonksiyon kendi başına da
  // güvenli olmalı — bölme sıfıra düşmesin.)
  if (maxScrollExtent <= 0) return 0;

  final fraction = (scrollOffset / maxScrollExtent).clamp(0.0, 1.0);
  return fraction * travel;
}
