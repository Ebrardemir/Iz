/// "Son Yazılarım" boşken gösterilen çizim: boş bir sayfa, üstünde bir kalem
/// ve yanında filiz.
///
/// NEDEN ÇİZİM?
/// Boş durum uzun bir paragraftı ve kimse okumuyordu. Boş bir listede
/// kullanıcının ihtiyacı olan şey açıklama değil DAVET: bir görsel iki
/// kelimeyle birlikte "burada bir şey olabilir" diyor. Kişiler ekranındaki
/// ayak izleriyle aynı fikir (`people_empty_illustration.dart`).
///
/// SAYFA BOŞ VE ÇİZGİLERİ KESİK: dolu bir defter "başkası yazmış" der, kesik
/// çizgiler "sıra sende". Kalem sayfanın üstünde duruyor, elde değil —
/// kullanıcıyı izlemeye değil almaya çağırıyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iz/core/extensions/context_x.dart';

/// Sayfanın yanındaki filiz — uygulamanın öteki çizimlerindeki dalın aynısı.
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

class JournalEmptyIllustration extends StatelessWidget {
  const JournalEmptyIllustration({super.key});

  /// Çizimin kenarı. Kişiler ekranındaki illüstrasyondan (272) küçük:
  /// orası ekranın tamamıydı, burası bir bölümün içi.
  static const double kSize = 132;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: context.l10n.journalEmptyIllustrationSemantics,
      image: true,
      child: SizedBox.square(
        dimension: kSize,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BlankPagePainter(
                  page: colors.surfaceContainerLowest,
                  edge: colors.outlineVariant,
                  line: colors.onSurfaceVariant.withValues(alpha: 0.35),
                  pen: colors.primary.withValues(alpha: 0.75),
                ),
              ),
            ),

            Positioned(
              right: 0,
              top: kSize * 0.04,
              child: SvgPicture.string(
                _sprigSvg,
                height: kSize * 0.52,
                colorFilter: ColorFilter.mode(
                  colors.primary.withValues(alpha: 0.45),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Boş sayfa, kesik çizgileri ve üstündeki kalem.
class _BlankPagePainter extends CustomPainter {
  const _BlankPagePainter({
    required this.page,
    required this.edge,
    required this.line,
    required this.pen,
  });

  final Color page;
  final Color edge;
  final Color line;
  final Color pen;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.08, h * 0.16, w * 0.74, h * 0.92),
      const Radius.circular(8),
    );

    canvas
      ..drawRRect(rect, Paint()..color = page)
      ..drawRRect(
        rect,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

    // KESİK ÇİZGİLER: "burası henüz yazılmadı" demenin en sessiz yolu.
    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    const dash = 7.0;
    const gap = 5.0;
    for (var i = 0; i < 4; i++) {
      final y = h * 0.30 + i * h * 0.14;
      // Son satır KISA: yarım bırakılmış bir cümlenin ritmi.
      final end = i == 3 ? w * 0.48 : w * 0.64;
      var x = w * 0.18;
      while (x < end) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + dash).clamp(0, end), y),
          linePaint,
        );
        x += dash + gap;
      }
    }

    // KALEM: sayfanın sağ alt köşesinde, hafif çapraz.
    final penPaint = Paint()
      ..color = pen
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        Offset(w * 0.44, h * 0.86),
        Offset(w * 0.80, h * 0.58),
        penPaint,
      )
      // Ucu: kalemin yönünü söyleyen küçük nokta.
      ..drawCircle(Offset(w * 0.44, h * 0.86), 3, Paint()..color = pen);
  }

  @override
  bool shouldRepaint(_BlankPagePainter oldDelegate) =>
      oldDelegate.page != page ||
      oldDelegate.edge != edge ||
      oldDelegate.line != line ||
      oldDelegate.pen != pen;
}
