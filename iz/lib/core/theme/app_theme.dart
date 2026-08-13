library;

import 'package:flutter/material.dart';
import 'package:iz/core/theme/app_colors.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/core/theme/app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(_lightScheme, AppSemanticColors.light());
  static ThemeData dark() => _build(_darkScheme, AppSemanticColors.dark());

  // --- Renk şemaları --------------------------------------------------------

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,

    primary: AppColorsLight.brandPrimary,
    onPrimary: AppColorsLight.onBrandPrimary,
    primaryContainer: AppColorsLight.primaryContainer,
    onPrimaryContainer: AppColorsLight.brandPrimary,

    secondary: AppColorsLight.brandSecondary,
    onSecondary: AppColorsLight.onBrandSecondary,
    secondaryContainer: AppColorsLight.secondaryContainer,
    onSecondaryContainer: AppColorsLight.brandSecondary,

    // Altın aksan Material'ın "tertiary" rolüne oturur: vurgu, premium rozet.
    tertiary: AppColorsLight.brandAccent,
    onTertiary: AppColorsLight.onBrandAccent,
    tertiaryContainer: AppColorsLight.accentContainer,
    onTertiaryContainer: AppColorsLight.textPrimary,

    error: AppColorsLight.danger,
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),

    surface: AppColorsLight.backgroundApp,
    onSurface: AppColorsLight.textPrimary,
    onSurfaceVariant: AppColorsLight.textSecondary,

    outline: AppColorsLight.outline,
    outlineVariant: AppColorsLight.outlineVariant,

    // Yüzey ton rampası: en açık (yükseltilmiş) → en koyu (nötr dolgu).
    surfaceContainerLowest: AppColorsLight.backgroundSurface,
    surfaceContainerLow: AppColorsLight.backgroundCard,
    surfaceContainer: AppColorsLight.surfaceStep1,
    surfaceContainerHigh: AppColorsLight.surfaceStep2,
    surfaceContainerHighest: AppColorsLight.brandDefault,

    inverseSurface: AppColorsLight.textPrimary,
    onInverseSurface: AppColorsLight.backgroundApp,
    inversePrimary: AppColorsDark.brandPrimary,

    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,

    primary: AppColorsDark.brandPrimary,
    onPrimary: AppColorsDark.onBrandPrimary,
    primaryContainer: AppColorsDark.primaryContainer,
    onPrimaryContainer: AppColorsDark.onPrimaryContainer,

    secondary: AppColorsDark.brandSecondary,
    onSecondary: AppColorsDark.onBrandSecondary,
    secondaryContainer: AppColorsDark.secondaryContainer,
    onSecondaryContainer: AppColorsDark.onSecondaryContainer,

    tertiary: AppColorsDark.brandAccent,
    onTertiary: AppColorsDark.onBrandAccent,
    tertiaryContainer: AppColorsDark.accentContainer,
    onTertiaryContainer: AppColorsDark.onAccentContainer,

    error: AppColorsDark.danger,
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),

    surface: AppColorsDark.backgroundApp,
    onSurface: AppColorsDark.textPrimary,
    onSurfaceVariant: AppColorsDark.textSecondary,

    outline: AppColorsDark.outline,
    outlineVariant: AppColorsDark.outlineVariant,

    // DİKKAT: koyu temada yükseklik arttıkça renk AÇILIR — açık temanın tersi.
    surfaceContainerLowest: AppColorsDark.surfaceLowest,
    surfaceContainerLow: AppColorsDark.backgroundCard,
    surfaceContainer: AppColorsDark.backgroundSurface,
    surfaceContainerHigh: AppColorsDark.surfaceStep1,
    surfaceContainerHighest: AppColorsDark.brandDefault,

    inverseSurface: AppColorsDark.textPrimary,
    onInverseSurface: AppColorsDark.backgroundApp,
    inversePrimary: AppColorsLight.brandPrimary,

    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  // --- Tema kurulumu --------------------------------------------------------

  static ThemeData _build(ColorScheme scheme, AppSemanticColors semantic) {
    final isDark = scheme.brightness == Brightness.dark;

    final cardColor = isDark
        ? AppColorsDark.backgroundCard
        : AppColorsLight.backgroundCard;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      // `surfaceTint` Material 3'te yükseltilmiş yüzeylere mor-mavi bir sis
      // ekler ve toprak tonlu paleti kirletir. Kapatıyoruz; derinliği
      // renk rampası ve çerçeveler veriyor.
      splashFactory: InkSparkle.splashFactory,
      // Tasarımın tipografi ölçeği — Cormorant Garamond (başlık) +
      // Poppins (gövde). Bkz. app_typography.dart.
      textTheme: AppTypography.build(scheme.onSurface),
      fontFamily: AppFonts.body,
    );

    return base.copyWith(
      extensions: [semantic, AppTextStyles.standard()],

      // TASARIM VARSAYILANI: ikonlar 28.
      // Burada bir kez ayarladığımız için widget'larda `size:` yazmıyoruz;
      // 40 ekran sonra 24/26/28 karışımı oluşmasının önüne geçer.
      iconTheme: const IconThemeData(size: AppIconSize.lg),

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(size: AppIconSize.lg, color: scheme.onSurface),
        actionsIconTheme: IconThemeData(
          size: AppIconSize.lg,
          color: scheme.onSurface,
        ),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),

      // AÇIK TEMADA KART = ZEMİN RENGİ (ikisi de FAF8F3).
      // Bu yüzden kartı gölge değil ÇERÇEVE ayırır; gölgeye güvenseydik
      // kartlar açık temada görünmez olurdu.
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Figma "Background/Surface". Kart "Background/App" olduğu için
        // alanlar karttan bir tık AYRIŞIR — referans tasarımdaki ilişki bu:
        // açık temada krem kartın üzerinde beyaza yakın alanlar, koyu temada
        // koyu kartın üzerinde bir tık açık alanlar.
        fillColor: isDark
            ? AppColorsDark.backgroundSurface
            : AppColorsLight.backgroundSurface,
        border: const OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        // Alan yüksekliği dolgudan DEĞİL, asgari dokunma hedefinden gelir.
        //
        // Dikey dolguyu 16 verdiğimizde alanlar ~53px oluyordu; dört alanlı
        // formda bu gereksiz yer kaplıyor. Dolguyu kısıp yüksekliği 48'e
        // (NFR-033 asgari dokunma hedefi) sabitliyoruz: alanlar görsel olarak
        // daha derli toplu ama parmakla vurulabilirlik hiç bozulmuyor.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          // NFR-033: asgari dokunma hedefi
          minimumSize: const Size(64, AppSpacing.minTapTarget),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(64, AppSpacing.minTapTarget),
          side: BorderSide(color: scheme.outline),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, AppSpacing.minTapTarget),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.secondaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.chip,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        side: BorderSide.none,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        showDragHandle: true,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        // BAŞLIK POPPINS, Cormorant DEĞİL.
        //
        // Material'ın varsayılanı `headlineSmall` ve o yuva bizde serif
        // tutuyor — "Kişi silinsin mi?" süslü bir yazıyla çıkıp hemen
        // altındaki Poppins açıklamayla aynı aileden görünmüyordu. Serif
        // markanın DUYGUSAL sesi ("Bu anıdan geriye hangi kareler kalsın?");
        // bir onay diyaloğu ise soğukkanlı bir soru sorar.
        //
        // `titleLarge` = Poppins 20 SemiBold: açıklamanın bir tık üstü.
        // Seçim diyaloğu bunu bir süre kendi içinde tanımlıyordu; artık tek
        // kaynak burası.
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      // TARİH SEÇİCİ — Material'ın kendi görünümü İZ'e ait değil.
      //
      // Kendi takvimimizi çizmek yerine Material'ınkini TEMAYA OTURTUYORUZ:
      // seçicinin içinde ay geçişi, yıl listesi, klavye girişi ve
      // erişilebilirlik zaten çözülmüş; onları yeniden yazmak çok riskli iş.
      // Değiştirdiğimiz şey yalnızca giysisi — yüzey rengi, köşeler, seçili
      // günün marka yeşili ve tipografi ölçeği.
      //
      // Not: `CalendarGrid` (Hayatım ekranı) İZ'e özel çizilmiş bir takvim
      // ama o bir SEÇİCİ değil, bir görünüm; ay içindeki anıları gösteriyor.
      // İkisini birleştirmek istenirse `CalendarMonth` mantığı `shared/`a
      // taşınıp buradan da kullanılabilir.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        headerBackgroundColor: scheme.primary,
        headerForegroundColor: scheme.onPrimary,
        // Seçili gün: dolu marka yeşili — alt çubuktaki seçili sekmeyle
        // ve takvimdeki "bugün" işaretiyle aynı dil.
        todayBorder: BorderSide(color: scheme.primary),
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.primary,
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurface,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        // Başlık serif: markanın sesi başlıklarda Cormorant.
        headerHeadlineStyle: base.textTheme.headlineSmall?.copyWith(
          color: scheme.onPrimary,
        ),
        headerHelpStyle: base.textTheme.labelMedium?.copyWith(
          color: scheme.onPrimary,
        ),
        dayStyle: base.textTheme.bodyMedium,
        weekdayStyle: base.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        yearStyle: base.textTheme.bodyLarge,
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.chip,
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        // Seçili sekme, ikonu DOLDURARAK değil gösterge hapı + renk ile
        // belirtilir — Lucide'da dolu varyant yok (bkz. app_icons.dart).
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppIconSize.lg,
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        minVerticalPadding: AppSpacing.sm,
      ),

      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: scheme.outlineVariant,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        actionTextColor: isDark
            ? AppColorsDark.brandAccent
            : AppColorsLight.brandAccent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.chip),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHigh,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}
