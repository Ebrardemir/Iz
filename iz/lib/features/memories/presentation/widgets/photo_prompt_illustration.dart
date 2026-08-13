/// Yeni anı akışının ilk adımındaki illüstrasyon: kesikli bir çerçeve
/// içinde iki eğik fotoğraf karesi, arkasında altın bir dal ve köşede
/// "+" işareti.
///
/// NEDEN ÇİZİM, NEDEN ASSET DEĞİL?
///   • Tek bir PNG iki temada da çalışmaz: koyu temada krem kareler
///     parlar. Widget'la çizince bütün renkler temadan geliyor.
///   • Ölçek bozulmuyor — vektör bile olsa bir asset'in çizgi kalınlığı
///     büyütünce kalınlaşır, burada `strokeWidth` sabit kalıyor.
///   • Dal, markanın kendi motifi (`iz_wordmark.dart`'taki filizle aynı
///     dil). Dışarıdan bir görsel yerine kendi imzamızı kullanıyoruz.
///
/// KESİKLİ ÇERÇEVE ELDE ÇİZİLİYOR: Flutter'ın `Border`ı kesikli çizgiyi
/// desteklemiyor. Paket eklemek yerine `Path.computeMetrics` ile yolu
/// parçalayan küçük bir `CustomPainter` yazdık — `curved_top_panel.dart` ve
/// `series_card.dart` da aynı yolu izliyor.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';

/// İnce konturlu botanik dal — `IzWordmark`'taki filizin ölçüye uyarlanmış
/// kopyası.
///
/// KOPYA DEĞİL, PAYLAŞILMASI GEREKEN BİR ŞEY DE DEĞİL: logodaki filiz marka
/// imzası ve orada tek renk/tek ölçüde kullanılıyor. Buradaki dekoratif bir
/// doku. İkisini tek yere çıkarmak, birini değiştirdiğimizde ötekini bozma
/// riski demekti.
///
/// ⚠️ `stroke-width` 1.1 DEĞİL 0.6. SVG'nin çizgi kalınlığı viewBox'la
/// ÖLÇEKLENİYOR: logodaki 1.1, 38 px'lik kutuda ~1.3 px'lik zarif bir çizgi
/// veriyor. Aynı değeri buradaki büyük kutuda kullanmak çizgiyi 5-6 px'e
/// çıkarıyor ve dal narin bir çizim değil, hantal bir altın leke oluyor —
/// bir kez öyle çizdik, ekranda gördük, düzelttik.
const String _sprigSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <g fill="none" stroke="#000" stroke-width="0.6"
     stroke-linecap="round" stroke-linejoin="round">
    <path d="M5 27 Q8 11 27 5 Q21 24 5 27 Z"/>
    <path d="M5 27 L27 5"/>
    <path d="M11 21 L11.5 15.5"/>
    <path d="M15 17 L16 12"/>
    <path d="M19 13 L20 9"/>
    <path d="M11 21 L16.5 20"/>
    <path d="M15 17 L20 16"/>
    <path d="M19 13 L23 12.5"/>
  </g>
</svg>
''';

class PhotoPromptIllustration extends StatelessWidget {
  const PhotoPromptIllustration({super.key});

  /// Kesikli çerçevenin kenarı.
  ///
  /// 176'DAN 224'E BÜYÜDÜ. Ekranın odak noktası bu illüstrasyon; küçükken
  /// sayfa "boş bir form" gibi duruyordu. İçindeki her şey aynı oranda
  /// büyüyor — kareler, "+" dairesi ve dallar hep [kSize]'a bağlı.
  static const double kSize = 224;

  /// Çerçevenin köşe yarıçapı — kartlarla aynı dil.
  static const Radius _kRadius = Radius.circular(24);

  /// Fotoğraf karesinin ölçüsü — kutunun ~%48'i.
  static const double _kFrameSize = kSize * 0.48;

  /// "+" dairesinin çapı.
  static const double _kPlusSize = 34;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: context.l10n.memoryPhotosIllustrationSemantics,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: kSize,
        child: CustomPaint(
          painter: _DashedBorderPainter(color: colors.outlineVariant),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // --- DALLAR: karelerin ARKASINDA, iki köşede -----------------
              //
              // Tek büyük dal yerine İKİ KÜÇÜK dal.
              //
              // NEDEN? Ortada tek bir dal, iki karenin (84 + 84, kaydırmalarla
              // ~120 genişlik) tam arkasına düşüyor ve görünmüyordu. Büyüttük,
              // bu kez kutuyu dolduran hantal bir şekle dönüştü. Köşelere
              // yerleştirilen iki küçük dal ikisini de çözüyor: kareler
              // ortayı tutuyor, dallar kenarlardan yaprak gösteriyor.
              //
              // Boyları ve saydamlıkları FARKLI — ikisi eşit olsaydı simetri
              // "desen" gibi okunurdu; asimetri onu bir çizime yaklaştırıyor.
              const Positioned(
                top: 16,
                left: 14,
                child: _Sprig(size: kSize * 0.38, angle: -0.55, alpha: 0.65),
              ),
              const Positioned(
                bottom: 18,
                right: 16,
                child: _Sprig(size: kSize * 0.27, angle: 2.5, alpha: 0.4),
              ),

              // --- ARKA KARE: hafif sola eğik ------------------------------
              Transform.translate(
                offset: const Offset(-18, -10),
                child: Transform.rotate(
                  angle: -0.14,
                  child: const _PhotoFrame(isBack: true),
                ),
              ),

              // --- ÖN KARE + "+" ------------------------------------------
              Transform.translate(
                offset: const Offset(13, 8),
                child: Transform.rotate(
                  angle: 0.06,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const _PhotoFrame(isBack: false),
                      // "+" ön karenin SAĞ ALT köşesinden taşıyor: eylemi
                      // (fotoğraf ekle) karelerin üstüne değil kenarına
                      // koyuyoruz, çizimi kapatmasın.
                      Positioned(
                        right: -_kPlusSize / 3,
                        bottom: -_kPlusSize / 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(
                            dimension: _kPlusSize,
                            child: Icon(
                              AppIcons.add,
                              size: AppIconSize.md,
                              color: colors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Altın botanik dal. Rengi temadan, boyu ve saydamlığı çağıranın kararı.
class _Sprig extends StatelessWidget {
  const _Sprig({required this.size, required this.angle, required this.alpha});

  final double size;
  final double angle;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: SvgPicture.string(
        _sprigSvg,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(
          context.colors.tertiary.withValues(alpha: alpha),
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

/// Tek bir fotoğraf karesi — içi boş, ince çerçeveli.
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({required this.isBack});

  /// Arkadaki kare bir tık daha soluk: derinlik hissini bu veriyor.
  final bool isBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        // Yükseltilmiş yüzey; koyu temada karelerin krem parlaması olmasın
        // diye renk temadan geliyor.
        color: isBack ? colors.surfaceContainer : colors.surfaceContainerLowest,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: SizedBox.square(
        dimension: PhotoPromptIllustration._kFrameSize,
        child: Center(
          child: Icon(
            AppIcons.photo,
            size: AppIconSize.lg,
            color: colors.onSurfaceVariant.withValues(
              alpha: isBack ? 0.25 : 0.45,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kesikli, yuvarlatılmış çerçeve.
///
/// Flutter'ın `Border`ı kesikli çizgi çizemiyor. Yolu `computeMetrics` ile
/// tarayıp [_kDash] uzunluğunda parçalar çıkarıyoruz; aradaki [_kGap] kadar
/// boşluk atlanıyor.
///
/// KESİKLİ ÇİZGİ NEDEN? "Buraya bir şey gelecek" demenin görsel dili bu —
/// düz bir çerçeve dolu bir kutu gibi okunur, kesikli çerçeve boşluğu ve
/// davetkârlığı birlikte anlatıyor.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  static const double _kDash = 7;
  static const double _kGap = 5;
  static const double _kStroke = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kStroke
      ..strokeCap = StrokeCap.round;

    // Çizgi kutunun İÇİNDE kalsın: `stroke` yolun iki yanına eşit dağılıyor,
    // yarım kalınlık içeri alınmazsa kenardan taşıyor.
    const inset = _kStroke / 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset,
            size.width - _kStroke,
            size.height - _kStroke,
          ),
          PhotoPromptIllustration._kRadius,
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + _kDash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _kGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
