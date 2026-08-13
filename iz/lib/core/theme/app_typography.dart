/// KULLANIM: widget'ta `fontSize` YAZMA, ölçekten oku:
/// ```dart
/// Text('Başlık', style: context.text.headlineMedium)
/// Text('12 anı', style: context.textStyles.statValue)
/// ```
library;

import 'package:flutter/material.dart';

abstract final class AppFonts {
  static const String display = 'CormorantGaramond';
  static const String body = 'Poppins';
}

abstract final class AppTypography {
  static const List<FontVariation> _semiBoldAxis = [FontVariation('wght', 600)];

  static TextStyle _display(double size) => TextStyle(
    fontFamily: AppFonts.display,
    fontSize: size,
    fontWeight: FontWeight.w600,
    fontVariations: _semiBoldAxis,
    // SATIR YÜKSEKLİĞİ = PUNTO + 8.
    //
    // Tasarımdan iki değer geldi ve ikisi de bu kuralı doğruluyor:
    //   H1 28 → 36   (ana sayfa başlığı)
    //   H2 24 → 32   (Hayatım ekranı başlığı)
    // Tek bir ORAN kullansaydık ikisi birden tutmazdı (36/28 = 1.286 ama
    // 32/24 = 1.333). Sabit ekleme ikisini de tam karşılıyor; ölçeğin
    // öteki basamakları da aynı ritmi sürdürüyor: 48→56, 36→44, 20→28.
    //
    // Önce 1.2 sonra 1.286 oranı kullanılmıştı; ikisi de TÜRETİLMİŞTİ.
    height: (size + 8) / size,
    letterSpacing: 0,
  );

  /// Figma satır yüksekliğini **piksel** olarak alır — CSS'te göründüğü gibi.
  ///
  /// Flutter `height` alanını ORAN olarak ister (satır yüksekliği ÷ punto),
  /// bu yüzden çevirmeyi burada yapıyoruz. Böylece aşağıdaki tablo Figma'nın
  /// `line-height: 20px` çıktısıyla birebir karşılaştırılabilir kalıyor;
  /// oranları elle hesaplayıp yazsaydık ilk düzenlemede kayardı.
  static TextStyle _body(
    double size,
    FontWeight weight, {
    required double lineHeightPx,
  }) => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: size,
    fontWeight: weight,
    height: lineHeightPx / size,
    // Figma'nın tamamında `letter-spacing: 0%`.
    // AÇIKÇA VERMEK ŞART: Material 3 etiket stillerine (labelLarge vb.)
    // kendiliğinden harf aralığı ekler; sıfırlamazsak tasarımdan sapar.
    letterSpacing: 0,
  );

  /// Figma ölçeğinin Material [TextTheme] karşılıkları.
  ///
  /// Material'ın 15 hazır yuvası var; Figma'daki iki stil (Body Small 10
  /// Regular ve Stat/Value 20 Medium) bunlara oturmuyor — onlar
  /// [AppTextStyles] uzantısında.
  static TextTheme build(Color onSurface) {
    final theme = TextTheme(
      // --- Cormorant Garamond SemiBold --------------------------------------
      displayLarge: _display(48), // FIGMA: Display 48
      displayMedium: _display(36), // FIGMA: Display 36
      // Figma'da üçüncü bir Display yok; H1 ile aynı ölçüyü veriyoruz ki
      // `displaySmall` kullanan Material bileşenleri ölçek dışına düşmesin.
      displaySmall: _display(28),

      headlineLarge: _display(28), // FIGMA: H1 28
      headlineMedium: _display(24), // FIGMA: H2 24
      headlineSmall: _display(20), // FIGMA: H3 20
      // --- Poppins (satır yükseklikleri Figma'dan, px) -----------------------

      // FIGMA: Body Large 20 SemiBold — 20/16
      // ⚠️ Satır yüksekliği (16) puntodan (20) KÜÇÜK. Tek satırlık başlıklarda
      // sorun çıkarmaz ama metin iki satıra taşarsa satırlar üst üste biner.
      // Figma'da "auto height" kapalı kalmış olabilir; tasarımda teyit et.
      titleLarge: _body(20, FontWeight.w600, lineHeightPx: 16),

      // FIGMA: Label 14 Medium — 14/20
      titleMedium: _body(14, FontWeight.w500, lineHeightPx: 20),

      // FIGMA: Body Small-medium 12 Medium — 12/18
      titleSmall: _body(12, FontWeight.w500, lineHeightPx: 18),

      // FIGMA: Body Large 16 Regular — 16/24
      bodyLarge: _body(16, FontWeight.w400, lineHeightPx: 24),

      // FIGMA: Body 14 Regular — 14/20
      bodyMedium: _body(14, FontWeight.w400, lineHeightPx: 20),

      // FIGMA: Body Small-1 12 Regular — 12/18
      bodySmall: _body(12, FontWeight.w400, lineHeightPx: 18),

      // FIGMA: Button 14 SemiBold — 14/20
      labelLarge: _body(14, FontWeight.w600, lineHeightPx: 20),

      // FIGMA: Caption 12 Medium = Stat/Label 12 Medium — 12/16
      labelMedium: _body(12, FontWeight.w500, lineHeightPx: 16),

      // FIGMA: Stat/Label 10 Medium — 10/16
      labelSmall: _body(10, FontWeight.w500, lineHeightPx: 16),
    );

    return theme.apply(bodyColor: onSurface, displayColor: onSurface);
  }
}

/// Material'ın [TextTheme] yuvalarına sığmayan Figma stilleri.
///
/// `AppSemanticColors` ile aynı desen: tasarımda var ama Material'da karşılığı
/// olmayan token'ları temaya bağlıyoruz.
///
/// KULLANIM: `context.textStyles.statValue` (bkz. context_x.dart)
@immutable
final class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.bodyTiny,
    required this.caption,
    required this.statValue,
    required this.screenTitle,
  });

  factory AppTextStyles.standard() => const AppTextStyles(
    // FIGMA: Body Small 10 Regular — 10/18. Yasal metin, çok küçük dipnot.
    bodyTiny: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 10,
      fontWeight: FontWeight.w400,
      height: 18 / 10,
      letterSpacing: 0,
    ),

    // FIGMA: Caption 12 Regular — 12/16.
    //
    // NEDEN AYRI? Figma'da İKİ farklı 12px Regular var: `Body Small-1`
    // (satır yüksekliği 18) ve `Caption` (16). Punto ve ağırlık aynı, satır
    // yüksekliği farklı. Material'ın 12px Regular için tek yuvası
    // (`bodySmall`) olduğundan ikincisi buraya düşüyor.
    caption: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 16 / 12,
      letterSpacing: 0,
    ),

    // FIGMA: Stat/Value 20 Medium — 20/24. Sayaç değerleri.
    // `titleLarge` de 20 ama SemiBold ve satır yüksekliği 16; bu ayrı stil.
    statValue: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 20,
      fontWeight: FontWeight.w500,
      height: 24 / 20,
      letterSpacing: 0,
    ),

    // Bir ekranın kendi başlığı — anı detayındaki anı adı gibi.
    //
    // NEDEN `headline*` DEĞİL? O yuvalar Cormorant Garamond (serif) tutuyor
    // ve serif markanın DUYGUSAL sesi: "Bu anıdan geriye hangi kareler
    // kalsın?" gibi sorulara yakışıyor. Ama kullanıcının kendi yazdığı bir
    // başlık ("İlk İzmir Tatilimiz") bir VERİ; onu süslü bir yazıyla
    // göstermek, altındaki notla aynı aileden olmadığı için sayfayı iki sesli
    // yapıyordu.
    //
    // NEDEN `titleLarge` DEĞİL? O da Poppins ama 20 punto ve satır yüksekliği
    // 16 — bir ekran başlığı olarak küçük kalıyor, iki satıra düşen bir
    // başlıkta da satırlar sıkışıyor.
    screenTitle: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 26,
      fontWeight: FontWeight.w600,
      height: 34 / 26,
      letterSpacing: 0,
    ),
  );

  final TextStyle bodyTiny;
  final TextStyle caption;
  final TextStyle statValue;
  final TextStyle screenTitle;

  @override
  AppTextStyles copyWith({
    TextStyle? bodyTiny,
    TextStyle? caption,
    TextStyle? statValue,
    TextStyle? screenTitle,
  }) => AppTextStyles(
    bodyTiny: bodyTiny ?? this.bodyTiny,
    caption: caption ?? this.caption,
    statValue: statValue ?? this.statValue,
    screenTitle: screenTitle ?? this.screenTitle,
  );

  @override
  AppTextStyles lerp(covariant AppTextStyles? other, double t) {
    if (other == null) return this;
    return AppTextStyles(
      bodyTiny: TextStyle.lerp(bodyTiny, other.bodyTiny, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      statValue: TextStyle.lerp(statValue, other.statValue, t)!,
      screenTitle: TextStyle.lerp(screenTitle, other.screenTitle, t)!,
    );
  }
}
