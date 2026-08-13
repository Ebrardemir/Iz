/// Fotoğrafın üzerine binen tüm katman: üstte şerit, altta metin + buton.
///
/// Bu widget fotoğrafın TAM ÜSTÜNÜ kaplar ve dikey ritmi tek elden kurar —
/// böylece durum çubuğu payı, kavise olan mesafe gibi kararlar iki ayrı
/// dosyada birbirinden habersiz hesaplanmıyor.
///
/// İKİ VARYANT, TEK YERLEŞİM:
///   • [memory] null → kullanıcının hiç anısı yok: "İlk İzini Bırak" +
///     "Anı Ekle".
///   • [memory] dolu → "BUGÜNÜN İZİ" + başlık + tarih + "Anıyı Gör".
/// İkisi de aynı noktadan (Figma `top: 125`) başlar; yalnızca içerik değişir.
/// Boş durum geçici bir yer tutucu DEĞİL — her yeni kullanıcı önce onu görür.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/home/presentation/home_layout.dart';
import 'package:iz/features/home/presentation/widgets/glass_pill_button.dart';
import 'package:iz/features/home/presentation/widgets/home_top_bar.dart';

/// Fotoğrafın üzerinde gösterilecek anı özeti.
///
/// VIEW'A HAZIR VERİ: burada `Memory` varlığı değil, ekrana basılacak hâli
/// duruyor. Tarih METNİ de hazır geliyor — "1 hafta önce" hesabı bir sunum
/// kararıdır ve ViewModel'e aittir; bu widget onu biçimlendirmez.
typedef HeroMemory = ({String id, String title, String dateLabel});

/// FIGMA: #FFFFFFD9 → beyazın %85'i. Başlığın altındaki destek satırları
/// başlıkla yarışmasın diye biraz geride duruyor.
const Color kOnPhotoMuted = Color(0xD9FFFFFF);

class HomeHeroOverlay extends StatelessWidget {
  const HomeHeroOverlay({
    required this.onAddMemory,
    required this.onViewMemory,
    this.memory,
    this.onNotificationsPressed,
    super.key,
  });

  /// Null ise boş durum çizilir.
  final HeroMemory? memory;

  final VoidCallback onAddMemory;
  final VoidCallback onViewMemory;
  final VoidCallback? onNotificationsPressed;

  /// Figma: metin bloğu `top: 125`.
  static const double kBlockTop = 125;

  /// Blok kavise yapışmasın diye ALTTA kalan pay.
  ///
  /// Figma'da 55 (buton alt kenarı 291, fotoğraf alt kenarı 346). Bizde 34:
  /// metinler tasarımdakinden büyük olduğu için blok da uzun, o payı bloğa
  /// veriyoruz. Gözle fark edilmiyor ama dolu varyantın küçülmeden sığması
  /// için gerekiyordu.
  ///
  /// [GlassPillButton.kTapPadding] düşülüyor: butonun GÖRÜNEN kenarı
  /// hedeflenen yere otursun, görünmez dokunma payı boşluğu şişirmesin.
  static const double _kBottomInset = 34 - GlassPillButton.kTapPadding;

  /// Fotoğraf kısaldığında alt payın kaplayabileceği azami oran.
  ///
  /// Kısa telefonda görsel 240 px'e kadar iniyor; orada sabit pay bloğu üst
  /// şeride bindirecek kadar yer yiyordu. Tasarım ölçüsünde (346) hiç
  /// devreye girmiyor, yalnızca dar durumlarda koruma yapıyor.
  static const double _kBottomInsetRatio = 0.16;

  @override
  Widget build(BuildContext context) {
    // Figma çerçevesinde durum çubuğu yok; fotoğraf ise tam ekran, yani
    // gerçek telefonda saat ve pil şeridin üstüne geliyor. Tasarımdaki
    // değeri TABAN kabul edip, çubuk varsa altına iniyoruz.
    final safeTop = context.media.padding.top;
    final top = math.max(HomeTopBar.kTopInset, safeTop + AppSpacing.sm);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bottom = math.min(
          _kBottomInset,
          constraints.maxHeight * _kBottomInsetRatio,
        );

        return Padding(
          padding: EdgeInsets.only(
            left: HomeLayout.pageInset,
            right: HomeLayout.pageInset,
            top: top,
            bottom: bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeTopBar(onNotificationsPressed: onNotificationsPressed),

              // Bloğu Figma'daki [kBlockTop]'a oturtan boşluk.
              //
              // DURUM ÇUBUĞU BLOĞU KAYDIRMAZ. Şerit çubuğun altına inmek
              // zorunda çünkü saat ve pil onun üstüne geliyor; ama blok
              // ekranın ortasına yakın, çubukla işi yok. Bloğu da 25 px
              // kaydırdığımızda dolu varyant (üst başlık + iki satır başlık
              // + tarih + buton) tasarım ölçüsünde bile sığmıyor ve
              // küçülmek zorunda kalıyordu. Boşluğu şeridin GERÇEK altından
              // hesaplayınca blok her durumda 125'te kalıyor.
              //
              // BOŞLUK `Flexible` DEĞİL. Öyleyken blokla aynı esneme
              // payına (flex: 1) sahipti ve `Column` serbest alanı ikisi
              // arasında yarı yarıya bölüyordu: blok tasarım ölçüsünde bile
              // yarı yüksekliğe sıkışıp küçülerek çiziliyordu. Boşluk artık
              // sabit; esneme hakkının tamamı bloğun.
              SizedBox(
                height: _gapAfterStrip(top, constraints.maxHeight, bottom),
              ),

              // Son güvenlik ağı. Yukarıdaki boşluk sıfıra inse bile
              // içerik sığmayabilir (küçük ekran + uzun başlık); orada
              // metin kırpılmak yerine oranını koruyarak küçülüyor.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: _HeroBlock(
                    memory: memory,
                    onAddMemory: onAddMemory,
                    onViewMemory: onViewMemory,
                    maxWidth: _textWidthFor(constraints.maxWidth),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Şerit ile metin bloğu arasındaki boşluk.
  ///
  /// Amaç bloğu [kBlockTop]'a oturtmak. İki koruma var:
  ///   • Taban: durum çubuğu çok yüksekse şerit 125'in altına inebilir;
  ///     o zaman blok şeride yapışmasın diye en az `sm` boşluk kalır.
  ///   • Tavan: fotoğraf çok kısaysa boşluk bloğa yer bırakmayabilir;
  ///     bloğa her koşulda en az bir dokunma hedefi kadar yer ayırıyoruz.
  static double _gapAfterStrip(double top, double heroHeight, double bottom) {
    final free = heroHeight - top - HomeTopBar.kRowHeight - bottom;
    final desired = kBlockTop - top - HomeTopBar.kRowHeight;
    return math.max(
      AppSpacing.sm,
      math.min(desired, free - AppSpacing.minTapTarget),
    );
  }

  /// Metin sütununun genişliği — başlık da alt satır da bunu kullanır.
  ///
  /// ORAN NEREDEN GELİYOR? İki sarma davranışını birden üretmesi gerekiyor:
  ///   • Dolu varyantta başlık ("İlk İzmir Tatilimiz", 36 puntoda ~262 px)
  ///     İKİ SATIRA sarmalı — referans tasarımdaki gibi.
  ///   • Boş varyantta başlık ("İlk İzini Bırak", ~197 px) TEK SATIR kalmalı.
  ///   • Açıklama cümlesi (16 puntoda ~343 px) İKİ SATIR olmalı.
  /// Ekranın %60'ı (390'da 234) üçünü de sağlıyor.
  ///
  /// Sütunu dar tutmanın ikinci faydası: sağdaki boşluk fotoğrafın öznesine
  /// kalıyor. Çok dar ekranda oran fazla kısıtladığı için taban var.
  ///
  /// ⚠️ [screenWidth] EKRANIN TAMAMI, kenar boşlukları düşülmemiş hâli.
  /// [LayoutBuilder] `Padding`in DIŞINDA olduğu için ölçü oradan öyle
  /// geliyor; bir ara bunu yanlışlıkla ikinci kez ekleyip sütunu
  /// olması gerekenden geniş bıraktım ve sarma bozuldu.
  static double _textWidthFor(double screenWidth) {
    final available = screenWidth - 2 * HomeLayout.pageInset;
    return math.min(available, math.max(180, screenWidth * 0.6));
  }
}

/// Fotoğraf üzerindeki metin bloğu — iki varyantın ortak iskeleti.
class _HeroBlock extends StatelessWidget {
  const _HeroBlock({
    required this.memory,
    required this.onAddMemory,
    required this.onViewMemory,
    required this.maxWidth,
  });

  final HeroMemory? memory;
  final VoidCallback onAddMemory;
  final VoidCallback onViewMemory;

  /// Metin sütununun genişliği — fotoğrafın öznesi sağda kalsın diye dar.
  final double maxWidth;

  /// Metin ile buton arasındaki boşluk.
  ///
  /// Figma 8 diyordu; ekranda buton yazıya yapışık duruyordu. Metin bir
  /// BLOK, buton ayrı bir EYLEM — aralarında satır arasından (8) belirgin
  /// şekilde büyük bir nefes olması gerekiyor.
  ///
  /// Butonun görünmez dokunma payı (6) bu boşluğa ekleniyor, o yüzden
  /// çıkarılıyor — yoksa ekranda 30 görünürdü.
  static const double _kGapBeforeButton =
      AppSpacing.lg - GlassPillButton.kTapPadding;

  /// Figma: blok içindeki satırlar arası 8.
  static const double _kLineGap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = memory;

    // GENİŞLİK HER SATIRA AYRI VERİLİYOR, bloğun tamamına değil.
    //
    // `FittedBox` çocuğuna SINIRSIZ genişlik verir; bu yüzden sınırı
    // metinlerin kendisi taşımak zorunda. Ayrıca alt satırın başlıktan
    // daha geniş olabilmesini de ancak böyle sağlıyoruz — dıştaki tek bir
    // sınır çocukları KISITLAR, genişletemez.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Narrow(
          maxWidth: maxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ÜST BAŞLIK BOŞ DURUMDA DA YER KAPLAR, sadece çizilmez.
              //
              // Neden: iki varyantın BAŞLIĞI aynı hizada başlasın. Boş
              // durumda bu satırı tamamen kaldırınca başlık logoya
              // yapışıyordu; sabit bir boşluk yazmak yerine üst başlığın
              // kendi yüksekliğini kullanıyoruz ki punto değişse bile hiza
              // korunsun.
              Visibility(
                visible: info != null,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: _Eyebrow(l10n.homeHeroTodayEyebrow),
              ),
              const SizedBox(height: _kLineGap),

              // Uzun başlık burada İKİ SATIRA sarıyor — referans tasarımda
              // olduğu gibi. Sarmayı üreten şey [maxWidth]'in darlığı.
              _Title(info?.title ?? l10n.homeHeroEmptyTitle),
              const SizedBox(height: _kLineGap),

              // ÜÇÜNCÜ SATIR iki varyantta da var, yalnızca içeriği
              // değişiyor: dolu → anının tarihi, boş → ne yapması
              // gerektiğini anlatan cümle. Aynı yuvayı ve aynı tipografiyi
              // paylaştıkları için varyantlar arasında geçerken düzen
              // kaymıyor. Cümle bu sütunda iki satıra sarıyor.
              _SecondaryLine(info?.dateLabel ?? l10n.homeHeroEmptySubtitle),
            ],
          ),
        ),

        const SizedBox(height: _kGapBeforeButton),

        if (info != null)
          GlassPillButton(
            label: l10n.homeHeroViewMemory,
            icon: AppIcons.forward,
            iconAfterLabel: true,
            onPressed: onViewMemory,
          )
        else
          GlassPillButton(
            label: l10n.homeHeroAddMemory,
            icon: AppIcons.add,
            onPressed: onAddMemory,
          ),
      ],
    );
  }
}

/// Çocuğunu belirli bir genişlikle sınırlar.
///
/// `FittedBox` içindeki metinler sınırsız genişlikte ölçülür ve hiç
/// sarmaz; sınırı taşıyan bu widget.
class _Narrow extends StatelessWidget {
  const _Narrow({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: child,
  );
}

/// "BUGÜNÜN İZİ" — bloğun küçük üst başlığı.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      // FIGMA: Poppins Regular 10/18, harf aralığı 0 → ölçekte `bodyTiny`.
      // Önce `labelSmall` (10/16, Medium) ve 1.5 harf aralığı kullanmıştım;
      // tasarımın gerçek değerleri gelince ikisi de düzeltildi.
      style: context.textStyles.bodyTiny.copyWith(
        // FIGMA: #FFFFFFD9 → beyazın %85'i. Bu satır bir ETİKET, başlıkla
        // yarışmamalı.
        color: kOnPhotoMuted,
        shadows: kOnPhotoShadows,
      ),
    );
  }
}

/// Anının başlığı (ya da boş durumda çağrı metni).
class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      // Display 36 serif — markanın sesi. Figma H1 (28) veriyordu ama
      // fotoğrafın üzerinde ekranın odak noktası olması gerekiyor.
      style: context.text.displayMedium?.copyWith(
        color: Colors.white,
        shadows: kOnPhotoShadows,
      ),
      // Uzun başlık fotoğrafı yutmasın.
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Başlığın altındaki ikincil satır.
///
/// Dolu varyantta anının tarihi ("1 hafta önce"), boş varyantta kullanıcıya
/// ne yapacağını anlatan cümle. Tek widget çünkü ikisi aynı yuvada, aynı
/// tipografiyle duruyor — biri değişirse öteki de değişsin.
///
/// PUNTO: Body Large (16). Figma tarihi 12 veriyor ama fotoğrafın üzerinde,
/// 36 puntoluk başlığın altında siliniyor; ayrıca boş varyanttaki cümleyle
/// aynı ölçüde durması gerekiyor.
class _SecondaryLine extends StatelessWidget {
  const _SecondaryLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.text.bodyLarge?.copyWith(
        color: kOnPhotoMuted,
        shadows: kOnPhotoShadows,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
