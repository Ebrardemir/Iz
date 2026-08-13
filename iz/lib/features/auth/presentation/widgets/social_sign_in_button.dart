/// Apple / Google ile giriş butonu.
///
/// SAF WIDGET: hangi sağlayıcı olduğunu bilmez; ikon + etiket + eylem alır.
///
/// LOGOLAR NEDEN FARKLI YOLLARLA ÇİZİLİYOR?
///   • **Google** çok renkli bir logodur (mavi/yeşil/sarı/kırmızı). İkon
///     fontları tek renk çizer, bu yüzden resmi SVG'yi gömüyoruz.
///   • **Apple** logosunun renkli sürümü YOKTUR. Apple'ın marka kuralları
///     yalnızca düz siyah veya düz beyaz kullanılmasına izin verir; bu yüzden
///     o, temaya göre renk alan tek renk bir ikon olarak kalıyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';

/// Google'ın resmi "G" logosu (Wikimedia Commons, Google markası).
///
/// Dosya yerine metin olarak gömülü: 24×24'lük tek bir simge için ayrı bir
/// asset dosyası ve onun yolunu doğru yazma zorunluluğu gereksiz.
const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24">
<path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
<path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
<path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
<path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
</svg>
''';

enum SocialProviderBrand { apple, google }

class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    required this.brand,
    required this.label,
    required this.onPressed,
    this.compact = false,
    super.key,
  });

  final SocialProviderBrand brand;
  final String label;
  final VoidCallback? onPressed;

  /// İki buton YAN YANA duruyorsa `true` ver.
  ///
  /// Dar düzende her piksel yazıya lazım: logo ile etiket arası kısılır,
  /// yoksa "Google ile Giriş Yap" tek satıra sığmaz. Tam genişlikte
  /// (alt alta) ise tersi geçerli — sıkışık bir ikon+yazı ikilisi geniş
  /// butonun ortasında yalnız kalır, aralarını açmak daha dengeli durur.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.xs : AppSpacing.md,
        ),
        side: BorderSide(color: context.colors.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrandLogo(brand: brand),
          SizedBox(width: compact ? AppSpacing.xs : AppSpacing.md),
          // TEK SATIR ŞART.
          //
          // "Google ile Giriş Yap" 14 puntoda mevcut genişliğe kıl payı
          // sığmıyor. `scaleDown` yalnızca GEREKİRSE küçültür: Apple etiketi
          // 14'te kalır, Google birkaç ondalık küçülür. Kırpmaya (…) veya
          // ikinci satıra düşmeye göre ikisi de daha iyi.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                // "Caption 12 Medium". 14'te iki buton yan yana dururken
                // etiketler sığmıyordu; referansta da bu yazılar gövde
                // metninden küçük.
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.brand});

  final SocialProviderBrand brand;

  @override
  Widget build(BuildContext context) {
    return switch (brand) {
      SocialProviderBrand.google => SvgPicture.string(
        _googleLogoSvg,
        width: AppIconSize.md,
        height: AppIconSize.md,
      ),
      // Apple logosu temaya göre siyah/beyaz olur — marka kuralı bu.
      SocialProviderBrand.apple => FaIcon(
        FontAwesomeIcons.apple,
        size: AppIconSize.md,
        color: context.colors.onSurface,
      ),
    };
  }
}
