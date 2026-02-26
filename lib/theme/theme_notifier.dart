import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/theme_preferences.dart';

/// Notifies the app when theme mode changes. Persists choice via [ThemePreferences].
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier._();
  static ThemeNotifier? _instance;
  static ThemeNotifier get instance {
    if (_instance == null) {
      _instance = ThemeNotifier._();
    }
    return _instance!;
  }

  ThemeMode _themeMode = ThemeMode.system;
  String _themeStyle = ThemePreferences.styleDefault;

  ThemeMode get themeMode => _themeMode;
  String get themeStyle => _themeStyle;
  bool get isAesthetic => _themeStyle == ThemePreferences.styleAesthetic;

  /// Load saved theme mode and style (call from main before runApp).
  Future<void> load() async {
    final mode = await ThemePreferences.instance.getThemeMode();
    final style = await ThemePreferences.instance.getThemeStyle();
    if (mode != _themeMode || style != _themeStyle) {
      _themeMode = mode;
      _themeStyle = style;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await ThemePreferences.instance.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setThemeStyle(String style) async {
    if (_themeStyle == style) return;
    _themeStyle = style;
    await ThemePreferences.instance.setThemeStyle(style);
    notifyListeners();
  }
}
