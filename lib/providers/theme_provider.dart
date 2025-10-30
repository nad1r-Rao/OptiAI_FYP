import 'package:flutter/material.dart';

/// A provider class for managing the application's theme.
///
/// This class allows switching between light and dark themes and notifies
/// listeners of any changes. It uses [ChangeNotifier] to manage the state.
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  /// The current theme mode of the application.
  ThemeMode get themeMode => _themeMode;

  /// A boolean that is `true` if the current theme is dark mode.
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Toggles the application's theme between dark and light mode.
  ///
  /// [isOn] If `true`, sets the theme to dark mode. Otherwise, sets it to light mode.
  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
