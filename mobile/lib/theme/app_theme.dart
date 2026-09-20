// lib/theme/app_theme.dart
// ThemeData light/dark parity dengan web (web/src/styles/theme.css).
// Dark memakai family #1a1a2e, bukan slate bawaan Material.

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF2563EB); // web --accent light

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: _seed);
    return ThemeData(
      colorScheme: scheme.copyWith(
        surface: AppColors.lightBgCard,
        onSurface: AppColors.lightTextPrimary,
        onSurfaceVariant: AppColors.lightTextSecondary,
        outline: AppColors.lightBorderMedium,
        outlineVariant: AppColors.lightBorder,
        primary: AppColors.lightAccent,
        onPrimary: Colors.white,
        secondary: AppColors.lightAccent,
      ),
      scaffoldBackgroundColor: AppColors.lightBg,
      cardColor: AppColors.lightBgCard,
      dividerColor: AppColors.lightBorder,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBgCard,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0.5,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.lightBgCard,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightBgInput,
        hintStyle: TextStyle(color: AppColors.lightTextFaint),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightBgCard,
        selectedItemColor: AppColors.lightAccent,
        unselectedItemColor: AppColors.lightTextMuted,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.lightBgCard,
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: scheme.copyWith(
        surface: AppColors.darkBgCard,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
        outline: AppColors.darkBorderMedium,
        outlineVariant: AppColors.darkBorder,
        primary: AppColors.darkAccent,
        onPrimary: AppColors.darkBgCard,
        secondary: AppColors.darkAccent,
        surfaceContainerHighest: AppColors.darkBgHover,
        surfaceContainer: AppColors.darkBgSecondary,
      ),
      scaffoldBackgroundColor: AppColors.darkBg,
      cardColor: AppColors.darkBgCard,
      dividerColor: AppColors.darkBorder,
      canvasColor: AppColors.darkBgCard,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBgCard,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.darkBgCard,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkBgInput,
        hintStyle: TextStyle(color: AppColors.darkTextFaint),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkBgCard,
        selectedItemColor: AppColors.darkAccent,
        unselectedItemColor: AppColors.darkTextMuted,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkBgCard,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkBgCard,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.darkBgCard,
      ),
    );
  }
}
