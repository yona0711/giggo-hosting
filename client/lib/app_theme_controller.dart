import 'package:flutter/material.dart';

import 'app_theme_storage.dart';

final ValueNotifier<ThemeMode> appThemeMode =
    ValueNotifier<ThemeMode>(ThemeMode.system);

ThemeMode _themeModeFromName(String? value) {
  switch (value) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    case 'system':
      return ThemeMode.system;
    default:
      return ThemeMode.system;
  }
}

String _themeModeName(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.light:
      return 'light';
    case ThemeMode.system:
      return 'system';
  }
}

Future<void> loadSavedThemeMode() async {
  appThemeMode.value = _themeModeFromName(await loadThemeModeName());
}

Future<void> setAppThemeMode(ThemeMode mode) async {
  appThemeMode.value = mode;
  await saveThemeModeName(_themeModeName(mode));
}
