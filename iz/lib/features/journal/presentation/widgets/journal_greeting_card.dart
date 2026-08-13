/// Günlük formunun karşılama kartı: solda "Merhaba" ve yazmaya davet, sağda
/// açık bir defter çizimi.
///
/// NEDEN BİR KARŞILAMA?
/// Günlük, uygulamanın en KİŞİSEL ekranı: kullanıcı buraya boş bir sayfayla
/// karşılaşmaya değil, bir şey anlatmaya geliyor. Boş bir metin kutusu ise
/// insanı susturur. Bu kart iki satırla "yazabilirsin, yeter" diyor ve
/// yanındaki defter o daveti sessizce tekrarlıyor.
///
/// DAVET CÜMLESİ HER GÜN DEĞİŞİYOR (FR-032). Tek bir sabit cümle ikinci günde
/// görünmez oluyor, üçüncüde sıkıyordu; küçük bir havuz kullanıcıyı her gün
/// başka bir kapıdan yazmaya çağırıyor (bkz. `journal_prompts.dart`).
///
/// ÇİZİM, FOTOĞRAF DEĞİL — `people_empty_illustration.dart` ile aynı üç
/// gerekçe: tek bir PNG iki temada birlikte çalışmaz, ölçek büyütünce çizgi
/// kalınlaşır ve dal markanın kendi motifi. Bütün renkler temadan geliyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';

/// Defterin yanındaki filiz — uygulamanın öteki çizimlerindeki dalın aynısı.
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

class JournalGreetingCard extends StatelessWidget {
  const JournalGreetingCard({required this.prompt, super.key});

  /// Bugünün davet cümlesi.
  ///
  /// DIŞARIDAN GELİYOR: hangi cümlenin gösterileceği güne bağlı bir karar
  /// (`journalPromptIndexFor`) ve bu widget'ın saati bilmesine gerek yok.
  final String prompt;

  /// Çizimin kenarı — referansta kartın sağ yarısını kaplıyor.
  static const double kIllustrationSize = 108;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        // Sayfa zemininden bir ton koyu: kart bir "alan" olduğunu söylemeli.
        color: colors.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.journalGreeting,
                    // SERİF — uygulamadaki tek "duygusal ses" burada yerinde:
                    // bu bir veri değil, kullanıcıya söylenen bir söz.
                    // (Anı başlığında tersini savunmuştuk; orada metin
                    // kullanıcının kendi yazdığıydı.)
                    style: context.text.headlineSmall?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    prompt,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            Semantics(
              // NFR-032 — dekoratif ama sessiz de değil.
              label: l10n.journalIllustrationSemantics,
              image: true,
              child: const SizedBox.square(
                dimension: kIllustrationSize,
                child: _NotebookIllustration(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Açık defter + filiz.
class _NotebookIllustration extends StatelessWidget {
  const _NotebookIllustration();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _NotebookPainter(
              page: colors.surfaceContainerLowest,
              line: colors.onSurfaceVariant.withValues(alpha: 0.35),
              shade: colors.onSurfaceVariant.withValues(alpha: 0.16),
            ),
          ),
        ),

        // Filiz defterin SAĞ ÜSTÜNDEN çıkıyor: referansta da dal sayfaların
        // üstüne düşüyor ve çizimi bir "masa üstü" hâline getiriyor.
        Positioned(
          right: 0,
          top: 0,
          child: SvgPicture.string(
            _sprigSvg,
            height: JournalGreetingCard.kIllustrationSize * 0.62,
            colorFilter: ColorFilter.mode(
              colors.primary.withValues(alpha: 0.5),
              BlendMode.srcIn,
            ),
          ),
        ),
      ],
    );
  }
}

/// İki sayfası açık bir defter — ortada kıvrım, sayfalarda satırlar.
class _NotebookPainter extends CustomPainter {
  const _NotebookPainter({
    required this.page,
    required this.line,
    required this.shade,
  });

  final Color page;
  final Color line;
  final Color shade;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Defter dikey ortada, alt yarıda duruyor: üst yarıyı filize bırakıyoruz.
    final top = h * 0.34;
    final bottom = h * 0.92;
    final left = w * 0.02;
    final right = w * 0.98;
    final middle = w / 2;

    // GÖLGE önce: sayfaların altında ince bir zemin, defteri havada
    // bırakmıyor.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left + 4, top + 6, right - 4, bottom + 3),
        const Radius.circular(6),
      ),
      Paint()..color = shade,
    );

    // İKİ SAYFA: dış kenarları hafif yukarı kıvrık (quadratic), iç kenarları
    // ortada birleşiyor. Düz iki dikdörtgen "kitap" değil "kart" gibi
    // duruyordu.
    Path leaf(double outerX, double innerX) => Path()
      ..moveTo(innerX, top)
      ..quadraticBezierTo(
        (innerX + outerX) / 2,
        top - h * 0.06,
        outerX,
        top + h * 0.05,
      )
      ..lineTo(outerX, bottom - h * 0.05)
      ..quadraticBezierTo(
        (innerX + outerX) / 2,
        bottom + h * 0.02,
        innerX,
        bottom,
      )
      ..close();

    final pagePaint = Paint()..color = page;
    canvas
      ..drawPath(leaf(left, middle), pagePaint)
      ..drawPath(leaf(right, middle), pagePaint);

    // Satırlar: sol sayfada üç, sağ sayfada iki — simetri fazla düzenli
    // görünüyordu, "yazılmış" bir defter biraz asimetrik olur.
    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      final y = top + h * 0.13 + i * h * 0.13;
      canvas.drawLine(
        Offset(left + w * 0.10, y),
        Offset(middle - w * 0.06, y),
        linePaint,
      );
    }
    for (var i = 0; i < 2; i++) {
      final y = top + h * 0.15 + i * h * 0.13;
      canvas.drawLine(
        Offset(middle + w * 0.06, y),
        Offset(right - w * 0.12, y),
        linePaint,
      );
    }

    // Ortadaki kıvrım en son: sayfaların üstünde kalmalı.
    canvas.drawLine(
      Offset(middle, top),
      Offset(middle, bottom),
      Paint()
        ..color = shade
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_NotebookPainter oldDelegate) =>
      oldDelegate.page != page ||
      oldDelegate.line != line ||
      oldDelegate.shade != shade;
}
