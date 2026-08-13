/// Küçük, hassas OLMAYAN tercihler (tema, onboarding görüldü mü, dil).
///
/// Hassas veri (token, şifreleme anahtarı) BURAYA YAZILMAZ —
/// NFR-011 gereği [SecureStore] kullanılır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class AppPreferences {
  const AppPreferences(this._prefs);
  final SharedPreferences _prefs;

  static const _kOnboardingCompleted = 'onboarding_completed';
  static const _kThemeMode = 'theme_mode';
  static const _kLocale = 'locale';
  static const _kTodaysTraceEnabled = 'todays_trace_enabled';
  static const _kLastExportAt = 'last_export_at';

  // FR-004 — onboarding akışı
  bool get onboardingCompleted =>
      _prefs.getBool(_kOnboardingCompleted) ?? false;
  Future<void> setOnboardingCompleted({required bool value}) =>
      _prefs.setBool(_kOnboardingCompleted, value);

  // FR-003 — kullanıcı tercihleri
  ThemeMode get themeMode => switch (_prefs.getString(_kThemeMode)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);

  /// null = cihaz dilini kullan.
  Locale? get locale {
    final code = _prefs.getString(_kLocale);
    return code == null ? null : Locale(code);
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale == null) {
      await _prefs.remove(_kLocale);
    } else {
      await _prefs.setString(_kLocale, locale.languageCode);
    }
  }

  // FR-081 — Bugünün İzi bildirimi ayrı açılıp kapanabilmeli
  bool get todaysTraceEnabled => _prefs.getBool(_kTodaysTraceEnabled) ?? true;
  Future<void> setTodaysTraceEnabled({required bool value}) =>
      _prefs.setBool(_kTodaysTraceEnabled, value);

  // FR-162 — Yedekleme Durumu ekranı son export tarihini gösterir
  DateTime? get lastExportAt {
    final iso = _prefs.getString(_kLastExportAt);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<void> setLastExportAt(DateTime value) =>
      _prefs.setString(_kLastExportAt, value.toIso8601String());
}

/// bootstrap içinde gerçek örnekle override edilir.
/// Override edilmeden okunursa bilinçli olarak patlar — sessiz hata olmasın.
final appPreferencesProvider = Provider<AppPreferences>((ref) {
  throw UnimplementedError(
    'appPreferencesProvider bootstrap içinde override edilmeli. '
    'Bkz. lib/app/bootstrap.dart',
  );
});
