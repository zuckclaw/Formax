// lib/widgets/math_tex.dart
// Render KaTeX asli di mobile (parity web katex.renderToString).
// Semua widget di sini TIDAK PERNAH blank/crash: latex kosong → SizedBox,
// latex invalid → fallback teks mentah (seperti web throwOnError:false).

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class MathTex {
  MathTex._();

  /// Fallback saat render gagal: tampilkan latex mentah dengan gaya
  /// monospace (tidak pernah blank, tidak pernah throw).
  static Widget fallback(String latex, {required bool isDark}) {
    return Text(
      latex,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
      ),
    );
  }

  /// Rumus inline (parity web displayMode:false).
  static Widget inline(
    String latex, {
    required bool isDark,
    double fontSize = 14,
  }) {
    final raw = latex.trim();
    if (raw.isEmpty) return const SizedBox.shrink();
    return Math.tex(
      raw,
      mathStyle: MathStyle.text,
      textStyle: TextStyle(
        fontSize: fontSize,
        color: isDark ? const Color(0xFFEEF2FF) : const Color(0xFF0F172A),
      ),
      onErrorFallback: (_) => fallback(raw, isDark: isDark),
    );
  }

  /// Rumus display / blok tengah (parity web displayMode:true).
  static Widget display(
    String latex, {
    required bool isDark,
    double fontSize = 16,
  }) {
    final raw = latex.trim();
    if (raw.isEmpty) return const SizedBox.shrink();
    return Math.tex(
      raw,
      mathStyle: MathStyle.display,
      textStyle: TextStyle(
        fontSize: fontSize,
        color: isDark ? const Color(0xFFEEF2FF) : const Color(0xFF0F172A),
      ),
      onErrorFallback: (_) => fallback(raw, isDark: isDark),
    );
  }

  /// Validasi ringan ala web (katex throwOnError): kurung seimbang +
  /// tidak ada backslash menggantung. Dipakai untuk state tombol Sisipkan.
  static bool looksValid(String latex) {
    final s = latex.trim();
    if (s.isEmpty) return false;
    if (s.endsWith(r'\')) return false;
    var braces = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '{') braces++;
      if (c == '}') {
        braces--;
        if (braces < 0) return false;
      }
    }
    return braces == 0;
  }
}
