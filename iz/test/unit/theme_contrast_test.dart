/// Tema **okunabilirlik** testi (WCAG 2.1 kontrast oranı).
///
/// NEDEN BU TEST VAR?
/// Figma'dan 9 marka rengi geldi; Material 3'ün ihtiyaç duyduğu geri kalan
/// tonları (konteyner dolguları, çerçeveler, durum renkleri) biz türettik.
/// Türetilmiş bir renk gözle "güzel" görünüp aynı zamanda **okunamaz**
/// olabilir — özellikle açık zemin üzerindeki altın/turuncu tonlarında.
///
/// Bu test o riski ölçüyor. Paleti ileride değiştirdiğinde, okunabilirliği
/// bozan bir renk seçersen testi kırar.
///
/// EŞİKLER (WCAG 2.1 AA):
///   • Normal metin        → 4.5:1
///   • Büyük metin / ikon  → 3.0:1
///   • Çerçeve, ayraç      → 3.0:1
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/theme/app_colors.dart';
import 'package:iz/core/theme/app_theme.dart';

/// WCAG bağıl parlaklık (relative luminance).
double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4) as double;

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// İki renk arasındaki kontrast oranı (1.0 – 21.0).
double contrastRatio(Color foreground, Color background) {
  final a = _luminance(foreground);
  final b = _luminance(background);
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  const textThreshold = 4.5;
  const uiThreshold = 3.0;

  /// Tek bir çifti doğrular ve başarısızlıkta ölçülen değeri yazar.
  void expectContrast(
    Color foreground,
    Color background, {
    required String label,
    required double min,
  }) {
    final ratio = contrastRatio(foreground, background);
    expect(
      ratio,
      greaterThanOrEqualTo(min),
      reason:
          '$label kontrastı yetersiz: ${ratio.toStringAsFixed(2)}:1 '
          '(en az ${min.toStringAsFixed(1)}:1 olmalı). '
          'Ön plan #${foreground.toARGB32().toRadixString(16).substring(2)}, '
          'zemin #${background.toARGB32().toRadixString(16).substring(2)}',
    );
  }

  for (final (themeName, theme) in [
    ('açık tema', AppTheme.light()),
    ('koyu tema', AppTheme.dark()),
  ]) {
    group(themeName, () {
      final scheme = theme.colorScheme;
      final semantic = theme.extension<AppSemanticColors>()!;

      test('metin renkleri zeminde okunabilir', () {
        expectContrast(
          scheme.onSurface,
          scheme.surface,
          label: 'Text/Primary → Background/App',
          min: textThreshold,
        );
        expectContrast(
          scheme.onSurfaceVariant,
          scheme.surface,
          label: 'Text/Secondary → Background/App',
          min: textThreshold,
        );
        // Kartlar ve yükseltilmiş yüzeyler de aynı metni taşıyor.
        expectContrast(
          scheme.onSurface,
          scheme.surfaceContainerLowest,
          label: 'Text/Primary → Background/Surface',
          min: textThreshold,
        );
        expectContrast(
          scheme.onSurfaceVariant,
          scheme.surfaceContainerLow,
          label: 'Text/Secondary → Background/Card',
          min: textThreshold,
        );
      });

      test('marka renkleri üzerindeki metin okunabilir', () {
        expectContrast(
          scheme.onPrimary,
          scheme.primary,
          label: 'onPrimary → Brand/Primary',
          min: textThreshold,
        );
        expectContrast(
          scheme.onSecondary,
          scheme.secondary,
          label: 'onSecondary → Brand/Secondary',
          min: textThreshold,
        );
        expectContrast(
          scheme.onTertiary,
          scheme.tertiary,
          label: 'onTertiary → Brand/Accent',
          min: textThreshold,
        );
        expectContrast(
          scheme.onError,
          scheme.error,
          label: 'onError → error',
          min: textThreshold,
        );
      });

      test('yumuşak dolgular üzerindeki metin okunabilir', () {
        expectContrast(
          scheme.onPrimaryContainer,
          scheme.primaryContainer,
          label: 'onPrimaryContainer → primaryContainer',
          min: textThreshold,
        );
        expectContrast(
          scheme.onSecondaryContainer,
          scheme.secondaryContainer,
          label: 'onSecondaryContainer → secondaryContainer',
          min: textThreshold,
        );
        expectContrast(
          scheme.onTertiaryContainer,
          scheme.tertiaryContainer,
          label: 'onTertiaryContainer → tertiaryContainer',
          min: textThreshold,
        );
      });

      test('durum renkleri zeminde okunabilir', () {
        // Bunlar metin rengi olarak kullanılıyor (uyarı başlığı, hata mesajı),
        // sadece ikon değil — bu yüzden metin eşiği geçerli.
        expectContrast(
          semantic.success,
          scheme.surface,
          label: 'success → zemin',
          min: textThreshold,
        );
        expectContrast(
          semantic.warning,
          scheme.surface,
          label: 'warning → zemin',
          min: textThreshold,
        );
        expectContrast(
          semantic.danger,
          scheme.surface,
          label: 'danger → zemin',
          min: textThreshold,
        );
        expectContrast(
          semantic.premium,
          scheme.surface,
          label: 'premium → zemin',
          min: textThreshold,
        );
      });

      test('kontrol çerçeveleri zeminden ayırt edilebilir', () {
        // `outline` dolgusuz butonların sınırıdır — yani kontrolün kendisi.
        // WCAG 1.4.11 bunun için 3:1 şart koşar.
        expectContrast(
          scheme.outline,
          scheme.surface,
          label: 'outline → zemin',
          min: uiThreshold,
        );
      });

      test('dekoratif çizgiler görünür kalır', () {
        // `outlineVariant` kart kenarı ve ayraçtır; bilgi taşımaz, bu yüzden
        // 3:1 kuralına tabi DEĞİL. Ama açık temada kart rengi zemin rengiyle
        // aynı olduğu için bu çizgi tamamen kaybolursa kartların sınırı yok
        // olur. Düşük ama sıfırdan farklı bir eşik koyuyoruz.
        expectContrast(
          scheme.outlineVariant,
          scheme.surfaceContainerLow,
          label: 'outlineVariant → kart zemini',
          min: 1.1,
        );
      });

      test('SnackBar metni okunabilir', () {
        expectContrast(
          scheme.onInverseSurface,
          scheme.inverseSurface,
          label: 'onInverseSurface → inverseSurface',
          min: textThreshold,
        );
      });
    });
  }
}
