/// Etiketi ÜSTTE duran form alanı: kalın bir başlık, altında yuvarlak köşeli
/// bir girdi kutusu.
///
/// NEDEN ANI FORMUNDAKİ DÜZEN DEĞİL?
/// Orada satırlar yatay: solda ikon ve etiket, sağda değer. O düzen ÇOK alanı
/// az yere sığdırmak için doğru — anı formunda sekiz satır var. Burada dört
/// alan var ve her biri kullanıcıdan bir cümle istiyor; etiketi üste almak
/// hem girdiye tam genişlik veriyor hem "(Opsiyonel)" gibi bir ek için yer
/// açıyor.
///
/// "(OPSİYONEL)" ETİKETİN PARÇASI, ipucu metni değil.
/// İpucuna yazsaydık kullanıcı yazmaya başladığı an kaybolurdu; oysa bilgi
/// alanın kendisine ait ve her zaman görünmeli. Kalın başlığın yanında ince
/// ve soluk duruyor — bir uyarı değil, bir izin.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';

class IzLabeledField extends StatelessWidget {
  const IzLabeledField({
    required this.label,
    required this.child,
    this.isOptional = false,
    super.key,
  });

  final String label;

  /// Girdi — metin alanı, tarih alanı, ne olursa.
  final Widget child;

  /// Etiketin yanına "(Opsiyonel)" eklenir.
  final bool isOptional;

  /// Etiket ile girdi arası.
  static const double _kGap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `Text.rich`: iki parça AYNI satırda ama farklı ağırlıkta. İki ayrı
        // `Text`i `Row`a koymak, uzun bir etiket sarınca ikisini ayırırdı.
        Text.rich(
          TextSpan(
            text: label,
            style: context.text.bodyMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            children: [
              if (isOptional)
                TextSpan(
                  text: ' ${context.l10n.formOptional}',
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: _kGap),
        child,
      ],
    );
  }
}

/// [IzLabeledField] içindeki metin girdisi.
///
/// NEDEN AYRI BİLEŞEN?
/// Uygulamanın `inputDecorationTheme`ı giriş/kayıt formları için ayarlı: dolu
/// zemin, belirgin çerçeve. Buradaki kutu referansta daha sessiz — ince
/// kenarlık, yumuşak köşe, kart zemininden bir tık açık. Her alanda aynı sekiz
/// satırlık `InputDecoration`ı tekrar etmek yerine tek yerde topladık.
class IzFieldInput extends StatelessWidget {
  const IzFieldInput({
    required this.controller,
    this.hintText,
    this.onChanged,
    this.errorText,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.readOnly = false,
    this.onTap,
    this.suffix,
    super.key,
  });

  final TextEditingController controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  /// Yalnızca dokunmayla doldurulan alanlar için (tarih seçici gibi).
  final bool readOnly;
  final VoidCallback? onTap;

  /// Kutunun sağındaki düğme — takvim ikonu gibi.
  final Widget? suffix;

  /// Kutunun köşe yarıçapı.
  ///
  /// Arama alanı tam yuvarlak (28), form kutuları daha ölçülü: referansta
  /// köşeler yumuşak ama kutu hâlâ bir kutu.
  static const Radius kRadius = Radius.circular(14);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: context.text.bodyMedium?.copyWith(color: colors.onSurface),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: colors.surfaceContainerLow,
        hintText: hintText,
        hintStyle: context.text.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        suffixIcon: suffix,
        errorText: errorText,
        // Sayaç gösterilmiyor: kutunun altında "12/60" yazısı formun dikey
        // ritmini bozuyor ve sınıra dayanınca yazı zaten girmiyor.
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: _border(colors.outlineVariant),
        enabledBorder: _border(colors.outlineVariant),
        focusedBorder: _border(colors.primary),
        errorBorder: _border(colors.error),
        focusedErrorBorder: _border(colors.error),
      ),
    );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: const BorderRadius.all(kRadius),
    borderSide: BorderSide(color: color),
  );
}
