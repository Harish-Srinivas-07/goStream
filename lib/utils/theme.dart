import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.system,
  );

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkTheme');
    if (isDark != null) {
      themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    } else {
      themeNotifier.value = ThemeMode.system;
    }
  }

  static Future<void> toggleTheme(bool isDark) async {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', isDark);
  }

  static bool get isDark => themeNotifier.value == ThemeMode.dark;
}
