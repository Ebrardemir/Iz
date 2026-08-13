/// Ayarlar sekmesi — FR-003, FR-046, FR-162, FR-163.
///
/// Bu ekran ÇALIŞIYOR: tema ve dil tercihleri `AppPreferences`e yazılıyor,
/// yedekleme durumu kartı R-001 riskini kullanıcıya görünür kılıyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/extensions/date_x.dart';
import 'package:iz/core/l10n/app_languages.dart';
import 'package:iz/core/storage/app_preferences.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/settings/presentation/view_models/settings_view_model.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final viewModel = ref.read(settingsProvider.notifier);
    final prefs = ref.watch(appPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          // --- R-001 / FR-162: yedekleme durumu -------------------------
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _BackupStatusCard(lastExportAt: prefs.lastExportAt),
          ),

          const Divider(),

          _SectionHeader(title: l10n.settingsAppearance),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (mode) {
              if (mode != null) viewModel.setThemeMode(mode);
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text(l10n.settingsThemeSystem),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text(l10n.settingsThemeLight),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text(l10n.settingsThemeDark),
                ),
              ],
            ),
          ),

          const Divider(),

          _SectionHeader(title: l10n.settingsLanguage),
          RadioGroup<String?>(
            groupValue: settings.locale?.languageCode,
            onChanged: viewModel.setLanguageCode,
            child: Column(
              children: [
                RadioListTile<String?>(
                  value: null,
                  title: Text(l10n.settingsLanguageSystem),
                ),
                // DİKKAT: Dil adları ÇEVRİLMEZ. Bir dil kendi adıyla yazılır
                // ("Türkçe", "English") — İngilizce arayüzde "Turkish" yazsaydı
                // Türkçe bilen kullanıcı kendi dilini bulamazdı. Bu, l10n
                // kuralının bilinçli ve standart istisnasıdır.
                for (final language in AppLanguages.all)
                  RadioListTile<String?>(
                    value: language.code,
                    title: Text(language.nativeName),
                  ),
              ],
            ),
          ),

          const Divider(),

          _SectionHeader(title: l10n.settingsNotifications),
          SwitchListTile(
            title: Text(l10n.todaysTraceTitle),
            subtitle: Text(l10n.todaysTraceSubtitle),
            value: settings.todaysTraceEnabled,
            onChanged: (value) => viewModel.setTodaysTrace(enabled: value),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(AppIcons.storage),
            title: Text(l10n.settingsStorage),
            // TODO(storage): FR-046 depolama kullanımı ekranı.
            trailing: const Icon(AppIcons.forward),
            onTap: null,
          ),
          ListTile(
            leading: const Icon(AppIcons.privacy),
            title: Text(l10n.settingsPrivacy),
            trailing: const Icon(AppIcons.forward),
            onTap: null,
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// R-001'in azaltımı: "Yedekleme sağlık ekranı, export, risk mesajı".
/// Kullanıcı verisinin risk altında olduğunu SAKLAMIYORUZ.
class _BackupStatusCard extends StatelessWidget {
  const _BackupStatusCard({this.lastExportAt});

  final DateTime? lastExportAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final warning = context.semanticColors.warning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.device, color: warning),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.backupLocalOnly,
                  style: context.text.titleSmall?.copyWith(color: warning),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.backupLocalOnlyDetail, style: context.text.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              lastExportAt == null
                  ? l10n.backupNeverExported
                  : l10n.backupLastExport(AppDateFormats.medium(lastExportAt!)),
              style: context.text.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              // TODO(export): FR-160/161 dışa aktarma akışı.
              onPressed: null,
              icon: const Icon(AppIcons.share),
              label: Text(l10n.backupExportNow),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: context.text.labelLarge?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
