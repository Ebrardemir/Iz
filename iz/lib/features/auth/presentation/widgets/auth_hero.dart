/// Giriş ekranının üst görseli.
///
/// SAF WIDGET: Riverpod'a bağlı değil, veri almaz. Tek işi çizmek.
///
/// NEDEN TEMA BAŞINA AYRI FOTOĞRAF?
/// Tek bir açık tonlu fotoğraf koyu temada zeminden kopuyor ve ekranın üstü
/// "yapıştırılmış" gibi duruyordu. Açık temada beyaz kumaş üzerine serilmiş
/// baskılar, koyu temada koyu ahşap üzerinde sepya baskılar kullanıyoruz —
/// aynı fikir, her iki temada da doğru his.
///
/// GÖRSELLERİ DEĞİŞTİRME: `assets/images/auth/` içindeki iki dosyayı
/// değiştir, kod değişmez (kaynak/lisans ve öneriler: docs/assets/images.md).
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_colors.dart';
import 'package:iz/core/theme/app_icons.dart';

class AuthHero extends StatelessWidget {
  const AuthHero({super.key});

  static const String _light = 'assets/images/auth/hero_light.jpg';
  static const String _dark = 'assets/images/auth/hero_dark.jpg';

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Semantics(
      // NFR-032 — dekoratif görsel; ekran okuyucuya tek bir açıklama.
      label: context.l10n.authHeroSemantics,
      image: true,
      excludeSemantics: true,
      child: Image.asset(
        isDark ? _dark : _light,
        fit: BoxFit.cover,
        // Kutuyu tamamen doldur: altındaki kart görselin üzerine bindiği için
        // kenarlarda boşluk kalırsa geçiş bozulur.
        width: double.infinity,
        height: double.infinity,
        // Görsel yüklenemezse ekran çökmesin.
        errorBuilder: (context, error, stack) => ColoredBox(
          color: isDark
              ? AppColorsDark.brandDefault
              : AppColorsLight.brandDefault,
          child: const Center(child: Icon(AppIcons.photo)),
        ),
      ),
    );
  }
}
