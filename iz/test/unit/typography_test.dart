/// Tipografi ölçeği KORUMA testi.
///
/// NEDEN BU TEST VAR?
/// Bir ekranı düzenlerken `titleMedium`ın puntosunu 14'ten 16'ya çekmek
/// bir saniyelik iştir ve o an mantıklı görünür — ama o stil 20 ekranda
/// kullanılıyordur ve tasarımla arası açılır. Bu test ölçeği Figma'ya
/// çiviliyor: değiştirmek istiyorsan testi de bilerek değiştirmen gerekir.
///
/// Aşağıdaki tablo Figma tipografi ölçeğinin birebir kopyasıdır.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/core/theme/app_typography.dart';

/// Figma çıktısındaki değerler: punto ve **piksel** satır yüksekliği.
typedef _Spec = ({
  String family,
  double size,
  FontWeight weight,
  double lineHeightPx,
});

void main() {
  final theme = AppTheme.light();
  final text = theme.textTheme;

  const display = AppFonts.display;
  const body = AppFonts.body;

  const w400 = FontWeight.w400;
  const w500 = FontWeight.w500;
  const w600 = FontWeight.w600;

  /// Figma ölçeği → Material yuvası eşlemesi.
  ///
  /// Cormorant satır yüksekliği tasarımdan İKİ kez geldi: H1 28 → 36 ve
  /// H2 24 → 32. İkisi de "punto + 8" kuralına uyuyor; ölçeğin öteki
  /// basamakları da onu sürdürüyor. Değişirse hem burası hem
  /// `app_typography.dart` güncellenecek.
  final expected = <String, (TextStyle?, _Spec)>{
    // --- Cormorant Garamond SemiBold ---
    'Display 48': (
      text.displayLarge,
      (family: display, size: 48, weight: w600, lineHeightPx: 48 + 8),
    ),
    'Display 36': (
      text.displayMedium,
      (family: display, size: 36, weight: w600, lineHeightPx: 36 + 8),
    ),
    'H1 28': (
      text.headlineLarge,
      (family: display, size: 28, weight: w600, lineHeightPx: 28 + 8),
    ),
    'H2 24': (
      text.headlineMedium,
      (family: display, size: 24, weight: w600, lineHeightPx: 24 + 8),
    ),
    'H3 20': (
      text.headlineSmall,
      (family: display, size: 20, weight: w600, lineHeightPx: 20 + 8),
    ),

    // --- Poppins (satır yükseklikleri Figma çıktısından) ---
    'Body Large 20 SemiBold': (
      text.titleLarge,
      (family: body, size: 20, weight: w600, lineHeightPx: 16),
    ),
    'Label 14 Medium': (
      text.titleMedium,
      (family: body, size: 14, weight: w500, lineHeightPx: 20),
    ),
    'Body Small-medium 12': (
      text.titleSmall,
      (family: body, size: 12, weight: w500, lineHeightPx: 18),
    ),
    'Body Large 16': (
      text.bodyLarge,
      (family: body, size: 16, weight: w400, lineHeightPx: 24),
    ),
    'Body 14': (
      text.bodyMedium,
      (family: body, size: 14, weight: w400, lineHeightPx: 20),
    ),
    'Body Small-1 12': (
      text.bodySmall,
      (family: body, size: 12, weight: w400, lineHeightPx: 18),
    ),
    'Button 14 SemiBold': (
      text.labelLarge,
      (family: body, size: 14, weight: w600, lineHeightPx: 20),
    ),
    'Caption/Stat 12 Medium': (
      text.labelMedium,
      (family: body, size: 12, weight: w500, lineHeightPx: 16),
    ),
    'Stat/Label 10 Medium': (
      text.labelSmall,
      (family: body, size: 10, weight: w500, lineHeightPx: 16),
    ),
  };

  group('tipografi ölçeği Figma ile aynı', () {
    expected.forEach((label, pair) {
      final (style, spec) = pair;

      test(label, () {
        expect(style, isNotNull, reason: '$label için stil tanımlı değil');
        expect(
          style!.fontFamily,
          spec.family,
          reason: '$label yanlış yazı tipiyle tanımlanmış',
        );
        expect(style.fontSize, spec.size, reason: '$label punto değişmiş');
        expect(
          style.fontWeight,
          spec.weight,
          reason: '$label ağırlık değişmiş',
        );

        // Flutter `height`i ORAN tutar; Figma px verir. Karşılaştırmayı
        // px'e çevirerek yapıyoruz ki hata mesajı tasarımla aynı dili konuşsun.
        expect(
          style.height! * style.fontSize!,
          closeTo(spec.lineHeightPx, 0.01),
          reason:
              '$label satır yüksekliği değişmiş '
              '(Figma: ${spec.lineHeightPx}px)',
        );

        // Figma'nın tamamında letter-spacing 0. Material 3 etiket stillerine
        // kendiliğinden aralık ekler; bu kontrol onu yakalar.
        expect(style.letterSpacing, 0, reason: '$label harf aralığı 0 olmalı');
      });
    });
  });

  group('Material yuvasına sığmayan stiller', () {
    final extra = theme.extension<AppTextStyles>();

    test('tema uzantısı bağlanmış', () {
      expect(
        extra,
        isNotNull,
        reason: 'AppTextStyles temaya eklenmemiş — context.textStyles patlar',
      );
    });

    test('Body Small 10 Regular — 10/18', () {
      expect(extra!.bodyTiny.fontFamily, body);
      expect(extra.bodyTiny.fontSize, 10);
      expect(extra.bodyTiny.fontWeight, w400);
      expect(extra.bodyTiny.height! * 10, closeTo(18, 0.01));
    });

    test('Caption 12 Regular — 12/16', () {
      expect(extra!.caption.fontFamily, body);
      expect(extra.caption.fontSize, 12);
      expect(extra.caption.fontWeight, w400);
      expect(extra.caption.height! * 12, closeTo(16, 0.01));

      // Figma'da iki farklı 12 Regular var; ayrımı satır yüksekliği yapıyor.
      // İkisi eşitlenirse tasarımdaki fark kaybolmuş demektir.
      final bodySmall = theme.textTheme.bodySmall!;
      expect(
        extra.caption.height,
        isNot(bodySmall.height),
        reason: 'Caption (12/16) ile Body Small-1 (12/18) aynı olmamalı',
      );
    });

    test('Stat/Value 20 Medium — 20/24', () {
      expect(extra!.statValue.fontFamily, body);
      expect(extra.statValue.fontSize, 20);
      // titleLarge da 20 ama SemiBold ve satır yüksekliği 16; karışmamalı.
      expect(extra.statValue.fontWeight, w500);
      expect(extra.statValue.height! * 20, closeTo(24, 0.01));
      expect(theme.textTheme.titleLarge!.fontWeight, w600);
    });
  });

  test('koyu tema aynı ölçeği kullanır, sadece rengi değişir', () {
    final dark = AppTheme.dark().textTheme;

    expect(dark.headlineLarge!.fontSize, text.headlineLarge!.fontSize);
    expect(dark.bodyMedium!.fontSize, text.bodyMedium!.fontSize);
    expect(dark.bodyMedium!.color, isNot(text.bodyMedium!.color));
  });

  test('değişken font ağırlık ekseni açıkça veriliyor', () {
    // Cormorant değişken fonttur; `wght` ekseni verilmezse bazı platformlarda
    // Regular olarak çizilir ve başlıklar inceleyip tasarımdan uzaklaşır.
    final axes = text.headlineLarge!.fontVariations;

    expect(axes, isNotNull, reason: 'başlıklarda fontVariations tanımlı değil');
    expect(
      axes!.any((a) => a.axis == 'wght' && a.value == 600),
      isTrue,
      reason: 'wght ekseni 600 olarak verilmeli',
    );
  });

  group('gerçek font dosyası', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await (FontLoader(AppFonts.display)..addFont(
            rootBundle.load('assets/fonts/CormorantGaramond-Variable.ttf'),
          ))
          .load();
    });

    test('wght ekseninin çizime GERÇEKTEN etkisi var', () {
      // Yukarıdaki test yalnızca "parametreyi verdik mi" diye bakar.
      // Bu test bir adım öteye gidip ekseni fontun gerçekten UYGULADIĞINI
      // ölçüyor: dosya statik bir sürümle değiştirilirse ağırlık artık
      // değişmez ve başlıklar sessizce inceleşir — burada yakalanır.
      double widthAt(double weight) => (TextPainter(
        text: TextSpan(
          text: 'Anılarım',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 48,
            fontVariations: [FontVariation('wght', weight)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout()).width;

      expect(
        widthAt(600),
        greaterThan(widthAt(400)),
        reason: 'wght ekseni uygulanmıyor — font statik olabilir',
      );
    });
  });
}
