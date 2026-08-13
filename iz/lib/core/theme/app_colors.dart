/// İZ renk paleti.
///
/// KAYNAK: Figma tasarım token'ları. Aşağıda **FIGMA** etiketli sabitler
/// birebir tasarımdan gelir — değiştirmeden önce tasarımı güncelle.
/// **TÜRETİLMİŞ** etiketliler Figma'da tanımlı olmayan ama Material 3'ün
/// ihtiyaç duyduğu ara tonlardır (konteyner dolguları, çerçeveler, ton
/// basamakları). Tasarımda karşılıkları belirlenirse buradan değiştirilir.
///
/// NFR-031: "Renk tek başına bilgi taşımamalı; durumlar ikon/metinle
/// desteklenmelidir." Aşağıdaki durum renkleri her zaman ikon + metinle
/// birlikte kullanılır.
library;

import 'package:flutter/material.dart';

/// Açık tema renkleri.
abstract final class AppColorsLight {
  // --- FIGMA: Marka --------------------------------------------------------
  static const Color brandPrimary = Color(0xFF294A35);
  static const Color brandSecondary = Color(0xFF3F654B);
  static const Color brandAccent = Color(0xFFC5A56A);

  /// Markanın nötr/sessiz dolgusu — çip, ayraç, ince çerçeve.
  static const Color brandDefault = Color(0xFFE8E3D9);

  // --- FIGMA: Metin --------------------------------------------------------
  static const Color textPrimary = Color(0xFF24241F);
  static const Color textSecondary = Color(0xFF6F6C65);

  // --- FIGMA: Zemin --------------------------------------------------------
  static const Color backgroundApp = Color(0xFFFAF8F3);
  static const Color backgroundSurface = Color(0xFFFFFDFA);
  static const Color backgroundCard = Color(0xFFFAF8F3);

  // --- TÜRETİLMİŞ: marka renkleri üzerindeki metin -------------------------
  /// Koyu yeşil zemin üzerine açık metin.
  static const Color onBrandPrimary = backgroundApp;
  static const Color onBrandSecondary = backgroundApp;

  /// Altın zemin açıktır; üzerine KOYU metin gelir (kontrast ≈ 6.7:1).
  static const Color onBrandAccent = textPrimary;

  // --- TÜRETİLMİŞ: yumuşak marka dolguları ---------------------------------
  static const Color primaryContainer = Color(0xFFDBDED7);
  static const Color secondaryContainer = Color(0xFFDEE2DA);
  static const Color accentContainer = Color(0xFFEDE3D1);

  // --- TÜRETİLMİŞ: yüzey basamakları (App → Default arası ton rampası) -----
  static const Color surfaceStep1 = Color(0xFFF4F1EA);
  static const Color surfaceStep2 = Color(0xFFEEEAE2);

  // --- TÜRETİLMİŞ: çerçeveler ----------------------------------------------
  /// KONTROL çerçevesi — dolgusu olmayan butonların sınırı.
  ///
  /// Bu çizgi butonun *kendisidir*: kaybolursa kullanıcı tıklanabilir alanı
  /// göremez. Bu yüzden WCAG 1.4.11 gereği zeminle en az 3:1 kontrast taşır
  /// (`theme_contrast_test.dart` bunu ölçüyor). İlk denediğimiz #C9C7C1
  /// yalnızca 1.59:1 veriyordu — güneşte ekranda kaybolurdu.
  static const Color outline = Color(0xFF8B8880);

  /// DEKORATİF çizgi — kart kenarı, ayraç.
  /// Bilgi taşımadığı için 3:1 kuralına tabi değil; görevi sadece yüzeyleri
  /// yumuşakça ayırmak.
  static const Color outlineVariant = brandDefault;

  // --- TÜRETİLMİŞ: durum renkleri ------------------------------------------
  static const Color success = Color(0xFF2E7D5B);
  static const Color warning = Color(0xFFB05A17);
  static const Color danger = Color(0xFFB3261E);

  /// İZ+ vurgusu — paletin altın aksanı premium'u temsil eder.
  static const Color premium = Color(0xFF8A6A2E);
}

/// Koyu tema renkleri.
abstract final class AppColorsDark {
  // --- FIGMA: Marka --------------------------------------------------------
  static const Color brandPrimary = Color(0xFF78927E);
  static const Color brandSecondary = Color(0xFF4F7058);
  static const Color brandAccent = Color(0xFFD0AD68);
  static const Color brandDefault = Color(0xFF343D35);

  // --- FIGMA: Metin --------------------------------------------------------
  static const Color textPrimary = Color(0xFFF3F0E9);
  static const Color textSecondary = Color(0xFFAAA9A1);

  // --- FIGMA: Zemin --------------------------------------------------------
  static const Color backgroundApp = Color(0xFF141914);
  static const Color backgroundSurface = Color(0xFF1D241E);
  static const Color backgroundCard = Color(0xFF1A1E1B);

  // --- TÜRETİLMİŞ: marka renkleri üzerindeki metin -------------------------
  /// Koyu temada marka yeşili AÇIK bir tondur; üzerine koyu metin gelir.
  static const Color onBrandPrimary = backgroundApp;

  /// İkincil yeşil daha koyudur; üzerine açık metin gelir (kontrast ≈ 4.8:1).
  static const Color onBrandSecondary = textPrimary;
  static const Color onBrandAccent = backgroundApp;

  // --- TÜRETİLMİŞ: yumuşak marka dolguları ---------------------------------
  static const Color primaryContainer = Color(0xFF2F3B31);
  static const Color onPrimaryContainer = Color(0xFFBBC5B8);
  static const Color secondaryContainer = Color(0xFF2B3B2F);
  static const Color onSecondaryContainer = Color(0xFFC0D2C4);
  static const Color accentContainer = Color(0xFF433E29);
  static const Color onAccentContainer = Color(0xFFEBD6A9);

  // --- TÜRETİLMİŞ: yüzey basamakları ---------------------------------------
  /// Koyu temada YÜKSEK yüzey = DAHA AÇIK renk. Rampa:
  /// App(141914) → Card(1A1E1B) → Surface(1D241E) → step(283029) → Default(343D35)
  static const Color surfaceLowest = Color(0xFF0E120E);
  static const Color surfaceStep1 = Color(0xFF283029);

  // --- TÜRETİLMİŞ: çerçeveler ----------------------------------------------
  /// Kontrol çerçevesi — bkz. [AppColorsLight.outline] gerekçesi.
  static const Color outline = Color(0xFF656E66);

  /// Dekoratif çizgi — kart kenarı, ayraç.
  static const Color outlineVariant = brandDefault;

  // --- TÜRETİLMİŞ: durum renkleri ------------------------------------------
  static const Color success = Color(0xFF6FCF97);
  static const Color warning = Color(0xFFF0A868);
  static const Color danger = Color(0xFFF2B8B5);

  /// Koyu temada premium doğrudan Figma'nın altın aksanıdır.
  static const Color premium = brandAccent;
}

/// Material'ın [ColorScheme]'ine sığmayan, İZ'e özel renkleri temaya bağlar.
///
/// KULLANIM: `context.semanticColors.warning` (bkz. context_x.dart)
@immutable
final class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.premium,
  });

  factory AppSemanticColors.light() => const AppSemanticColors(
    success: AppColorsLight.success,
    warning: AppColorsLight.warning,
    danger: AppColorsLight.danger,
    premium: AppColorsLight.premium,
  );

  factory AppSemanticColors.dark() => const AppSemanticColors(
    success: AppColorsDark.success,
    warning: AppColorsDark.warning,
    danger: AppColorsDark.danger,
    premium: AppColorsDark.premium,
  );

  final Color success;
  final Color warning;
  final Color danger;
  final Color premium;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? premium,
  }) => AppSemanticColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    premium: premium ?? this.premium,
  );

  @override
  AppSemanticColors lerp(covariant AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      premium: Color.lerp(premium, other.premium, t)!,
    );
  }
}
