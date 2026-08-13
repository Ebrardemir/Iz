/// Üst şeritlerdeki ikon eylemi — hizası ve dokunma alanı doğru kurulmuş.
///
/// NEDEN AYRI BİLEŞEN?
/// Aynı iki tuzağa iki ayrı ekranda düştük (ana sayfadaki zil, Hayatım
/// ekranındaki arama/filtre). İkisi de `IconButton`ın GÖRÜNMEZ payından
/// kaynaklanıyor: ikon 28 çizilir ama kutu 48'dir, yani her yanda
/// [kTapPadding] kadar boşluk vardır.
///
/// TUZAK 1 — KENAR HİZASI. Kutunun kenarı tasarımdaki yere konunca ikon
/// 10 px içeride kalır.
///
/// TUZAK 2 — ARALIK. İki ikon arasına tasarımdaki boşluğu koyarsan görünen
/// aralık iki kutunun payı kadar (2 × 10) fazla çıkar.
///
/// İkisini birden [IzIconActionRow] çözüyor. Düzeltmeyi TEK TEK ikona
/// uygulamak yetmiyor: son ikonu sağa kaydırınca komşusuyla arası da
/// açılıyor. Bu yüzden kaydırma SATIRIN tamamına uygulanıyor.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/theme/app_spacing.dart';

class IzIconAction extends StatelessWidget {
  const IzIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.shadows,
    this.size = AppIconSize.lg,
    super.key,
  });

  final IconData icon;

  /// NFR-032 — ekran okuyucu ve uzun basış için.
  final String tooltip;

  final VoidCallback? onPressed;

  /// Boş bırakılırsa temanın `onSurface` rengi.
  final Color? color;

  /// Fotoğraf üzerinde okunurluk gölgesi.
  final List<Shadow>? shadows;

  /// İkonun çizim boyu. Varsayılan arayüz ölçüsü 28; bazı Figma
  /// çerçeveleri (ay okları gibi) 32 istiyor.
  final double size;

  /// Dokunma kutusunun VARSAYILAN ikon boyunda her yana eklediği görünmez pay.
  static const double kTapPadding =
      (AppSpacing.minTapTarget - AppIconSize.lg) / 2;

  /// Verilen ikon boyu için görünmez pay.
  ///
  /// Kutu her zaman en az [AppSpacing.minTapTarget]; ikon büyüdükçe pay
  /// küçülür, ikon kutudan büyükse pay 0'a iner.
  ///
  /// [IzIconActionRow] hizayı bununla hesaplıyor — sabit [kTapPadding]
  /// kullansaydı satıra varsayılandan farklı boyda (örn. 32) bir ikon
  /// konduğu anda hiza sessizce kayardı.
  static double paddingFor(double iconSize) {
    final pad = (AppSpacing.minTapTarget - iconSize) / 2;
    return pad < 0 ? 0 : pad;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      // Dokunma alanı 48'in altına düşmesin diye `IconButton`; çıplak
      // `Icon` görsel olarak aynı görünür ama parmakla ıskalanır.
      constraints: const BoxConstraints(
        minWidth: AppSpacing.minTapTarget,
        minHeight: AppSpacing.minTapTarget,
      ),
      padding: EdgeInsets.zero,
      icon: Icon(
        icon,
        size: size,
        color: color ?? Theme.of(context).colorScheme.onSurface,
        shadows: shadows,
      ),
    );
  }
}

/// Şeridin sağ ucundaki ikon eylemleri.
///
/// İki düzeltmeyi birden yapar:
///   • Aradaki boşluğu tasarımdaki GÖRÜNEN değere indirir (kutuların
///     görünmez payını düşerek).
///   • Satırın tamamını payı kadar sağa kaydırır, böylece son ikonun
///     görsel sağ kenarı tasarımdaki yere oturur.
///
/// Kaydırmanın SATIRA uygulanması şart: tek tek son ikona uygulasaydık
/// komşusuyla arası da o kadar açılırdı — ilk denemede tam bu oldu.
class IzIconActionRow extends StatelessWidget {
  const IzIconActionRow({required this.actions, this.designGap = 0, super.key});

  final List<IzIconAction> actions;

  /// Tasarımdaki, ikonların GÖRÜNEN kenarları arasındaki boşluk.
  final double designGap;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    // Her ikonun payı KENDİ boyundan hesaplanıyor. Sabit bir değer
    // kullanmıyoruz: satırda 28 ve 32 boyunda ikonlar karışık durabilir ve
    // o durumda tek bir pay ikisi için de yanlış olurdu.
    final pads = [
      for (final action in actions) IzIconAction.paddingFor(action.size),
    ];

    return Transform.translate(
      // Kaydırma SON ikonun payı kadar: satırın görsel sağ kenarını
      // tasarımdaki yere oturtan şey o ikonun kendi görünmez payıdır.
      offset: Offset(pads.last, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            actions[i],
            if (i < actions.length - 1)
              // Komşu iki kutunun payı, tasarımdaki GÖRÜNEN boşluktan
              // düşülüyor. Negatife düşmesin: kutular üst üste binemez.
              SizedBox(
                width: (designGap - pads[i] - pads[i + 1]).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
