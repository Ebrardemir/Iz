/// Kapak alanındaki çizim: uzak dağlar, soluk bir güneş, iki bulut ve sağda
/// uygulamanın kendi zeytin dalı. Fotoğraf seçilmemişken görünüyor.
///
/// NE ANLATIYOR?
/// Bir MANZARA, bir ikon değil. Bu alan bir fotoğrafın yerini tutuyor; oraya
/// bir "resim ekle" ikonu koymak kutuyu bir düğmeye çevirirdi. Yumuşak
/// katmanlı dağlar "burada bir görsel olacak" diyor ve seçilen fotoğrafın
/// yerini gözde şimdiden hazırlıyor.
///
/// NEDEN ÇİZİM, NEDEN ASSET DEĞİL?
/// `people_empty_illustration.dart` ile aynı üç gerekçe: tek bir PNG iki
/// temada birlikte çalışmaz, ölçek büyütünce çizgi kalınlaşır ve dal markanın
/// kendi motifi. Bütün renkler temadan geliyor.
///
/// KATMAN SIRASI önemli: gökyüzü → güneş → bulutlar → arka dağlar → ön dağlar
/// → dal. Güneş dağların ARKASINDA kalıyor; öne alınsa illüstrasyon bir çocuk
/// çizimine dönüyordu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iz/core/extensions/context_x.dart';

/// Zeytin dalı — `people_empty_illustration.dart`taki filizin aynısı.
///
/// ⚠️ `stroke-width` 0.6: çizgi kalınlığı viewBox'la ÖLÇEKLENİYOR, logodaki
/// 1.1 bu boyda hantal bir lekeye dönüşüyor (o hatayı bir kez yaptık).
const String _branchSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 48">
  <g fill="none" stroke="#000" stroke-width="0.6"
     stroke-linecap="round" stroke-linejoin="round">
    <path d="M16 47 C16 32 14 18 11 4"/>
    <path d="M14 36 C9 35 6 31 6 27 C11 27 14 31 14 36 Z"/>
    <path d="M15 29 C20 28 23 24 23 20 C18 20 15 24 15 29 Z"/>
    <path d="M13 22 C8 21 5 17 5 13 C10 13 13 17 13 22 Z"/>
    <path d="M13 15 C18 14 21 10 21 6 C16 6 13 10 13 15 Z"/>
  </g>
</svg>
''';

class IzCoverIllustration extends StatelessWidget {
  const IzCoverIllustration({super.key});

  /// Dalın kutuya oranı — referansta sağ kenara yakın ve kutunun neredeyse
  /// tamamı kadar uzun.
  /// (0.70 + aşağıdaki 0.20 = 0.90: dal kutunun üst kenarına DEĞMİYOR.
  /// 0.78 + 0.22 = 1.0 denendi ve dalın tepesi kırpılıyordu.)
  static const double _kBranchHeightRatio = 0.70;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      // NFR-032 — dekoratif ama boş da değil: ekran okuyucu kullanıcısı burada
      // bir görsel olduğunu bilmeli, yoksa "Kapak Görseli Ekle" metni havada
      // kalıyor.
      label: context.l10n.coverIllustrationSemantics,
      image: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;

          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _LandscapePainter(
                  // Üç ayrı doluluk: uzaklık rengin AÇIKLIĞIYLA anlatılıyor,
                  // çizgiyle değil.
                  far: colors.onSurfaceVariant.withValues(alpha: 0.10),
                  near: colors.onSurfaceVariant.withValues(alpha: 0.18),
                  sun: colors.onSurfaceVariant.withValues(alpha: 0.13),
                ),
              ),

              // Dal SAĞDA ve tabanı dağların içine giriyor: havada duran bir
              // dal yapıştırılmış gibi görünüyordu.
              //
              // YUKARI ÇEKİLDİ (`bottom` büyük): eklemek düğmesi sağ altta
              // duruyor ve dal onun üstüne binince ikisi birbirini yiyordu.
              Positioned(
                right: constraints.maxWidth * 0.04,
                bottom: height * 0.20,
                child: SvgPicture.string(
                  _branchSvg,
                  height: height * _kBranchHeightRatio,
                  colorFilter: ColorFilter.mode(
                    colors.primary.withValues(alpha: 0.45),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Dağlar, güneş ve bulutlar.
class _LandscapePainter extends CustomPainter {
  const _LandscapePainter({
    required this.far,
    required this.near,
    required this.sun,
  });

  final Color far;
  final Color near;
  final Color sun;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- GÜNEŞ: dağların arkasında, sol-ortada ---------------------------
    canvas.drawCircle(
      Offset(w * 0.40, h * 0.30),
      h * 0.10,
      Paint()..color = sun,
    );

    // --- BULUTLAR: üst üste binen üç daireden ----------------------------
    void cloud(double cx, double cy, double r) {
      final paint = Paint()..color = far;
      canvas
        ..drawCircle(Offset(cx - r * 0.8, cy), r * 0.7, paint)
        ..drawCircle(Offset(cx, cy - r * 0.2), r, paint)
        ..drawCircle(Offset(cx + r * 0.9, cy), r * 0.65, paint)
        // Alt kenarı düzleştiren dikdörtgen: dairelerin altındaki girintiler
        // bulutu bir üzüm salkımı gibi gösteriyordu.
        ..drawRect(
          Rect.fromLTRB(cx - r * 1.5, cy, cx + r * 1.55, cy + r * 0.7),
          paint,
        );
    }

    cloud(w * 0.2, h * 0.22, h * 0.055);
    cloud(w * 0.68, h * 0.16, h * 0.045);

    // --- DAĞLAR ----------------------------------------------------------
    // Zirve YUVARLATILMIŞ (`quadraticBezierTo`): keskin üçgenler bu yumuşak
    // paletin içinde sert duruyordu.
    Path peak(double cx, double peakY, double halfWidth) => Path()
      ..moveTo(cx - halfWidth, h)
      ..quadraticBezierTo(cx - halfWidth * 0.3, peakY, cx, peakY)
      ..quadraticBezierTo(cx + halfWidth * 0.3, peakY, cx + halfWidth, h)
      ..close();

    canvas
      // Arkadaki iki tepe daha açık: derinlik böyle kuruluyor.
      ..drawPath(peak(w * 0.30, h * 0.42, w * 0.24), Paint()..color = far)
      ..drawPath(peak(w * 0.78, h * 0.38, w * 0.26), Paint()..color = far)
      // Öndeki tepe en koyu ve en geniş — bakışın oturduğu yer.
      ..drawPath(peak(w * 0.55, h * 0.30, w * 0.34), Paint()..color = near);
  }

  @override
  bool shouldRepaint(_LandscapePainter oldDelegate) =>
      oldDelegate.far != far ||
      oldDelegate.near != near ||
      oldDelegate.sun != sun;
}
