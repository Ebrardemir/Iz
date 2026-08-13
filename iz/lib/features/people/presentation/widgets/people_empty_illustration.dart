/// "Henüz kişi yok" ekranının illüstrasyonu: yumuşak bir kubbenin altında
/// üç figür, iki yanda birer dal, altta soluk bir zemin.
///
/// NE ANLATIYOR?
/// Kubbe bir sığınak: figürler onun ALTINDA duruyor, önünde değil. Ortadaki
/// figür daha küçük ve daha koyu — yani en öndeki, en korunan. "Hayatındaki
/// insanlar" fikri bir liste ikonuyla değil, bu ilişkiyle anlatılıyor.
///
/// NEDEN ÇİZİM, NEDEN ASSET DEĞİL?
///   • Tek bir PNG iki temada da çalışmaz: koyu temada krem yüzeyler parlar.
///     Widget'la çizince bütün renkler temadan geliyor.
///   • Ölçek bozulmuyor — vektör bile olsa bir asset'in çizgi kalınlığı
///     büyütünce kalınlaşır.
///   • Dal, markanın kendi motifi (`iz_wordmark.dart`'taki filizle ve
///     `photo_prompt_illustration.dart`'taki dalla aynı dil).
///
/// ⚠️ SVG `stroke-width` 0.6, 1.1 DEĞİL. Çizgi kalınlığı viewBox'la
/// ÖLÇEKLENİYOR: logodaki 1.1 küçük kutuda zarif bir çizgi verirken buradaki
/// büyük kutuda 5-6 piksellik hantal bir lekeye dönüşüyor. Aynı hatayı bir kez
/// fotoğraf adımının illüstrasyonunda yapıp ekranda görüp düzelttik.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iz/core/extensions/context_x.dart';

/// İnce konturlu botanik dal.
const String _sprigSvg = '''
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

class PeopleEmptyIllustration extends StatelessWidget {
  const PeopleEmptyIllustration({super.key});

  /// Kutunun kenarı.
  ///
  /// Referansta illüstrasyon ekran genişliğinin ~%70'i; 390 piksellik bir
  /// telefonda 272. Sabit veriyoruz ama ekran dar olursa küçülüyor
  /// (bkz. `build`) — küçük telefonlarda metni aşağı itmesin.
  static const double kSize = 272;

  /// Kubbenin kutuya oranı.
  static const double _kDomeWidth = 0.76;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Dar ekranda küçülsün: 272 sabit kalsaydı 320 piksellik bir telefonda
    // illüstrasyon metni ekrandan aşağı iterdi.
    final side = MediaQuery.sizeOf(context).width * 0.7;
    final size = side < kSize ? side : kSize;

    return Semantics(
      label: context.l10n.peopleIllustrationSemantics,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Kubbe + figürler + zemin: hepsi tek boyayıcı, çünkü sıraları
            // (arkadan öne) bir kompozisyon kararı ve ayrı widget'lara
            // bölünürse o sıra ağaç yapısına dağılıyor.
            CustomPaint(
              size: Size.square(size),
              painter: _PeopleScenePainter(
                dome: colors.surfaceContainerHighest,
                ground: colors.surfaceContainerHigh,
                figure: colors.onSurfaceVariant.withValues(alpha: 0.42),
                accent: colors.onSurfaceVariant.withValues(alpha: 0.58),
                halo: colors.surface,
              ),
            ),

            // Dallar EN ÖNDE ve figürlerin iki yanında: kompozisyonu
            // çerçeveliyorlar, kubbenin içine girmiyorlar.
            Positioned(
              left: size * 0.02,
              bottom: size * 0.08,
              child: _Sprig(height: size * 0.30, color: colors.primary),
            ),
            Positioned(
              right: size * 0.02,
              bottom: size * 0.08,
              child: _Sprig(
                height: size * 0.30,
                color: colors.primary,
                flipped: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sprig extends StatelessWidget {
  const _Sprig({
    required this.height,
    required this.color,
    this.flipped = false,
  });

  final double height;
  final Color color;
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    final sprig = SvgPicture.string(
      _sprigSvg,
      height: height,
      // Dal DEKOR: markanın yeşilinin soluk hâli. Tam doygun yeşil,
      // arkadaki figürlerden daha güçlü çıkıp gözü kenarlara çekiyordu.
      colorFilter: ColorFilter.mode(
        color.withValues(alpha: 0.35),
        BlendMode.srcIn,
      ),
    );

    // Sağdaki dal solunun AYNASI: ikinci bir SVG yazmak yerine çeviriyoruz,
    // böylece iki dal birbirinden ayrışamaz.
    if (!flipped) return sprig;
    return Transform.flip(flipX: true, child: sprig);
  }
}

/// Kubbe, zemin ve üç figür.
class _PeopleScenePainter extends CustomPainter {
  const _PeopleScenePainter({
    required this.dome,
    required this.ground,
    required this.figure,
    required this.accent,
    required this.halo,
  });

  final Color dome;
  final Color ground;

  /// Yandaki iki figür.
  final Color figure;

  /// Ortadaki figür — bir tık koyu.
  final Color accent;

  /// Ortadaki figürü arkadakilerden ayıran ince kontur.
  final Color halo;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- Kubbe ------------------------------------------------------------
    //
    // Tam yarım daire DEĞİL: üstü daire, altı dikey iki kenar. Referanstaki
    // biçim bu ve fark önemli — tam yarım daire bir "balon", bu ise bir
    // "sığınak" gibi okunuyor.
    final domeWidth = w * PeopleEmptyIllustration._kDomeWidth;
    final domeLeft = (w - domeWidth) / 2;
    final domeBottom = h * 0.84;
    // Kubbe ALÇAK ve GENİŞ. Daha dik bir kemer denedik; figürleri sarmak
    // yerine üstlerinde yükselen bir kule gibi duruyordu.
    final domeTop = h * 0.16;
    final radius = domeWidth / 2;

    final domePath = Path()
      ..moveTo(domeLeft, domeBottom)
      ..lineTo(domeLeft, domeTop + radius)
      ..arcToPoint(
        Offset(domeLeft + domeWidth, domeTop + radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(domeLeft + domeWidth, domeBottom)
      ..close();

    canvas.drawPath(domePath, Paint()..color = dome);

    // --- Zemin -------------------------------------------------------------
    //
    // Kubbeden GENİŞ: figürler bir yüzeye basıyor ve o yüzey kubbenin
    // dışına taşıyor — kompozisyon havada durmuyor.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, domeBottom),
        width: w * 0.90,
        height: h * 0.13,
      ),
      Paint()..color = ground,
    );

    // --- Figürler ----------------------------------------------------------
    //
    // Sıra ARKADAN ÖNE: yandakiler, sonra ortadaki. Ortadaki en son çiziliyor
    // ki halosu ötekilerin üstünde kalsın.
    final baseline = domeBottom - h * 0.01;

    // İKİSİ AYNI ÖLÇÜDE DEĞİL: birkaç piksellik fark, çizimi simetrik bir
    // ikondan çıkarıp bir sahneye çeviriyor.
    _figure(
      canvas,
      center: w * 0.33,
      baseline: baseline,
      scale: 0.33,
      size: size,
      color: figure,
    );
    _figure(
      canvas,
      center: w * 0.67,
      baseline: baseline,
      scale: 0.31,
      size: size,
      color: figure,
    );

    // Ortadaki: daha KÜÇÜK ve daha KOYU — en öndeki, en korunan.
    _figure(
      canvas,
      center: w * 0.50,
      baseline: baseline,
      scale: 0.225,
      size: size,
      color: accent,
      haloColor: halo,
    );
  }

  /// Tek figür: daire kafa + üstü yuvarlatılmış gövde.
  ///
  /// [scale] figürün toplam yüksekliğinin kutuya oranı.
  void _figure(
    Canvas canvas, {
    required double center,
    required double baseline,
    required double scale,
    required Size size,
    required Color color,
    Color? haloColor,
  }) {
    final total = size.height * scale;
    final headRadius = total * 0.30;
    final bodyWidth = headRadius * 2.55;
    final bodyTop = baseline - (total - headRadius * 2) - total * 0.04;

    final body = RRect.fromRectAndCorners(
      Rect.fromLTRB(
        center - bodyWidth / 2,
        bodyTop,
        center + bodyWidth / 2,
        baseline,
      ),
      // Üst köşeler tam yuvarlak (omuz), alt köşeler düz (zemine basıyor).
      topLeft: Radius.circular(bodyWidth / 2),
      topRight: Radius.circular(bodyWidth / 2),
    );
    final headCenter = Offset(center, bodyTop - headRadius * 0.85);

    // Halo: ortadaki figürü arkadakilerden ayıran ince kontur. Şekilleri
    // biraz büyük çizip ALTINA koyuyoruz — `stroke` kullanmak köşelerde
    // kırılıyordu.
    if (haloColor != null) {
      final grow = total * 0.035;
      canvas
        ..drawRRect(body.inflate(grow), Paint()..color = haloColor)
        ..drawCircle(headCenter, headRadius + grow, Paint()..color = haloColor);
    }

    final paint = Paint()..color = color;
    canvas
      ..drawRRect(body, paint)
      ..drawCircle(headCenter, headRadius, paint);
  }

  @override
  bool shouldRepaint(_PeopleScenePainter oldDelegate) =>
      oldDelegate.dome != dome ||
      oldDelegate.ground != ground ||
      oldDelegate.figure != figure ||
      oldDelegate.accent != accent ||
      oldDelegate.halo != halo;
}
