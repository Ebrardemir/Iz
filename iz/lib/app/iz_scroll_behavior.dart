/// Uygulamanın kaydırma davranışı — HER PLATFORMDA AYNI.
///
/// SORUN NEYDİ?
/// Flutter, kaydırma hissini çalıştığı platforma göre değiştirir:
///   • Android → listenin sonunda içerik ESNER (Material 3 "stretch"),
///     eski sürümlerde kenarda mavi bir parıltı belirir.
///   • iOS     → içerik yaylanarak geri döner (bounce).
/// Aynı uygulama iki platformda iki farklı karakterde davranıyordu; üstelik
/// Android'in esneme/parıltı efekti Material'ın kendi dili, İZ'in değil.
///
/// KARAR: hiçbir kenar efekti YOK. Liste sonunda içerik durur, o kadar.
///
/// NEDEN?
///   • Esneme de yaylanma da dikkat çekiyor ve kendini gösteriyor; İZ'in
///     dili sakin, içerik önde olmalı.
///   • İki platformda tek davranış: tasarımı bir cihazda görüp ötekinde
///     sürpriz yaşamıyoruz.
///   • `ClampingScrollPhysics` en sade seçenek — parmak nereye götürürse
///     içerik oraya gider, sınırda net biçimde durur.
///
/// `AlwaysScrollableScrollPhysics` sarmalı ŞART: onsuz, içeriği ekrana
/// sığan sayfalar hiç kaydırılamaz.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class IzScrollBehavior extends MaterialScrollBehavior {
  const IzScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());

  /// Android'in esneme/parıltı göstergesini kaldırır.
  ///
  /// Fizik zaten sınırda durduruyor; göstergeye gerek yok.
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  /// Fare ve dokunmatik kalemle de kaydırılabilsin.
  ///
  /// Varsayılanda masaüstünde fareyle sürükleyerek kaydırma kapalı; İZ
  /// ileride masaüstünde de açılabilir ve bu satır o gün işi kolaylaştırır.
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}
