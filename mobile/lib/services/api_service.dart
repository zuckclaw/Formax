import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // Base URL dikonfigurasi via --dart-define=API_URL=...
  // Default = URL backend RESMI (ngrok) yang sama dengan web Vercel,
  //   https://wriggly-diffusion-flatfoot.ngrok-free.dev
  // Untuk development lokal, override dengan:
  //   Android Emulator: flutter run --dart-define=API_URL=http://10.0.2.2:8000
  //   HP fisik via USB : adb reverse tcp:8000 tcp:8000 lalu --dart-define=API_URL=http://127.0.0.1:8000
  static const String _defaultApiUrl = 'https://wriggly-diffusion-flatfoot.ngrok-free.dev';

  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return _defaultApiUrl;
  }

  // Frontend URL tempat publik mengisi form (link & QR yang dibagikan).
  // Default: frontend yang sudah dideploy (Vercel). Bisa di-override saat build
  // dengan --dart-define=FRONTEND_URL=https://... (mis. preview branch).
  static String get frontendUrl {
    const f = String.fromEnvironment('FRONTEND_URL');
    if (f.isNotEmpty) return f;
    return 'https://formax-seven.vercel.app';
  }

  // Normalisasi link publik supaya menunjuk ke FRONTEND_URL (bukan localhost).
  // Server mungkin mengembalikan localhost/127.0.0.1 bila FRONTEND_URL env di
  // backend belum diupdate — di sini kita paksa selalu pakai frontendUrl.
  static String publicFormLink(String slug) {
    final s = slug.startsWith('http')
        ? Uri.parse(slug).pathSegments.last
        : slug;
    return '${frontendUrl.replaceAll(RegExp(r'/+$'), '')}/f/$s';
  }

  static String? _sessionToken;

  // Safe JSON decode — tidak throw jika body kosong / HTML error page
  static dynamic _safeJson(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } catch (_) {
      // Fallback: body bukan JSON (mis. 502 HTML) → bungkus sebagai detail
      return {'detail': body.length > 500 ? '${body.substring(0, 500)}...' : body};
    }
  }

  // Menyimpan token. Jika rememberMe false, token hanya disimpan di memori.
  static Future<void> saveToken(String token, {bool rememberMe = true}) async {
    _sessionToken = token;
    if (rememberMe) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
    } else {
      // Pastikan token lama di storage dihapus jika user memilih tidak di-remember
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
    }
  }

  // Mengambil token (prioritaskan dari memori)
  static Future<String?> getToken() async {
    if (_sessionToken != null) return _sessionToken;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Menghapus token (Logout)
  static Future<void> removeToken() async {
    _sessionToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  // Identitas responden anonim (Google-Forms style).
  // Simpan satu UUID di shared_preferences per perangkat, dipakai sebagai X-Respondent-Key
  // supaya orang yang membuka link tanpa login tetap bisa mengisi & melacak submission-nya.
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
    // UUID v4 sederhana tanpa dependency eksternal
    final rnd = DateTime.now().microsecondsSinceEpoch;
    final rand = (rnd * 2654435761) % 0x7FFFFFFF;
    final hex = rand.toRadixString(16).padLeft(8, '0');
    return 'anon-$hex-${DateTime.now().millisecondsSinceEpoch}';
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
  static Future<Map<String, dynamic>> login(String email, String password, {bool rememberMe = true}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = _safeJson(response.body);
      if (response.statusCode == 200) {
        if (data is Map && data.containsKey('access_token')) {
          await saveToken(data['access_token'], rememberMe: rememberMe);
        }
        return {'success': true, 'data': data};
      } else {
        final msg = data is Map ? (data['detail'] ?? 'Login failed') : 'Login failed';
        return {'success': false, 'message': msg.toString()};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Request OTP
  static Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      );

      final data = _safeJson(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        final msg = data is Map ? (data['detail'] ?? 'Failed to send OTP') : 'Failed to send OTP';
        return {'success': false, 'message': msg.toString()};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Register (Signup)
  static Future<Map<String, dynamic>> register(String fullName, String email, String password, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': fullName,
          'email': email,
          'password': password,
          'otp': otp,
        }),
      );

      final data = _safeJson(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data is Map && data.containsKey('access_token')) {
           await saveToken(data['access_token']);
        }
        return {'success': true, 'data': data};
      } else {
        final msg = data is Map ? (data['detail'] ?? 'Registration failed') : 'Registration failed';
        return {'success': false, 'message': msg.toString()};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Get User Profile
  static Future<Map<String, dynamic>> getMe() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = _safeJson(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        final msg = data is Map ? (data['detail'] ?? 'Failed to get profile') : 'Failed to get profile';
        return {'success': false, 'message': msg.toString()};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Diagnosa HTML: berapa persen label/placeholder dari questions yang masih
  // mengandung tag HTML saat dikirim ke backend. Jika 0, mobile sudah drop —
  // jika >0 tapi GET kembalikan plain, berarti backend yang strip.
  static void _logHtmlDiagnostic(String label, dynamic questions) {
    try {
      if (questions is! List || questions.isEmpty) {
        debugPrint('[ApiService] $label: no questions (${questions.runtimeType})');
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
      debugPrint('[ApiService] $label: $withHtml/$total text fields still contain HTML');
    } catch (e) {
      debugPrint('[ApiService] $label diag error: $e');
    }
  }

  // Fungsi Create Template — DIPERBAIKI: timeout, logging, validasi 422
  static Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> payload) async {
    _logHtmlDiagnostic('createTemplate (SEND)', payload['questions']);
    try {
      final token = await getToken();
      if (token == null) {
        debugPrint('[ApiService] createTemplate gagal: No token (belum login?)');
        return {'success': false, 'message': 'No token found — silakan login ulang'};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/templates'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final data = _safeJson(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        // Tampilkan detail validasi Pydantic (422) yang sering jadi penyebab draft tidak tersimpan
        String detail = 'Failed to create template';
        if (data is Map) {
          if (data['detail'] is String) {
            detail = data['detail'];
          } else if (data['detail'] is List) {
            // FastAPI 422 returns list of errors
            try {
              detail = (data['detail'] as List).map((e) => '${e['loc']?.last ?? 'field'}: ${e['msg']}').join(', ');
            } catch (_) {
              detail = data['detail'].toString();
            }
          } else if (data['message'] != null) {
            detail = data['message'].toString();
          }
        }
        if (response.statusCode == 401) detail = 'Sesi habis / token tidak valid — login ulang. ($detail)';
        if (response.statusCode == 422) detail = 'Format data tidak valid (422): $detail';
        return {'success': false, 'message': detail};
      }
    } catch (e, stack) {
      debugPrint('[ApiService] createTemplate exception: $e\n$stack');
      String msg = e.toString();
      if (msg.contains('TimeoutException')) msg = 'Timeout koneksi ke $baseUrl — cek backend jalan & adb reverse / API_URL';
      return {'success': false, 'message': msg};
    }
  }

  // Fungsi Update Template (PATCH) — untuk draft save berikutnya, cegah duplikat POST
  static Future<Map<String, dynamic>> updateTemplate(String id, Map<String, dynamic> payload) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final response = await http
          .patch(
            Uri.parse('$baseUrl/templates/$id'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      final data = _safeJson(response.body);
      if (response.statusCode == 200) return {'success': true, 'data': data};
      String detail = data is Map && data['detail'] is String ? data['detail'] : 'Failed to update template';
      if (data is Map && data['detail'] is List) {
        try { detail = (data['detail'] as List).map((e) => '${e['loc']?.last ?? 'field'}: ${e['msg']}').join(', '); } catch (_) {}
      }
      return {'success': false, 'message': detail};
    } catch (e, stack) {
      debugPrint('[ApiService] updateTemplate exception: $e\n$stack');
      return {'success': false, 'message': e.toString()};
    }
  }

  // FIX: ambil detail template lengkap dengan questions (untuk search -> edit)
  static Future<Map<String, dynamic>> getTemplate(String id) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final response = await http
          .get(Uri.parse('$baseUrl/templates/$id'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final parsed = _safeJson(response.body);
        if (parsed is Map) _logHtmlDiagnostic('getTemplate (RECV)', parsed['questions']);
        return {'success': true, 'data': parsed};
      }
      final body = _safeJson(response.body);
      final msg = body is Map ? (body['detail'] ?? 'Failed: ${response.statusCode}') : 'Failed: ${response.statusCode}';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Get My Templates — DIPERBAIKI: timeout + logging
  static Future<Map<String, dynamic>> getMyTemplates() async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final response = await http
          .get(
            Uri.parse('$baseUrl/templates/mine'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final parsed = _safeJson(response.body);
        // /templates/mine mengembalikan List<TemplateOut>; kumpulkan pertanyaan dari
        // masing-masing template agar diagnostik HTML membandingkan hal yang sama
        // dengan SEND (perbandingan apples-to-apples, bukan menghitung template).
        final questions = <dynamic>[];
        if (parsed is List) {
          for (final t in parsed) {
            if (t is Map && t['questions'] is List) {
              questions.addAll(t['questions'] as List);
            }
          }
        } else if (parsed is Map) {
          final items = parsed['items'] ?? parsed['questions'] ?? parsed['data'];
          if (items is List) {
            for (final t in items) {
              if (t is Map && t['questions'] is List) {
                questions.addAll(t['questions'] as List);
              }
            }
          }
        }
        _logHtmlDiagnostic('getMyTemplates (RECV)', questions);
        return {'success': true, 'data': parsed};
      }
      final body = _safeJson(response.body);
      final msg = body is Map ? (body['detail'] ?? 'Failed: ${response.statusCode}') : 'Failed: ${response.statusCode}';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      debugPrint('[ApiService] getMyTemplates exception: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Create Form
  static Future<Map<String, dynamic>> createForm(Map<String, dynamic> payload) async {
    _logHtmlDiagnostic('createForm (SEND)', payload['questions']);
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/forms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      final data = _safeJson(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }
      String detail = 'Failed to create form';
      if (data is Map) {
        if (data['detail'] is String) {
          detail = data['detail'];
        } else if (data['detail'] is List) {
          try {
            detail = (data['detail'] as List).map((e) => '${e['loc']?.last ?? 'field'}: ${e['msg']}').join(', ');
          } catch (_) {
            detail = data['detail'].toString();
          }
        } else if (data['message'] != null) {
          detail = data['message'].toString();
        }
      }
      if (response.statusCode == 401) detail = 'Sesi habis / token tidak valid — login ulang. ($detail)';
      if (response.statusCode == 422) detail = 'Format data tidak valid (422): $detail';
      return {'success': false, 'message': detail};
    } catch (e, stack) {
      debugPrint('[ApiService] createForm exception: $e\n$stack');
      String msg = e.toString();
      if (msg.contains('TimeoutException')) msg = 'Timeout koneksi ke $baseUrl — cek backend jalan & adb reverse / API_URL';
      return {'success': false, 'message': msg};
    }
  }

  // FIX Bug 18: PATCH status form menjadi published setelah create
  static Future<Map<String, dynamic>> updateForm(String formId, Map<String, dynamic> payload) async {
    _logHtmlDiagnostic('updateForm (SEND)', payload['questions']);
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final response = await http.patch(Uri.parse('$baseUrl/forms/$formId'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode(payload)).timeout(const Duration(seconds: 15));
      final data = _safeJson(response.body);
      if (response.statusCode == 200) return {'success': true, 'data': data};
      String detail = data is Map && data['detail'] is String ? data['detail'] : 'Failed to update form';
      if (data is Map && data['detail'] is List) {
        try { detail = (data['detail'] as List).map((e) => '${e['loc']?.last ?? 'field'}: ${e['msg']}').join(', '); } catch (_) {}
      }
      if (response.statusCode == 401) detail = 'Sesi habis / token tidak valid — login ulang. ($detail)';
      if (response.statusCode == 422) detail = 'Format data tidak valid (422): $detail';
      return {'success': false, 'message': detail};
    } catch (e, stack) {
      debugPrint('[ApiService] updateForm exception: $e\n$stack');
      String msg = e.toString();
      if (msg.contains('TimeoutException')) msg = 'Timeout koneksi ke $baseUrl — cek backend jalan & adb reverse / API_URL';
      return {'success': false, 'message': msg};
    }
  }

  // Ambil detail form lengkap (termasuk questions) milik owner — dipakai untuk
  // melanjutkan draft form di FormMaker.
  static Future<Map<String, dynamic>> getForm(String formId) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final response = await http
          .get(Uri.parse('$baseUrl/forms/$formId'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
      final parsed = _safeJson(response.body);
      if (response.statusCode == 200) {
        if (parsed is Map) _logHtmlDiagnostic('getForm (RECV)', parsed['questions']);
        return {'success': true, 'data': parsed};
      }
      final msg = parsed is Map ? (parsed['detail'] ?? 'Failed: ${response.statusCode}') : 'Failed: ${response.statusCode}';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Hanya form dengan status 'draft' — sumber data section "Draft Saya" di Dashboard.
  static Future<Map<String, dynamic>> getDraftForms() async {
    final res = await getMyForms();
    if (res['success'] != true) return res;
    final rawList = res['data'];
    if (rawList is! List) return {'success': true, 'data': []};
    final drafts = rawList.where((e) => e is Map && e['status'] == 'draft').toList();
    return {'success': true, 'data': drafts};
  }

  // Hapus form beserta semua responsnya (permanen, tidak bisa dibatalkan).
  static Future<Map<String, dynamic>> deleteForm(String formId) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final response = await http
          .delete(
            Uri.parse('$baseUrl/forms/$formId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));
      final data = _safeJson(response.body);
      if (response.statusCode == 200) return {'success': true, 'data': data};
      final msg = data is Map
          ? (data['detail'] ?? 'Failed: ${response.statusCode}')
          : 'Failed: ${response.statusCode}';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Hapus template milik pengguna (permanen).
  static Future<Map<String, dynamic>> deleteTemplate(String templateId) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final response = await http
          .delete(
            Uri.parse('$baseUrl/templates/$templateId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));
      final data = _safeJson(response.body);
      if (response.statusCode == 200) return {'success': true, 'data': data};
      final msg = data is Map
          ? (data['detail'] ?? 'Failed: ${response.statusCode}')
          : 'Failed: ${response.statusCode}';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Publish form: mengubah status form menjadi 'published'
  static Future<Map<String, dynamic>> publishForm(String formId) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final response = await http
          .post(
            Uri.parse('$baseUrl/forms/$formId/publish'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));
      final data = _safeJson(response.body);
      if (response.statusCode == 200) return {'success': true, 'data': data};
      final msg = data is Map ? (data['detail'] ?? 'Failed to publish form') : 'Failed to publish form';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Generate QR Code
  static Future<Map<String, dynamic>> generateQrCode(String formId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/forms/$formId/generate-qr'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = _safeJson(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        final msg = data is Map ? (data['detail'] ?? 'Failed to generate QR code') : 'Failed to generate QR code';
        return {'success': false, 'message': msg.toString()};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Get My Forms (untuk Dashboard & History)
  static Future<Map<String, dynamic>> getMyForms() async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final response = await http.get(
        Uri.parse('$baseUrl/forms'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': _safeJson(response.body)};
      }
      final body = _safeJson(response.body);
      final msg = body is Map ? (body['detail'] ?? 'Failed') : 'Failed';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Validate Form Link (untuk Join with Link)
  static Future<Map<String, dynamic>> validateFormLink(String link) async {
    try {
      String slug = link.trim();
      
      // Jika link berupa URL lengkap (misal http://localhost:5173/f/slug-123), ekstrak slug-nya
      if (slug.contains('http') || slug.contains('/f/')) {
        try {
          final uri = Uri.parse(slug);
          final pathSegments = uri.pathSegments;
          if (pathSegments.contains('f')) {
            final index = pathSegments.indexOf('f');
            if (index + 1 < pathSegments.length) {
              slug = pathSegments[index + 1];
            }
          } else if (pathSegments.isNotEmpty) {
            slug = pathSegments.last;
          }
        } catch (_) {}
      }

      final token = await getToken();

      // Gunakan endpoint get_form_by_slug yang sudah ada di backend
      final response = await http.get(
        Uri.parse('$baseUrl/forms/public/$slug'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token'
        },
      );

      final data = _safeJson(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': {'slug': slug, if (data is Map) ...data}};
      } else {
        final msg = data is Map ? (data['detail'] ?? 'Form tidak ditemukan') : 'Form tidak ditemukan';
        return {'success': false, 'message': msg.toString()};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Get Form Submissions (untuk Result Page)
  static Future<Map<String, dynamic>> getFormSubmissions(String formId) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final response = await http.get(
        Uri.parse('$baseUrl/forms/$formId/submissions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': _safeJson(response.body)};
      }
      final body = _safeJson(response.body);
      final msg = body is Map ? (body['detail'] ?? 'Failed') : 'Failed';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // AKTIVITAS SAYA — daftar form yang pernah/sedang diisi user sebagai responden.
  // Endpoint backend: GET /submissions/me → List[MySubmissionOut]
  static Future<Map<String, dynamic>> getMySubmissions() async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final response = await http.get(
        Uri.parse('$baseUrl/submissions/me'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': _safeJson(response.body)};
      }
      final body = _safeJson(response.body);
      final msg = body is Map ? (body['detail'] ?? 'Failed') : 'Failed';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Hasil submission milik responden (untuk "Lihat Hasil" di Aktivitas Saya).
  // Endpoint backend: GET /submissions/{submission_id}/result → SubmissionResultOut
  static Future<Map<String, dynamic>> getSubmissionResult(String submissionId) async {
    try {
      final token = await getToken();
      final respondentKey = await getRespondentKey();
      final response = await http.get(
        Uri.parse('$baseUrl/submissions/$submissionId/result'),
        headers: {
          'Content-Type': 'application/json',
          'X-Respondent-Key': respondentKey,
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      final data = _safeJson(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      final msg = data is Map ? (data['detail'] ?? 'Gagal memuat hasil') : 'Gagal memuat hasil';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Search (untuk Dashboard Search)
  static Future<Map<String, dynamic>> search(String query) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final uri = Uri.parse('$baseUrl/search').replace(
        queryParameters: query.isNotEmpty ? {'q': query} : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': _safeJson(response.body)};
      }
      final body = _safeJson(response.body);
      final msg = body is Map ? (body['detail'] ?? 'Failed') : 'Failed';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Update Profile
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final response = await http.put(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      final data = _safeJson(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      final msg = data is Map ? (data['detail'] ?? 'Failed to update profile') : 'Failed to update profile';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Export respons form ke Excel (.xlsx). Backend mengembalikan file biner,
  // jadi kembalikan bytes + nama file (dari Content-Disposition backend).
  static Future<Map<String, dynamic>> exportFormSubmissions(String formId) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final response = await http
          .get(
            Uri.parse('$baseUrl/forms/$formId/export'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final cd = response.headers['content-disposition'];
        final filename = _extractFilename(cd) ?? '$formId-hasil.xlsx';
        return {
          'success': true,
          'bytes': response.bodyBytes,
          'filename': filename,
        };
      }
      final body = _safeJson(utf8.decode(response.bodyBytes, allowMalformed: true));
      final msg = body is Map
          ? (body['detail'] ?? 'Export gagal (${response.statusCode})')
          : 'Export gagal (${response.statusCode})';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static String? _extractFilename(String? contentDisposition) {
    if (contentDisposition == null) return null;
    final match =
        RegExp(r'filename="?([^";]+)"?').firstMatch(contentDisposition);
    return match?.group(1)?.trim();
  }

  // Fungsi Upload File (untuk avatar, file upload question, dll.)
  static Future<Map<String, dynamic>> uploadFile(dynamic file) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/uploads'));
      request.headers['Authorization'] = 'Bearer $token';
      if (kIsWeb) {
        // Web: XFile.path adalah blob URL, harus pakai bytes
        final bytes = await file.readAsBytes();
        String filename = 'upload';
        try {
          filename = file.name as String;
        } catch (_) {
          try {
            filename = file.path.toString().split('/').last;
          } catch (_) {}
        }
        request.files.add(http.MultipartFile.fromBytes('file', bytes as List<int>, filename: filename));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', file.path as String));
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final data = _safeJson(responseBody);

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        final url = data is Map ? data['file_url'] : null;
        return {'success': true, 'file_url': url};
      }
      final msg = data is Map ? (data['detail'] ?? 'Upload failed') : 'Upload failed';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
