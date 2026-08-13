/// Ana sayfada FOTOĞRAFIN ÜZERİNDE duran üst şerit: solda marka, sağda zil.
///
/// SAF WIDGET: veri almaz, konumunu da bilmez. Nereye oturacağına
/// [HomeHeroOverlay] karar verir; burada yalnızca satırın kendisi var.
///
/// ÖLÇÜLER (Figma, 390 genişlikte çerçeve):
///   şerit  → width 350, height 40, top 36, left 20, space-between
///   "İZ"   → width 46, height 44
/// 350 + 2×20 = 390 olduğu için "width: 350" aslında **20 px yan boşluk**
/// demek; sabit genişlik yerine boşluğu yazıyoruz ki her ekranda çalışsın.
///
/// Tasarımda logonun sağında bir profil dairesi de vardı; istenmediği için
/// yok. Zil bu yüzden şeridin en sağında.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/shared/widgets/iz_icon_action.dart';
import 'package:iz/shared/widgets/iz_wordmark.dart';

/// Fotoğrafın üzerindeki BEYAZ metin ve ikonlar için okunurluk gölgesi.
///
/// Buradaki zemin tema değil, o günkü anının kapak görseli. Açık bir
/// gökyüzüne denk gelirse beyaz kaybolur. Yumuşak koyu gölge hiçbir şeyi
/// karartmadan kenarları ayırıyor.
const List<Shadow> kOnPhotoShadows = [
  Shadow(color: Color(0x66000000), blurRadius: 12),
  Shadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
];

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({this.onNotificationsPressed, super.key});

  /// Şimdilik "yakında" bildirimi gösteriyor; ekran hazır olunca rota olacak.
  final VoidCallback? onNotificationsPressed;

  /// "İZ" kutusunun yüksekliği. `height: 1` sayesinde punto ile kutu
  /// yüksekliği aynı şey — Figma'daki yükseklik doğrudan buraya yazılır.
  ///
  /// Figma 44 diyordu; ekranda küçük kaldığı için 52'ye çıktı. Zil bilerek
  /// büyümedi: marka öne çıksın, ikon arayüz ölçeğinde (28) kalsın.
  /// **Logoyu büyütmek/küçültmek için değiştirilecek TEK sayı burası** —
  /// şeridin hizası aşağıda bundan türetiliyor.
  static const double kWordmarkSize = 60;

  /// Satırın yüksekliği: logo ile dokunma hedefinden hangisi büyükse o.
  static const double kRowHeight = kWordmarkSize > AppSpacing.minTapTarget
      ? kWordmarkSize
      : AppSpacing.minTapTarget;

  /// Şeridin üstten uzaklığı — MERKEZDEN türetildi.
  ///
  /// Figma'da şerit `top: 36, height: 40`, yani dikey merkezi 56. Ama
  /// bizim satırımız 40 değil: zil bir BUTON ve dokunma hedefi 48'in
  /// altına düşemez (NFR-032), logo da ondan uzun olabilir. Satırı 36'dan
  /// başlatsaydık merkez aşağı kayar, logo ve zil tasarımdakinden aşağıda
  /// dururdu. Merkezi koruyarak hesaplıyoruz; böylece [kWordmarkSize]
  /// değişince hiza kendiliğinden düzeliyor.
  static const double _kStripCenter = 36 + 40 / 2; // 56
  static const double kTopInset = _kStripCenter - kRowHeight / 2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kRowHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const IzWordmark(
            size: kWordmarkSize,
            // Fotoğraf üzerinde marka yeşili okunmuyor; burada renk temadan
            // değil ZEMİNDEN geliyor ve iki temada da beyaz.
            color: Colors.white,
            // Filiz bu puntoda lekeye dönüşüyor.
            showSprig: false,
            shadows: kOnPhotoShadows,
          ),
          IzIconActionRow(
            actions: [
              IzIconAction(
                icon: AppIcons.notifications,
                tooltip: context.l10n.homeNotifications,
                onPressed: onNotificationsPressed,
                color: Colors.white,
                shadows: kOnPhotoShadows,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
