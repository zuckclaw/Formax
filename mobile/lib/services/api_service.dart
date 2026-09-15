import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

// Part: endpoint AUTH — Tahap 8a. ApiService tetap fasad publik via
// forwarder satu baris; puluhan call-site tidak berubah.
part 'api/auth_part.dart';

// Part: endpoint TEMPLATE — Tahap 8b. Pola sama: fasad + forwarder.
part 'api/templates_part.dart';

// Part: endpoint FORM — Tahap 8c. Pola sama: fasad + forwarder.
part 'api/forms_part.dart';

// Part: endpoint MISC (submissions/search/profil/export/upload) — Tahap 8d.
// Pola sama: fasad + forwarder.
part 'api/misc_part.dart';

String _apiErrorDetail(Object? data, String fallback) {
  if (data is! Map) return fallback;
  final detail = data['detail'];
  if (detail is String) return detail;
  if (detail is List) {
    return detail.map((item) {
      if (item is! Map) return item.toString();
      final error = Map<String, dynamic>.from(item);
      final location = error['loc'];
      final parts = location is List ? location : const <dynamic>[];
      final field = parts.isEmpty ? 'field' : parts.last.toString();
      return '$field: ${error['msg'] ?? ''}';
    }).join(', ');
  }
  return data['message']?.toString() ?? fallback;
}

class ApiService {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Mobile harus konsumsi backend yang sama dengan web project,
    // sehingga semua client terhubung ke backend production yang sama.
    return 'https://wriggly-diffusion-flatfoot.ngrok-free.dev';
  }

  static String get frontendUrl {
    const f = String.fromEnvironment('FRONTEND_URL');
    if (f.isNotEmpty) return f;
    return 'https://formax-seven.vercel.app';
  }

  static String publicFormLink(String slug) {
    try {
      final s = slug.startsWith('http')
          ? Uri.parse(slug).pathSegments.last
          : slug;
      final clean = s.trim().isEmpty ? slug.trim() : s.trim();
      return '${frontendUrl.replaceAll(RegExp(r'/+$'), '')}/f/$clean';
    } catch (_) {
      return '${frontendUrl.replaceAll(RegExp(r'/+$'), '')}/f/$slug';
    }
  }

  static String? _sessionToken;

  // Secure storage hanya untuk Android/iOS (Keystore/Keychain).
  // Web/Desktop fallback ke SharedPreferences agar tidak crash (plugin tidak didukung).
  static const _secure = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _kAccessToken = 'access_token';

  static bool get _useSecure =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // Safe JSON decode — tidak throw jika body kosong / HTML error page
  static dynamic _safeJson(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } catch (_) {
      // Fallback: body bukan JSON (mis. 502 HTML) → bungkus sebagai detail
      return {
        'detail': body.length > 500 ? '${body.substring(0, 500)}...' : body,
      };
    }
  }

  static String _friendlyError(http.Response response, String fallback) {
    final body = response.body.trim();
    final lowerBody = body.toLowerCase();
    if (lowerBody.contains('<html') ||
        lowerBody.contains('<!doctype') ||
        lowerBody.contains('assets.ngrok.com')) {
      return 'Tidak dapat terhubung ke server. Pastikan backend dan tunnel ngrok sedang berjalan.';
    }
    final data = _safeJson(body);
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return fallback;
  }

  static String _friendlyException(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('connection refused') ||
        message.contains('timeout')) {
      return 'Tidak dapat terhubung ke server. Pastikan backend dan tunnel ngrok sedang berjalan.';
    }
    return 'Terjadi kesalahan saat menghubungi server.';
  }

  /// True jika respons 401 karena token kedaluwarsa/tidak valid (bukan salah password).
  /// Dipakai untuk auto-logout agar user tidak stuck dengan sesi mati.
  static bool _isSessionExpired(int statusCode, dynamic body) {
    if (statusCode != 401) return false;
    final detail = (body is Map ? body['detail'] : null)?.toString().toLowerCase() ?? '';
    return detail.contains('kadaluarsa') || detail.contains('tidak valid');
  }

  static Future<Map<String, dynamic>> _unauthorizedResult(dynamic body) async {
    try {
      await removeToken();
    } catch (_) {}
    final msg = (body is Map && body['detail'] != null)
        ? body['detail'].toString()
        : 'Sesi kedaluwarsa, silakan login ulang';
    return {'success': false, 'message': msg.toString(), 'expired': true};
  }

  // Menyimpan token. Jika rememberMe false, token hanya disimpan di memori.
  // rememberMe true (Android/iOS): Keystore/Keychain. Web/Desktop: SharedPreferences.
  // Token lama di SharedPreferences otomatis dimigrasi ke secure saat dibaca.
  static Future<void> saveToken(String token, {bool rememberMe = true}) async {
    _sessionToken = token;
    if (rememberMe) {
      if (_useSecure) {
        try {
          await _secure.write(key: _kAccessToken, value: token);
          // Bersihkan sisa plaintext lama agar tidak ada dua sumber.
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_kAccessToken);
          } catch (_) {}
          return;
        } catch (_) {
          // Fallback ke prefs bila secure gagal (mis. device tanpa lock screen).
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccessToken, token);
    } else {
      // Pastikan token lama di storage dihapus jika user memilih tidak di-remember
      try {
        if (_useSecure) await _secure.delete(key: _kAccessToken);
      } catch (_) {}
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kAccessToken);
      } catch (_) {}
    }
  }

  // Mengambil token (prioritaskan dari memori)
  static Future<String?> getToken() async {
    if (_sessionToken != null) return _sessionToken;
    if (_useSecure) {
      try {
        final s = await _secure.read(key: _kAccessToken);
        if (s != null && s.isNotEmpty) {
          _sessionToken = s;
          return s;
        }
      } catch (_) {}
      // Migrasi sekali: token lama masih di prefs plaintext -> pindah ke secure.
      try {
        final prefs = await SharedPreferences.getInstance();
        final legacy = prefs.getString(_kAccessToken);
        if (legacy != null && legacy.isNotEmpty) {
          try {
            await _secure.write(key: _kAccessToken, value: legacy);
            await prefs.remove(_kAccessToken);
          } catch (_) {}
          _sessionToken = legacy;
          return legacy;
        }
      } catch (_) {}
      return null;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString(_kAccessToken);
      if (t != null && t.isNotEmpty) _sessionToken = t;
      return _sessionToken;
    } catch (_) {
      return _sessionToken;
    }
  }

  // Menghapus token (Logout)
  static Future<void> removeToken() async {
    _sessionToken = null;
    try {
      if (_useSecure) await _secure.delete(key: _kAccessToken);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccessToken);
    } catch (_) {}
  }

  static Future<String> getRespondentKey() async {
    final prefs = await SharedPreferences.getInstance();
    String? key = prefs.getString('anonymous_respondent_key');
    if (key == null || key.isEmpty) {
      key = _generateUuid();
      await prefs.setString('anonymous_respondent_key', key);
    }
    return key;
  }

  static String _generateUuid() {
    // UUID v4 dengan CSPRNG (Random.secure), bukan timestamp predictible.
    try {
      final r = math.Random.secure();
      const hexChars = '0123456789abcdef';
      final sb = StringBuffer();
      for (var i = 0; i < 32; i++) {
        sb.write(hexChars[r.nextInt(16)]);
      }
      final hex = sb.toString();
      return 'anon-${hex.substring(0, 8)}-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
    } catch (_) {
      return 'anon-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    }
  }

  // Slug dari judul form — pola sama dengan web (generateSlug) agar konsisten.
  static String generateSlug(String title) {
    final base = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final trimmed = base.length > 60 ? base.substring(0, 60) : base;
    return '$trimmed-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
  }

  // Fungsi Login
  // Fasad AUTH (Tahap 8a): implementasi di api/auth_part.dart.
  static Future<Map<String, dynamic>> login(
    String email,
    String password, {
    bool rememberMe = true,
  }) =>
      _authLogin(email, password, rememberMe: rememberMe);

  // Fungsi Request OTP
  static Future<Map<String, dynamic>> sendOtp(String email) =>
      _authSendOtp(email);

  static Future<Map<String, dynamic>> requestPasswordReset(String email) =>
      _authRequestPasswordReset(email);

  static Future<Map<String, dynamic>> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) =>
      _authResetPassword(email, otp, newPassword);

  static Future<Map<String, dynamic>> verifyPasswordResetOtp(
    String email,
    String otp,
  ) =>
      _authVerifyPasswordResetOtp(email, otp);

  // Fungsi Register (Signup)
  static Future<Map<String, dynamic>> register(
    String fullName,
    String email,
    String password,
    String otp,
  ) =>
      _authRegister(fullName, email, password, otp);

  // Fungsi Get User Profile
  static Future<Map<String, dynamic>> getMe() => _authGetMe();

  static void _logHtmlDiagnostic(String label, dynamic questions) {
    try {
      if (questions is! List || questions.isEmpty) {
        debugPrint(
          '[ApiService] $label: no questions (${questions.runtimeType})',
        );
        return;
      }
      int withHtml = 0;
      int total = 0;
      for (final q in questions) {
        if (q is! Map) continue;
        for (final key in ['label', 'placeholder', 'description']) {
          final v = q[key];
          if (v is String && v.trim().isNotEmpty) {
            total++;
            if (RegExp(r'<[a-zA-Z/]').hasMatch(v)) withHtml++;
          }
        }
      }
      debugPrint(
        '[ApiService] $label: $withHtml/$total text fields still contain HTML',
      );
    } catch (e) {
      debugPrint('[ApiService] $label diag error: $e');
    }
  }

  // Fungsi Create Template — DIPERBAIKI: timeout, logging, validasi 422
  // Fasad TEMPLATE (Tahap 8b): implementasi di api/templates_part.dart.
  static Future<Map<String, dynamic>> createTemplate(
    Map<String, dynamic> payload,
  ) =>
      _tplCreate(payload);

  // Fungsi Update Template (PATCH) — untuk draft save berikutnya, cegah duplikat POST
  static Future<Map<String, dynamic>> updateTemplate(
    String id,
    Map<String, dynamic> payload,
  ) =>
      _tplUpdate(id, payload);

  // FIX: ambil detail template lengkap dengan questions (untuk search -> edit)
  static Future<Map<String, dynamic>> getTemplate(String id) => _tplGet(id);

  // Fungsi Get My Templates — DIPERBAIKI: timeout + logging
  static Future<Map<String, dynamic>> getMyTemplates() => _tplGetMine();

  // Fungsi Create Form
  // Fasad FORM (Tahap 8c): implementasi di api/forms_part.dart.
  static Future<Map<String, dynamic>> createForm(
    Map<String, dynamic> payload,
  ) =>
      _formCreate(payload);

  // FIX Bug 18: PATCH status form menjadi published setelah create
  static Future<Map<String, dynamic>> updateForm(
    String formId,
    Map<String, dynamic> payload,
  ) =>
      _formUpdate(formId, payload);

  // Ambil detail form lengkap (termasuk questions) milik owner — dipakai untuk
  // melanjutkan draft form di FormMaker.
  static Future<Map<String, dynamic>> getForm(String formId) =>
      _formGet(formId);

  // Hanya form dengan status 'draft' — sumber data section "Draft Saya" di Dashboard.
  static Future<Map<String, dynamic>> getDraftForms() => _formGetDrafts();

  // Hapus form beserta semua responsnya (permanen, tidak bisa dibatalkan).
  static Future<Map<String, dynamic>> deleteForm(String formId) =>
      _formDelete(formId);

  // Hapus template milik pengguna (permanen).
  // Hapus template (domain TEMPLATE walau posisinya di antara form).
  static Future<Map<String, dynamic>> deleteTemplate(String templateId) =>
      _tplDelete(templateId);

  // Publish form: mengubah status form menjadi 'published'
  static Future<Map<String, dynamic>> publishForm(String formId) =>
      _formPublish(formId);

  static Future<Map<String, dynamic>> regenerateJoinToken(String formId) =>
      _formRegenToken(formId);

  // Fungsi Generate QR Code
  static Future<Map<String, dynamic>> generateQrCode(String formId) =>
      _formQr(formId);

  // Fungsi Get My Forms (untuk Dashboard & History)
  static Future<Map<String, dynamic>> getMyForms() => _formGetMine();

  // Fungsi Validate Form Link (untuk Join with Link)
  static Future<Map<String, dynamic>> validateFormLink(String link) =>
      _formValidateLink(link);

  // Fasad MISC (Tahap 8d): implementasi di api/misc_part.dart.
  // (Untuk Result Page.)
  static Future<Map<String, dynamic>> getFormSubmissions(String formId) =>
      _miscFormSubs(formId);

  // AKTIVITAS SAYA — daftar form yang pernah/sedang diisi user sebagai responden.
  // Endpoint backend: GET /submissions/me → List[MySubmissionOut]
  static Future<Map<String, dynamic>> getMySubmissions() => _miscMySubs();

  // Hasil submission milik responden (untuk "Lihat Hasil" di Aktivitas Saya).
  // Endpoint backend: GET /submissions/{submission_id}/result → SubmissionResultOut
  static Future<Map<String, dynamic>> getSubmissionResult(
    String submissionId,
  ) =>
      _miscSubResult(submissionId);

  // Fungsi Search (untuk Dashboard Search)
  static Future<Map<String, dynamic>> search(String query) =>
      _miscSearch(query);

  // Fungsi Update Profile
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> payload,
  ) =>
      _miscUpdateProfile(payload);

  // Export respons form ke Excel (.xlsx). Backend mengembalikan file biner,
  // jadi kembalikan bytes + nama file (dari Content-Disposition backend).
  static Future<Map<String, dynamic>> exportFormSubmissions(
    String formId,
  ) =>
      _miscExport(formId);

  // _extractFilename & _uploadOnce ikut pindah ke api/misc_part.dart
  // (pemakainya hanya di sana).

  static Future<Map<String, dynamic>> uploadFile(XFile file) =>
      _miscUpload(file);
}
