/// Boş durum ekranı.
///
/// NFR-035: "Boş durum ekranları kullanıcıya ne yapacağını açıklamalıdır;
/// '0 kayıt' gibi teknik boşluk bırakılmamalıdır."
///
/// Bu yüzden widget bir eylem butonu (`actionLabel` + `onAction`) almayı
/// teşvik eder — kullanıcı boş ekranda ne yapacağını bilsin.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: AppIconSize.xl,
                color: context.colors.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              title,
              style: context.text.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
