/// Üst kenarı KAVİSLİ olan panel.
///
/// Ana sayfada fotoğrafın üzerine binen içerik alanı bununla çiziliyor.
/// Giriş/kayıt ekranlarındaki panelden farkı: orada köşeler yuvarlak,
/// burada kenarın TAMAMI tek bir eğri.
///
/// KAVİS SİMETRİK DEĞİL. Referans tasarımda kenar solda en aşağıda başlar,
/// ortaya doğru yavaşça yükselip düzleşir, sağ tarafta ise dik bir hamleyle
/// yukarı çıkar — yani fotoğrafın SAĞ tarafı kısa kalır.
///
/// ÖLÇÜ NEREDEN GELİYOR?
/// Figma katmanı 390 × 66.544 diyor ve bu doğru: referans ekran görüntüsünde
/// kenarı sütun sütun ölçtük, içerik 326 px genişken toplam düşey fark 56 px
/// çıktı — 390 px'e ölçeklenince 67 px. [_curveRatio] bu.
///
/// Eğrinin ŞEKLİ de tahmin değil: aynı ölçüme kübik Bézier oturtuldu,
/// ortalama sapma 0.58 piksel. Kontrol noktaları [_c1x]…[_c2y].
///
/// Sabit piksel yerine ORAN kullanıyoruz; böylece dar telefonda da geniş
/// ekranda da kavis aynı karakterde kalır. Uç ölçülerde oran abartıya
/// kaçmasın diye alt/üst sınır var.
library;

import 'package:flutter/material.dart';

class CurvedTopPanel extends StatelessWidget {
  const CurvedTopPanel({required this.color, required this.child, super.key});

  final Color color;
  final Widget child;

  /// Figma: 66.544 / 390 ≈ 0.1706 (referans ölçümüyle doğrulandı: 56 / 326).
  static const double _curveRatio = 66.544 / 390;

  static const double _minCurve = 48;
  static const double _maxCurve = 100;

  /// Kavisin toplam düşey yüksekliği: en alçak nokta (SOL uç) ile en yüksek
  /// nokta (SAĞ uç) arasındaki fark.
  ///
  /// İçeriği yerleştirirken lazım: en alçak nokta sol uç olduğu için içerik
  /// bu kadar aşağıdan başlamalı, yoksa solda kırpılır.
  static double curveHeightFor(double width) =>
      (width * _curveRatio).clamp(_minCurve, _maxCurve);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipPath(
          clipper: _CurveClipper(curveHeightFor(constraints.maxWidth)),
          child: ColoredBox(color: color, child: child),
        );
      },
    );
  }
}

/// Üst kenarı tek bir kübik Bézier olan kırpıcı.
///
/// KOORDİNATLAR (panelin kendi içinde, y aşağı doğru artar):
///   başlangıç : (0, h)      → SOL uç, kavisin en alçak noktası
///   bitiş     : (w, 0)      → SAĞ uç, kavisin en yüksek noktası
///
/// Kontrol noktaları referans ölçümünden fit edildi; ikinci kontrol
/// noktasının y'si h'yi biraz aşıyor (1.08·h) ama eğri h'yi geçmiyor —
/// bu, sağ taraftaki dik yükselişi veren şey.
class _CurveClipper extends CustomClipper<Path> {
  const _CurveClipper(this.curveHeight);

  final double curveHeight;

  static const double _c1x = 0.57;
  static const double _c1y = 0.27;
  static const double _c2x = 0.84;
  static const double _c2y = 1.08;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = curveHeight;
    return Path()
      ..moveTo(0, h)
      ..cubicTo(_c1x * w, _c1y * h, _c2x * w, _c2y * h, w, 0)
      ..lineTo(w, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_CurveClipper oldClipper) =>
      oldClipper.curveHeight != curveHeight;
}
