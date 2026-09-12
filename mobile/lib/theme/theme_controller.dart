// lib/theme/theme_controller.dart
// Controller tema (light/dark) dengan persistensi SharedPreferences.
// Parity dengan web: web memakai localStorage('theme') + prefers-color-scheme;
// di sini default mengikuti sistem (ThemeMode.system) sampai user memilih manual.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefKey = 'theme';

  ThemeMode _mode = ThemeMode.system; // default: ikuti OS
  ThemeMode get mode => _mode;
  bool get isDark =>
      _mode == ThemeMode.dark ||
      (_mode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  /// Muat preferensi tersimpan sebelum runApp.
  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final saved = sp.getString(_prefKey);
      _mode = switch (saved) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
      notifyListeners();
    } catch (_) {
      _mode = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_prefKey, mode.name);
    } catch (_) {
      // persistensi gagal — abaikan, tema tetap berubah di sesi ini
    }
  }

  Future<void> toggle() async {
    // Sama seperti web: toggle antara light & dark.
    await setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
