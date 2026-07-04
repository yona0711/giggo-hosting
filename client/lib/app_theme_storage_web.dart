// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

const _themeModeKey = 'giggo.themeMode';

Future<String?> loadThemeModeName() async {
  return html.window.localStorage[_themeModeKey];
}

Future<void> saveThemeModeName(String value) async {
  html.window.localStorage[_themeModeKey] = value;
}
