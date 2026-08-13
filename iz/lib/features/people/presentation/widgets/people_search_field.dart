/// Kişiler listesinin arama alanı.
///
/// NEDEN AYRI BİLEŞEN, NEDEN ÇIPLAK `TextField` DEĞİL?
/// Uygulamanın `inputDecorationTheme`ı form alanları için ayarlı: dolu zemin,
/// çerçeve, 48 piksel asgari yükseklik. Arama alanı bir form alanı değil —
/// referansta yumuşak yuvarlak köşeli, çerçevesiz, sol tarafında bir büyüteç
/// olan bir şerit. Her kullanımda o sekiz satırlık `InputDecoration`ı tekrar
/// etmek yerine tek yerde topladık.
///
/// SAF WIDGET: sorguyu yukarı bildiriyor, süzme işini yapmıyor
/// (bkz. `filterPeople`).
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';

class PeopleSearchField extends StatelessWidget {
  const PeopleSearchField({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: context.text.bodyMedium?.copyWith(color: colors.onSurface),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: colors.surfaceContainerLow,
        hintText: l10n.peopleSearchHint,
        hintStyle: context.text.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        prefixIcon: Icon(
          AppIcons.search,
          size: AppIconSize.md,
          color: colors.onSurfaceVariant,
        ),
        // Yazı varken temizleme düğmesi. Aramayı iptal etmek için alanı tek
        // tek silmek gerekmesin — listeyi geri getirmenin tek dokunuşu olmalı.
        suffixIcon: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(AppIcons.clear),
                  iconSize: AppIconSize.md,
                  color: colors.onSurfaceVariant,
                  tooltip: l10n.peopleSearchClear,
                ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        // Yumuşak ve tam yuvarlak kenar: alan bir kutu değil bir ŞERİT gibi
        // okunmalı. Çerçeve yok; zemin farkı yeterli.
        border: _border(colors.surfaceContainerLow),
        enabledBorder: _border(colors.outlineVariant),
        focusedBorder: _border(colors.primary),
      ),
    );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(28)),
    borderSide: BorderSide(color: color),
  );
}
