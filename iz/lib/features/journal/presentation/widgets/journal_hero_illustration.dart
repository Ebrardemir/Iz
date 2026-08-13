/// Günlük ana sayfasındaki karşılama kartının çizimi: bir masa, üstünde açık
/// bir defter, kalemi ve yanında kahve.
///
/// NEDEN FOTOĞRAF DEĞİL?
/// Önce anı önizlemesinden ödünç bir fotoğraf vardı; kalabalıktı ve günlükle
/// ilgisi yoktu. Doğru fotoğraf da tek başına yetmezdi: koyu bir kare beyaz
/// yazı, açık bir kare koyu yazı ister ve fotoğraf değiştiği gün metnin
/// okunurluğu kaybolur. Çizimde bütün renkler temadan geliyor, iki temada da
/// çalışıyor ve sahneyi biz kuruyoruz — "sade, kitaplı, kahveli".
///
/// SAHNE SOLDA BOŞ: metin oraya oturuyor. Defter ve fincan sağ yarıda duruyor
/// ki başlık ile düğme çizimin üstüne binmesin.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iz/core/extensions/context_x.dart';

/// Fincanın arkasındaki filiz — uygulamanın öteki çizimlerindeki dalın aynısı.
///
/// ⚠️ `stroke-width` 0.6: çizgi kalınlığı viewBox'la ÖLÇEKLENİYOR.
const String _sprigSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 48">
  <g fill="none" stroke="#000" stroke-width="0.6"
     stroke-linecap="round" stroke-linejoin="round">
    <path d="M16 47 C16 32 14 18 11 4"/>
    <path d="M14 36 C9 35 6 31 6 27 C11 27 14 31 14 36 Z"/>
    <path d="M15 29 C20 28 23 24 23 20 C18 20 15 24 15 29 Z"/>
    <path d="M13 22 C8 21 5 17 5 13 C10 13 13 17 13 22 Z"/>
  </g>
</svg>
''';

class JournalHeroIllustration extends StatelessWidget {
  const JournalHeroIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colors.surfaceContainerHigh),

          CustomPaint(
            painter: _DeskPainter(
              // Üç doluluk: masa, kâğıt ve koyu detay. Renkler temadan
              // geldiği için koyu temada da sahne bozulmuyor.
              desk: colors.onSurfaceVariant.withValues(alpha: 0.16),
              paper: colors.surfaceContainerLowest,
              ink: colors.onSurfaceVariant.withValues(alpha: 0.55),
              cup: colors.primary.withValues(alpha: 0.85),
            ),
          ),

          // Filiz fincanın ARKASINDAN çıkıyor: sahneyi masaya oturtan detay.
          Positioned(
            right: constraints.maxWidth * 0.02,
            bottom: constraints.maxHeight * 0.30,
            child: SvgPicture.string(
              _sprigSvg,
              height: constraints.maxHeight * 0.46,
              colorFilter: ColorFilter.mode(
                colors.primary.withValues(alpha: 0.40),
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Masa yüzeyi, açık defter, kalem ve kahve fincanı.
class _DeskPainter extends CustomPainter {
  const _DeskPainter({
    required this.desk,
    required this.paper,
    required this.ink,
    required this.cup,
  });

  final Color desk;
  final Color paper;
  final Color ink;
  final Color cup;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- MASA: alt üçte bir, yumuşak bir bant --------------------------
    canvas.drawRect(Rect.fromLTRB(0, h * 0.66, w, h), Paint()..color = desk);

    // --- DEFTER: sağ yarıda, hafif eğik iki sayfa ----------------------
    // Eğim `Canvas.rotate` ile değil doğrudan yolla veriliyor: dönmüş bir
    // katman gölgeyi de döndürüyor ve sahne yamuk görünüyordu.
    // Defter SAĞ ÜÇTE İKİDE: metin sütunu soldaki %62'yi kaplıyor ve ikisi
    // üst üste binmemeli.
    final bookLeft = w * 0.60;
    final bookRight = w * 0.94;
    final bookTop = h * 0.44;
    final bookBottom = h * 0.80;
    final spine = (bookLeft + bookRight) / 2;

    Path leaf(double outerX) => Path()
      ..moveTo(spine, bookTop + h * 0.02)
      ..quadraticBezierTo(
        (spine + outerX) / 2,
        bookTop - h * 0.03,
        outerX,
        bookTop + h * 0.05,
      )
      ..lineTo(outerX, bookBottom - h * 0.03)
      ..quadraticBezierTo(
        (spine + outerX) / 2,
        bookBottom + h * 0.03,
        spine,
        bookBottom,
      )
      ..close();

    final paperPaint = Paint()..color = paper;
    canvas
      ..drawPath(leaf(bookLeft), paperPaint)
      ..drawPath(leaf(bookRight), paperPaint);

    // Sayfa satırları — solda üç, sağda iki. Tam simetri "yazılmış" değil
    // "basılmış" bir defter gibi duruyordu.
    final linePaint = Paint()
      ..color = ink.withValues(alpha: 0.30)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      final y = bookTop + h * 0.07 + i * h * 0.06;
      canvas.drawLine(
        Offset(bookLeft + w * 0.03, y),
        Offset(spine - w * 0.02, y),
        linePaint,
      );
    }
    for (var i = 0; i < 2; i++) {
      final y = bookTop + h * 0.08 + i * h * 0.06;
      canvas.drawLine(
        Offset(spine + w * 0.02, y),
        Offset(bookRight - w * 0.04, y),
        linePaint,
      );
    }

    // Kıvrım
    canvas.drawLine(
      Offset(spine, bookTop + h * 0.02),
      Offset(spine, bookBottom),
      Paint()
        ..color = ink.withValues(alpha: 0.22)
        ..strokeWidth = 1.4,
    );

    // --- KALEM: defterin üstünde, hafif çapraz ------------------------
    final penPaint = Paint()
      ..color = ink
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(spine - w * 0.04, bookBottom - h * 0.04),
      Offset(bookRight - w * 0.03, bookBottom - h * 0.17),
      penPaint,
    );
    // Ucu: kalemin hangi yönde olduğunu söyleyen küçük koyu nokta.
    canvas.drawCircle(
      Offset(spine - w * 0.04, bookBottom - h * 0.04),
      2.6,
      Paint()..color = ink,
    );

    // --- FİNCAN: solda, defterin biraz önünde -------------------------
    final cupPaint = Paint()..color = cup;
    // Fincan defterin SOLUNDA ve biraz önünde; ikisi birlikte bir masa
    // köşesi kuruyor.
    final cupLeft = w * 0.44;
    final cupRight = w * 0.58;
    final cupTop = h * 0.56;
    final cupBottom = h * 0.76;

    // Gövde: aşağı doğru hafif daralan bir kap.
    final body = Path()
      ..moveTo(cupLeft, cupTop)
      ..lineTo(cupRight, cupTop)
      ..lineTo(cupRight - (cupRight - cupLeft) * 0.14, cupBottom)
      ..quadraticBezierTo(
        (cupLeft + cupRight) / 2,
        cupBottom + h * 0.03,
        cupLeft + (cupRight - cupLeft) * 0.14,
        cupBottom,
      )
      ..close();
    canvas.drawPath(body, cupPaint);

    // Kulp: gövdeye BİTİŞİK bir yay. Önce biraz uzaktaydı ve fincandan
    // kopuk, havada duran bir çizgi gibi görünüyordu.
    canvas.drawArc(
      Rect.fromLTWH(
        cupRight - (cupRight - cupLeft) * 0.30,
        cupTop + h * 0.03,
        (cupRight - cupLeft) * 0.52,
        h * 0.09,
      ),
      -1.1,
      2.2,
      false,
      Paint()
        ..color = cup
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // Kahvenin yüzeyi: gövdeden bir ton açık ince bir elips.
    canvas.drawOval(
      Rect.fromLTWH(cupLeft + 3, cupTop - 3, cupRight - cupLeft - 6, h * 0.045),
      Paint()..color = paper.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_DeskPainter oldDelegate) =>
      oldDelegate.desk != desk ||
      oldDelegate.paper != paper ||
      oldDelegate.ink != ink ||
      oldDelegate.cup != cup;
}
