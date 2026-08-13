/// Ayarlar ViewModel'i — FR-003.
///
/// BASİT AMA ÖĞRETİCİ ÖRNEK:
/// Tema ve dil hem kalıcı olmalı (SharedPreferences) hem de değişince
/// uygulama anında tepki vermeli. ViewModel state'i bellekte tutar,
/// her değişimde diske yazar. `MaterialApp` bu state'i izler.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/storage/app_preferences.dart';

final class SettingsState {
  const SettingsState({
    required this.themeMode,
    required this.todaysTraceEnabled,
    this.locale,
  });

  final ThemeMode themeMode;

  /// null → cihaz dilini kullan.
  final Locale? locale;
  final bool todaysTraceEnabled;

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? todaysTraceEnabled,
    bool clearLocale = false,
  }) => SettingsState(
    themeMode: themeMode ?? this.themeMode,
    locale: clearLocale ? null : (locale ?? this.locale),
    todaysTraceEnabled: todaysTraceEnabled ?? this.todaysTraceEnabled,
  );
}

class SettingsViewModel extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.watch(appPreferencesProvider);
    return SettingsState(
      themeMode: prefs.themeMode,
      locale: prefs.locale,
      todaysTraceEnabled: prefs.todaysTraceEnabled,
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    unawaited(ref.read(appPreferencesProvider).setThemeMode(mode));
  }

  /// null → sistem dili.
  void setLanguageCode(String? code) {
    final locale = code == null ? null : Locale(code);
    state = state.copyWith(locale: locale, clearLocale: code == null);
    unawaited(ref.read(appPreferencesProvider).setLocale(locale));
  }

  /// FR-081 — Bugünün İzi bildirimi ayrı açılıp kapanabilmeli.
  void setTodaysTrace({required bool enabled}) {
    state = state.copyWith(todaysTraceEnabled: enabled);
    unawaited(
      ref.read(appPreferencesProvider).setTodaysTraceEnabled(value: enabled),
    );
  }
}

final settingsProvider = NotifierProvider<SettingsViewModel, SettingsState>(
  SettingsViewModel.new,
);
