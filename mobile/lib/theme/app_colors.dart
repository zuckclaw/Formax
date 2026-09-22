// lib/theme/app_colors.dart
// Token warna parity dengan web (web/src/styles/theme.css).
// Light = nilai existing web. Dark = family #1a1a2e.
// Semua halaman WAJIB pakai ini / Theme.of, jangan hardcode slate
// (0xFF1A1A2E / 0xFF23233F / 0xFF2D2D4A) lagi.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ---------- LIGHT (web :root) ----------
  static const lightBg = Color(0xFFE8EEF6);
  static const lightBgSecondary = Color(0xFFFFFFFF);
  static const lightBgCard = Color(0xFFFFFFFF);
  static const lightBgInput = Color(0xFFFFFFFF);
  static const lightBgInputAlt = Color(0xFFF2F8FF);
  static const lightBgHover = Color(0xFFF1F5F9);

  static const lightTextPrimary = Color(0xFF0F172A);
  static const lightTextBody = Color(0xFF1E293B);
  static const lightTextSecondary = Color(0xFF475569);
  static const lightTextMuted = Color(0xFF64748B);
  static const lightTextFaint = Color(0xFF94A3B8);

  static const lightBorder = Color(0xFFE2E8F0);
  static const lightBorderLight = Color(0xFFEDF2F7);
  static const lightBorderMedium = Color(0xFFCBD5E1);
  static const lightBorderInput = Color(0xFFDCEAF8);

  static const lightAccent = Color(0xFF2563EB);
  static const lightAccentHover = Color(0xFF1D4ED8);
  static const lightAccentLight = Color(0xFFEFF6FF);
  static const lightAccentSoft = Color(0xFFDBEAFE);

  // ---------- DARK (web [data-theme="dark"]) ----------
  static const darkBg = Color(0xFF1A1A2E);
  static const darkBgSecondary = Color(0xFF1E1E3A);
  static const darkBgCard = Color(0xFF23233F);
  static const darkBgInput = Color(0xFF2A2A4A);
  static const darkBgInputAlt = Color(0xFF252545);
  static const darkBgHover = Color(0xFF2E2E55);
  static const darkBgHoverStrong = Color(0xFF38386A);
  static const darkBgSidebar = Color(0xFF131326);

  static const darkTextPrimary = Color(0xFFEEF2FF);
  static const darkTextHeading = Color(0xFFF1F5FF);
  static const darkTextBody = Color(0xFFE2E8F0);
  static const darkTextSecondary = Color(0xFFCBD5E1);
  static const darkTextMuted = Color(0xFF94A3B8);
  static const darkTextFaint = Color(0xFF7A8599);

  static const darkBorder = Color(0xFF2D2D4A);
  static const darkBorderLight = Color(0xFF2A2A4A);
  static const darkBorderMedium = Color(0xFF3A3A5C);
  static const darkBorderStrong = Color(0xFF4A4A6A);

  static const darkAccent = Color(0xFF60A5FA);
  static const darkAccentHover = Color(0xFF93C5FD);
  static const darkAccentLight = Color(0xFF1E293B);
  static const darkAccentSoft = Color(0xFF1E3A5F);

  // ---------- STATUS DARK (web rgba + teks terang) ----------
  static const darkDraftBg = Color(0x2ECA8A04);
  static const darkDraftText = Color(0xFFFDE68A);
  static const darkPublishedBg = Color(0x2E16A34A);
  static const darkPublishedText = Color(0xFF86EFAC);
  static const darkClosedBg = Color(0x2EEF4444);
  static const darkClosedText = Color(0xFFFCA5A5);

  // ---------- STATUS LIGHT ----------
  static const lightDraftBg = Color(0xFFFEF3C7);
  static const lightDraftText = Color(0xFF92400E);
  static const lightPublishedBg = Color(0xFFDCFCE7);
  static const lightPublishedText = Color(0xFF15803D);
  static const lightClosedBg = Color(0xFFFEE2E2);
  static const lightClosedText = Color(0xFF991B1B);

  // ---------- Helper ----------
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? darkBg : lightBg;
  static Color card(BuildContext context) =>
      isDark(context) ? darkBgCard : lightBgCard;
  static Color input(BuildContext context) =>
      isDark(context) ? darkBgInput : lightBgInput;
  static Color hover(BuildContext context) =>
      isDark(context) ? darkBgHover : lightBgHover;
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(BuildContext context) =>
      isDark(context) ? darkTextSecondary : lightTextSecondary;
  static Color textMuted(BuildContext context) =>
      isDark(context) ? darkTextMuted : lightTextMuted;
  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;
  static Color accent(BuildContext context) =>
      isDark(context) ? darkAccent : lightAccent;
}
