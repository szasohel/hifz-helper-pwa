import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/constants.dart';

class AppSettings {
  final String activeScript;   // 'uthmani' or 'indopak'
  final String activeReciter;  // 'alafasy' or 'husary'
  final ThemeMode themeMode;   // ThemeMode.light, ThemeMode.dark, ThemeMode.system

  AppSettings({
    this.activeScript = 'uthmani',
    this.activeReciter = AppConstants.reciterHusary,
    this.themeMode = ThemeMode.light,
  });

  AppSettings copyWith({
    String? activeScript,
    String? activeReciter,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      activeScript: activeScript ?? this.activeScript,
      activeReciter: activeReciter ?? this.activeReciter,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _loadSettings();
    return AppSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final script = prefs.getString(AppConstants.keyActiveScript) ?? 'uthmani';
    final reciter = prefs.getString(AppConstants.keyActiveReciter) ?? AppConstants.reciterHusary;
    final themeStr = prefs.getString(AppConstants.keyThemeMode) ?? 'light';

    ThemeMode mode = ThemeMode.light;
    if (themeStr == 'dark') mode = ThemeMode.dark;
    if (themeStr == 'system') mode = ThemeMode.system;

    state = AppSettings(
      activeScript: script,
      activeReciter: reciter,
      themeMode: mode,
    );
  }

  Future<void> setScript(String script) async {
    state = state.copyWith(activeScript: script);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyActiveScript, script);
  }

  Future<void> setReciter(String reciter) async {
    state = state.copyWith(activeReciter: reciter);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyActiveReciter, reciter);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    final modeStr = mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system');
    await prefs.setString(AppConstants.keyThemeMode, modeStr);
  }

  Future<void> toggleDayNight() async {
    final newMode = state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

