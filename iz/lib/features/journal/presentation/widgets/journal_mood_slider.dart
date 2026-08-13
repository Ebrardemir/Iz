/// "Bugün kendini nasıl hissediyorsun?" — 1..10 arası kaydırıcı.
///
/// UCU KALP ŞEKLİNDE VE İÇİNDE SAYI VAR (kullanıcının isteği, referansta da
/// böyle). Material'ın yuvarlak topuzu bir ayar düğmesi gibi duruyor; kalp
/// bu ölçeğin bir ayar değil bir HÂL olduğunu söylüyor. Sayı topuzun içinde
/// çünkü kullanıcı parmağını kaldırmadan hangi değerde olduğunu görmeli —
/// altta ayrı bir rakam olsaydı parmağın altında kalırdı.
///
/// ONDALIK YOK, 10 ADIM VAR (`divisions: 9`): "7,3 hissediyorum" diye bir şey
/// yok. Adımlar aynı zamanda dokunmayı bağışlayıcı yapıyor — parmak kabaca
/// doğru yere düşse yeter.
///
/// SEÇİLMEMİŞ HÂLİ VAR: [value] null ise kaydırıcı ortada duruyor ama kalp
/// SOLUK ve kayıt puansız gidiyor. "Hiç işaretlemedim" ile "5 hissettim" aynı
/// şey değil; ortadaki bir değeri varsayılan saymak kullanıcının adına
/// konuşmak olurdu.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';

class JournalMoodSlider extends StatelessWidget {
  const JournalMoodSlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 1..10 arası puan; null = kullanıcı henüz dokunmadı.
  final int? value;

  final ValueChanged<int> onChanged;

  static const int kMin = 1;
  static const int kMax = 10;

  /// Ölçeğin ortası — henüz seçim yokken topuzun durduğu yer.
  static const double _kNeutral = (kMin + kMax) / 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final current = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.journalMoodQuestion,
          style: context.text.titleMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: colors.primary,
                  inactiveTrackColor: colors.outlineVariant,
                  // Adım noktaları KAPALI: on nokta çizgiyi kesik kesik
                  // gösterip referanstaki yumuşak şeridi bozuyordu.
                  activeTickMarkColor: Colors.transparent,
                  inactiveTickMarkColor: Colors.transparent,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 24,
                  ),
                  thumbShape: _HeartThumbShape(
                    label: current == null ? '' : '$current',
                    // Seçilmemişken soluk: kalp orada ama "bu senin değerin"
                    // demiyor.
                    fill: current == null
                        ? colors.outlineVariant
                        : colors.primary,
                    textColor: current == null
                        ? colors.onSurfaceVariant
                        : colors.onPrimary,
                    textStyle: context.text.labelMedium,
                  ),
                ),
                child: Semantics(
                  // Ekran okuyucu için değer metni: Material'ın kendi
                  // etiketi yalnızca sayıyı okuyor, neyin sayısı olduğunu
                  // söylemiyor.
                  label: l10n.journalMoodSemantics(current ?? 0),
                  child: Slider(
                    value: (current ?? _kNeutral).toDouble(),
                    min: kMin.toDouble(),
                    max: kMax.toDouble(),
                    // On değer, dokuz aralık.
                    divisions: kMax - kMin,
                    onChanged: (raw) => onChanged(raw.round()),
                  ),
                ),
              ),
            ),
          ],
        ),

        // UÇLARDA SAYI DEĞİL SÖZCÜK.
        //
        // Önce "1 en zor, 10 en iyi hissettiğin an." yazıyordu: bir ölçeği
        // tarif etmek için kullanılan, kullanıcıya hiçbir şey hissettirmeyen
        // bir cümle. Sayının ne demek olduğunu iki kelime zaten söylüyor ve
        // rakamın kendisi kalbin içinde duruyor.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // FLEXIBLE: 2x yazı ölçeğinde iki etiket satırı 19 piksel
              // taşırıyordu. Kırpmak yerine ALT SATIRA geçiyorlar — kısa
              // cümleler ve ortadan kesilmiş bir "Zorlu bir gü…" hiçbir şey
              // anlatmaz.
              Flexible(child: _ScaleEnd(label: l10n.journalMoodLow)),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: _ScaleEnd(
                  label: l10n.journalMoodHigh,
                  align: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ölçeğin iki ucundaki rakam.
class _ScaleEnd extends StatelessWidget {
  const _ScaleEnd({required this.label, this.align = TextAlign.start});

  final String label;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
    label,
    textAlign: align,
    style: context.text.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    ),
  );
}

/// Kalp biçimli topuz — içinde seçili sayı.
class _HeartThumbShape extends SliderComponentShape {
  const _HeartThumbShape({
    required this.label,
    required this.fill,
    required this.textColor,
    required this.textStyle,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final TextStyle? textStyle;

  /// Kalbin kutusu. NFR-033'ün dokunma hedefi kaydırıcının kendi kulvarından
  /// geliyor; buradaki ölçü yalnızca görsel.
  static const double _kSize = 34;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(_kSize);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // GÖLGE: kalp şeridin üstünde duruyor ve aynı yeşilin koyusu olduğu için
    // sınırı kaybolabiliyordu.
    canvas.drawShadow(_heartPath(center, _kSize * 1.02), Colors.black, 2, true);
    canvas.drawPath(_heartPath(center, _kSize), Paint()..color = fill);

    if (label.isEmpty) return;

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: (textStyle ?? const TextStyle()).copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: textDirection,
      textAlign: TextAlign.center,
    )..layout();

    // Sayı kalbin geometrik ortasının biraz ÜSTÜNDE: alt uç sivrildiği için
    // gövdenin ağırlığı yukarıda ve tam merkez göze aşağı kaymış görünüyor.
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2 + _kSize * 0.05),
    );
  }

  /// [size] kenarlı bir kutuya sığan kalp.
  ///
  /// İKİ YUMRU ÜSTTE, SİVRİ UÇ ALTTA. (İlk yazışta kontrol noktaları ters
  /// düştü ve kalp baş aşağı çizildi — ekranda görüp düzelttik.)
  ///
  /// Emoji ya da ikon kullanmadık: ikonun içine sayı yazmak için yine elle
  /// çizmek gerekiyordu ve ikon setinin kalbi (`AppIcons.favorite`) İÇİ BOŞ
  /// bir kontur — burada dolu bir topuz lazım.
  Path _heartPath(Offset center, double size) {
    final w = size;
    final h = size * 0.92;
    final x = center.dx - w / 2;
    final y = center.dy - h / 2;

    return Path()
      // Üstteki çentikten başlıyoruz.
      ..moveTo(x + w * 0.50, y + h * 0.32)
      // Sol yumru
      ..cubicTo(
        x + w * 0.50,
        y + h * 0.08,
        x + w * 0.06,
        y + h * 0.06,
        x + w * 0.06,
        y + h * 0.36,
      )
      // Sol yandan sivri uca
      ..cubicTo(
        x + w * 0.06,
        y + h * 0.60,
        x + w * 0.30,
        y + h * 0.74,
        x + w * 0.50,
        y + h * 0.96,
      )
      // Uçtan sağ yana
      ..cubicTo(
        x + w * 0.70,
        y + h * 0.74,
        x + w * 0.94,
        y + h * 0.60,
        x + w * 0.94,
        y + h * 0.36,
      )
      // Sağ yumru
      ..cubicTo(
        x + w * 0.94,
        y + h * 0.06,
        x + w * 0.50,
        y + h * 0.08,
        x + w * 0.50,
        y + h * 0.32,
      )
      ..close();
  }
}
