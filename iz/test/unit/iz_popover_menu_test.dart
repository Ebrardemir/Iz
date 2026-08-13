/// Popover menünün YERLEŞİM kuralları.
///
/// Ekran kenarına yakın bir satırda menünün nereye gideceği kolayca yanlış
/// yazılan bir hesap ve gözle fark etmesi zor: sorun yalnızca listenin son
/// satırında ya da küçük bir telefonda görünür. Mantık saf bir fonksiyonda
/// olduğu için widget kurmadan, tek tek sınıyoruz.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/shared/widgets/iz_popover_menu.dart';

/// Telefon ölçüsü + tipik güvenli alan (çentik 47, alt çubuk 34).
const _screen = Size(390, 844);
const _safeArea = EdgeInsets.only(top: 47, bottom: 34);
const _menu = Size(220, 97);

void main() {
  group('normal durum — altta yer var', () {
    test('menü çıpanın ALTINA açılır', () {
      // Ekranın ortasındaki bir satır.
      const anchor = Rect.fromLTWH(300, 400, 48, 48);

      final offset = resolveIzPopoverOffset(
        anchor: anchor,
        popover: _menu,
        screen: _screen,
        safeArea: _safeArea,
      );

      // Çıpanın altı 448, üstüne varsayılan 4'lük boşluk.
      expect(offset.dy, 452);
    });

    test('SAĞ kenarlar hizalanır', () {
      const anchor = Rect.fromLTWH(300, 400, 48, 48);

      final offset = resolveIzPopoverOffset(
        anchor: anchor,
        popover: _menu,
        screen: _screen,
        safeArea: _safeArea,
      );

      // Üç nokta satırın sağ ucunda; menü de oradan aşağı açılmalı.
      expect(offset.dx + _menu.width, anchor.right);
    });
  });

  group('altta yer kalmadıysa', () {
    test('menü çıpanın ÜSTÜNE geçer', () {
      // Listenin son satırı: ekranın dibine yakın.
      const anchor = Rect.fromLTWH(300, 770, 48, 48);

      final offset = resolveIzPopoverOffset(
        anchor: anchor,
        popover: _menu,
        screen: _screen,
        safeArea: _safeArea,
      );

      // Aşağı açsaydı 822 + 97 = 919; ekran 844 ve altta 34 güvenli alan var.
      // Yukarı dönüyor: 770 − 4 − 97 = 669.
      expect(offset.dy, 669);
    });

    test('menü hiçbir hâlde güvenli alanın altına taşmaz', () {
      const anchor = Rect.fromLTWH(300, 700, 48, 48);

      final offset = resolveIzPopoverOffset(
        anchor: anchor,
        popover: _menu,
        screen: _screen,
        safeArea: _safeArea,
      );

      expect(
        offset.dy + _menu.height,
        lessThanOrEqualTo(_screen.height - _safeArea.bottom),
      );
    });
  });

  group('ekran kenarları', () {
    test('sol kenara yakın çıpada menü ekran dışına çıkmaz', () {
      // Sağ kenarları hizalasa menü −180'e giderdi.
      const anchor = Rect.fromLTWH(0, 400, 40, 40);

      final offset = resolveIzPopoverOffset(
        anchor: anchor,
        popover: _menu,
        screen: _screen,
        safeArea: _safeArea,
      );

      expect(offset.dx, greaterThanOrEqualTo(0));
    });

    test('sağ kenara yakın çıpada menü sağdan taşmaz', () {
      const anchor = Rect.fromLTWH(342, 400, 48, 48);

      final offset = resolveIzPopoverOffset(
        anchor: anchor,
        popover: _menu,
        screen: _screen,
        safeArea: _safeArea,
      );

      expect(offset.dx + _menu.width, lessThanOrEqualTo(_screen.width));
    });

    test('üstte de güvenli alanın üstüne çıkmaz', () {
      // Çentiğin hemen altındaki bir satır; yukarı dönmek zorunda kalsa
      // durum çubuğunun arkasına girmemeli.
      const anchor = Rect.fromLTWH(300, 60, 48, 48);

      final offset = resolveIzPopoverOffset(
        anchor: anchor,
        popover: _menu,
        screen: _screen,
        safeArea: _safeArea,
      );

      expect(offset.dy, greaterThanOrEqualTo(_safeArea.top));
    });
  });

  test('ekran menüden darsa sol kenara yaslanır, çökmez', () {
    // Uç durum: bu hesabın bir `clamp` hatasıyla patlamadığından emin ol.
    const anchor = Rect.fromLTWH(100, 100, 48, 48);

    final offset = resolveIzPopoverOffset(
      anchor: anchor,
      popover: const Size(400, 300),
      screen: const Size(200, 200),
    );

    expect(offset.dx, isNotNaN);
    expect(offset.dy, isNotNaN);
    expect(offset.dx, greaterThanOrEqualTo(0));
  });
}
