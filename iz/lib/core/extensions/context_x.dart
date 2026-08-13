/// `BuildContext` kısayolları — widget kodunu okunur tutar.
///
/// `Theme.of(context).textTheme.titleMedium` yerine `context.text.titleMedium`.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_colors.dart';
import 'package:iz/core/theme/app_typography.dart';

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// İZ'e özel anlamsal renkler (success/warning/danger/premium).
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;

  /// Material'ın TextTheme yuvalarına sığmayan tasarım stilleri
  /// (`bodyTiny`, `statValue`). Bkz. app_typography.dart.
  AppTextStyles get textStyles => Theme.of(this).extension<AppTextStyles>()!;

  /// Çeviriler: `context.l10n.memoriesTitle`
  AppL10n get l10n => AppL10n.of(this);

  MediaQueryData get media => MediaQuery.of(this);
  Size get screenSize => MediaQuery.sizeOf(this);
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Tablet/geniş ekran ayrımı — Studio ve timeline düzeni için.
  bool get isCompact => MediaQuery.sizeOf(this).width < 600;

  /// Klavye açık mı?
  bool get isKeyboardOpen => MediaQuery.viewInsetsOf(this).bottom > 0;

  // --- Kısa yardımcılar -----------------------------------------------------

  void showSnack(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  /// NFR-034: "Kritik silme/paylaşma/sipariş işlemlerinde açık onay ve geri
  /// bildirim bulunmalıdır." Yıkıcı işlemler bu diyalogdan geçmeli.
  Future<bool> confirm({
    required String title,
    required String message,
    required String confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: this,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel ?? dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: dialogContext.colors.error,
                    foregroundColor: dialogContext.colors.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
