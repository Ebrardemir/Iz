/// Fotoğrafın üzerinde duran YARI SAYDAM hap buton.
///
/// Zemini tema DEĞİL, altındaki fotoğraf belirliyor: buton kendi rengini
/// getirmez, görselin üzerine ince bir beyaz tabaka serer. Bu yüzden
/// renkleri `ColorScheme`den gelmiyor — açık/koyu tema fark etmeksizin
/// fotoğrafın üstünde aynı davranır. Uygulamanın geri kalanındaki butonlar
/// temadan beslenmeye devam ediyor; bu bilinçli ve dar bir istisna.
///
/// ÖLÇÜLER (Figma):
///   height 36, border-radius 999 (hap), border 2px #FFFFFF99,
///   background #FFFFFF29, yatay padding 16, ikon–yazı arası 4
///
/// NEDEN `TextButton`, elle yazılmış bir kutu değil?
/// Tasarımdaki 36 px, parmak için önerilen 48'in altında. `TextButton`'ın
/// `tapTargetSize: padded` ayarı, butonun GÖRÜNEN boyunu değiştirmeden
/// dokunma alanını 48'e çıkarır (NFR-032). Elle yazsaydık ya tasarımı ya
/// erişilebilirliği bozardık.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';

class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconAfterLabel = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// "Anı Ekle" → artı SOLDA (eylemi niteler).
  /// "Anıyı Gör →" → ok SAĞDA (yönü gösterir).
  final bool iconAfterLabel;

  /// Dolgu — beyazın %24'ü.
  ///
  /// Figma katmanı `#FFFFFF29` (%16) diyordu ama referans TASARIMDA buton
  /// gözle görülür şekilde daha belirgin. Tahmin etmemek için referans
  /// görselden ölçtük: butonun içi ile hemen yanındaki fotoğrafı aynı
  /// yükseklikte karşılaştırınca alfa ≈ 0.238 çıkıyor → `0x3D`.
  static const Color _fill = Color(0x3DFFFFFF);

  /// Kenarlık — beyazın %60'ı (`#FFFFFF99`, Figma).
  ///
  /// Ölçüm 0.55 verdi; aradaki fark 2 px'lik kenarlığın küçültülmüş ekran
  /// görüntüsünde yumuşamasından. Katmandaki değer daha güvenilir.
  static const Color _border = Color(0x99FFFFFF);

  static const double kHeight = 36;
  static const double _kBorderWidth = 2;

  /// `tapTargetSize: padded` butonun ÜSTÜNE ve ALTINA bu kadar GÖRÜNMEZ pay
  /// ekler; kutu 36 çizilir ama 48 olarak yer kaplar.
  ///
  /// Bunu dışarı açıyoruz çünkü butonu tasarımdaki yere oturtan kod bu payı
  /// düşmek zorunda: hesaba katmazsan butonun çevresindeki boşluklar
  /// Figma'dakinden 6'şar piksel büyük çıkar — ilk denemede tam bu oldu.
  static const double kTapPadding = (AppSpacing.minTapTarget - kHeight) / 2;

  /// Yazının puntosuna göre küçük bir ikon. Arayüz ölçeğindeki 28 bu hapın
  /// içinde devasa kalırdı.
  static const double _kIconSize = 16;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: _fill,
        foregroundColor: Colors.white,
        // Fotoğrafın üzerinde koyu dalga kaybolur; beyaz görünür.
        overlayColor: Colors.white,
        shape: const StadiumBorder(
          side: BorderSide(color: _border, width: _kBorderWidth),
        ),
        side: const BorderSide(color: _border, width: _kBorderWidth),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        // Yükseklik tasarımdan; genişlik içeriğe göre.
        minimumSize: const Size(0, kHeight),
        fixedSize: const Size.fromHeight(kHeight),
        tapTargetSize: MaterialTapTargetSize.padded,
        // Punto ve satır yüksekliği ölçekten (`bodyLarge`, 16/24), ağırlık
        // butondan (SemiBold).
        //
        // ⚠️ TEK SAPMA: tasarım sisteminde 16 SemiBold yok — Poppins 16
        // yalnızca Regular olarak tanımlı, buton stili ise 14 SemiBold.
        // Fotoğrafın üzerinde 14 küçük kalıyordu, Regular'a düşmek de
        // butonu zayıflatıyordu. Tasarımcıdan "Button 16 SemiBold" token'ı
        // isteyip burayı ona bağlamak gerekiyor.
        textStyle: context.text.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!iconAfterLabel) ...[
            Icon(icon, size: _kIconSize),
            // Figma: ikon–yazı arası 4.
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (iconAfterLabel) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(icon, size: _kIconSize),
          ],
        ],
      ),
    );
  }
}
