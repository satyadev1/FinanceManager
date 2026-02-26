import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyThemeMode = 'theme_mode';
const String _keyThemeStyle = 'theme_style';

/// Persists and loads theme mode (light / dark / system) and theme style (default / aesthetic).
class ThemePreferences {
  ThemePreferences._();
  static final ThemePreferences instance = ThemePreferences._();

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyThemeMode);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_keyThemeMode, value);
  }

  static const String styleDefault = 'default';
  static const String styleAesthetic = 'aesthetic';

  Future<String> getThemeStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeStyle) ?? styleDefault;
  }

  Future<void> setThemeStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeStyle, style);
  }
}
