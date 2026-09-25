import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Helper untuk menyimpan dan memulihkan pengaturan formulir (form settings)
/// ke dalam metadata template.
///
/// Menggunakan dual-layer persistence:
/// 1. Root fields (native API columns di backend modern)
/// 2. Embedded metadata di HTML description (<div class="form-settings-meta" data-value="BASE64"></div>)
///    dan questions[0].settings['__form_settings__'].
///
/// Hal ini menjamin bahwa seluruh fitur:
/// - Paksa layar penuh (require_fullscreen)
/// - Perlu token (use_join_token)
/// - Acak soal per bagian (shuffle_questions)
/// - Acak opsi jawaban (shuffle_options)
/// - Responden dapat melihat hasil (allow_see_result)
/// - Jawaban benar (reveal_answers)
/// - Tema tampilan (theme)
/// - Jadwal & timer formulir: waktu mulai & waktu selesai (start_date, end_date)
/// - Batas respons (max_submissions)
/// - Terima respons (accept_responses)
///
/// TETAP TERSIMPAN DAN TERSALIN 100% baik saat backend sudah dimigrasikan
/// maupun saat backend masih menggunakan skema lama.
class FormSettingsMeta {
  static const String metaMarker = 'form-settings-meta';

  /// Ekstrak settings dari berbagai kemungkinan layer (root map, description HTML, questions).
  static Map<String, dynamic> extractSettings({
    Map<dynamic, dynamic>? root,
    String? descriptionHtml,
    List<dynamic>? questions,
  }) {
    final Map<String, dynamic> result = {};

    // 1. Ekstrak dari embedded metadata di descriptionHtml
    final desc = descriptionHtml ?? root?['description']?.toString();
    if (desc != null && desc.contains(metaMarker)) {
      try {
        final match = RegExp(
          r'class="form-settings-meta"[^>]*data-value="([^"]+)"',
        ).firstMatch(desc);
        if (match != null && match.group(1) != null) {
          final rawB64 = match.group(1)!;
          final jsonStr = utf8.decode(base64Decode(rawB64));
          final decoded = jsonDecode(jsonStr);
          if (decoded is Map) {
            decoded.forEach((k, v) {
              if (v != null) result[k.toString()] = v;
            });
          }
        }
      } catch (e) {
        debugPrint('[FormSettingsMeta] Gagal decode description meta: $e');
      }
    }

    // 2. Ekstrak dari questions[0].settings['__form_settings__']
    final qs = questions ?? (root?['questions'] is List ? root!['questions'] as List : null);
    if (qs != null && qs.isNotEmpty) {
      try {
        final firstQ = qs.first;
        if (firstQ is Map) {
          final qSettings = firstQ['settings'];
          if (qSettings is Map && qSettings['__form_settings__'] is Map) {
            final map = qSettings['__form_settings__'] as Map;
            map.forEach((k, v) {
              if (v != null) result[k.toString()] = v;
            });
          }
        }
      } catch (e) {
        debugPrint('[FormSettingsMeta] Gagal decode questions meta: $e');
      }
    }

    // 3. Timpa/lengkapi dengan root properties
    if (root != null) {
      // Boolean flags: jika salah satu true, maka true (melindungi jika backend mengembalikan default false)
      for (final boolKey in [
        'allow_see_result',
        'require_fullscreen',
        'reveal_answers',
        'shuffle_questions',
        'shuffle_options',
        'use_join_token',
      ]) {
        final rootVal = root.containsKey(boolKey) && root[boolKey] == true;
        final metaVal = result[boolKey] == true;
        result[boolKey] = rootVal || metaVal;
      }

      // accept_responses: default true, tapi jika salah satu explicitly false, maka false
      if (root.containsKey('accept_responses') && root['accept_responses'] != null) {
        if (root['accept_responses'] == false || result['accept_responses'] == false) {
          result['accept_responses'] = false;
        } else {
          result['accept_responses'] = true;
        }
      }

      // max_submissions: jika root > 0 gunakan root, jika tidak gunakan meta jika ada
      if (root.containsKey('max_submissions') && root['max_submissions'] != null) {
        final rootSub = (root['max_submissions'] is int)
            ? root['max_submissions'] as int
            : int.tryParse('${root['max_submissions']}') ?? 0;
        final metaSub = result['max_submissions'] != null
            ? ((result['max_submissions'] is int)
                ? result['max_submissions'] as int
                : int.tryParse('${result['max_submissions']}') ?? 0)
            : 0;
        result['max_submissions'] = rootSub > 0 ? rootSub : (metaSub > 0 ? metaSub : rootSub);
      }

      // start_date & end_date
      if (root.containsKey('start_date') && root['start_date'] != null && root['start_date'].toString().isNotEmpty) {
        result['start_date'] = root['start_date'];
      }
      if (root.containsKey('end_date') && root['end_date'] != null && root['end_date'].toString().isNotEmpty) {
        result['end_date'] = root['end_date'];
      }

      // theme
      if (root.containsKey('theme') && root['theme'] != null) {
        result['theme'] = root['theme'];
      }
    }

    return result;
  }

  /// Bersihkan tag meta div dari HTML agar tidak tampil atau mengotori editor/display.
  static String stripMetaHtml(String? html) {
    if (html == null || html.isEmpty) return '';
    return html
        .replaceAll(
          RegExp(r'<div class="form-settings-meta"[^>]*>.*?</div>', dotAll: true),
          '',
        )
        .trim();
  }

  /// Sisipkan tag meta div ke dalam descriptionHtml.
  static String embedMetaHtml(String? html, Map<String, dynamic> settings) {
    final clean = stripMetaHtml(html);
    try {
      final jsonStr = jsonEncode(settings);
      final b64 = base64Encode(utf8.encode(jsonStr));
      final div =
          '<div class="form-settings-meta" data-value="$b64" style="display:none"></div>';
      return clean.isEmpty ? div : '$clean$div';
    } catch (e) {
      debugPrint('[FormSettingsMeta] Gagal embed meta: $e');
      return clean;
    }
  }
}
