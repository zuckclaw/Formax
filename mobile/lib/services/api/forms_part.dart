// Endpoint FORM ApiService — CRUD, publish, token, QR, mine, validasi link.
// Dipindah verbatim dari `services/api_service.dart` (Tahap 8c) tanpa
// perubahan logika. File ini adalah `part` dari library yang sama.
// ApiService.* tetap menjadi fasad publik (forwarder satu baris) sehingga
// call-site di seluruh app TIDAK berubah.
// Catatan: static member ApiService WAJIB di-qualify (ApiService.xxx) dari
// fungsi top-level (aturan Dart, pelajaran Tahap 3a/8a). debugPrint/http/
// jsonEncode adalah top-level & tidak perlu qualify.
// _logHtmlDiagnostic SENGAJA tetap di file utama: dipakai form DAN template.
part of '../api_service.dart';

Future<Map<String, dynamic>> _formCreate(
  Map<String, dynamic> payload,
) async {
  ApiService._logHtmlDiagnostic('createForm (SEND)', payload['questions']);
  try {
    final token = await ApiService.getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }

    final response = await http
        .post(
          Uri.parse('${ApiService.baseUrl}/forms'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {'success': true, 'data': data};
    }
    String detail = 'Failed to create form';
    if (data is Map) {
      if (data['detail'] is String) {
        detail = data['detail'];
      } else if (data['detail'] is List) {
        try {
          detail = (data['detail'] as List)
              .map((e) => '${e['loc']?.last ?? 'field'}: ${e['msg']}')
              .join(', ');
        } catch (_) {
          detail = data['detail'].toString();
        }
      } else if (data['message'] != null) {
        detail = data['message'].toString();
      }
    }
    if (response.statusCode == 401)
      detail = 'Sesi habis / token tidak valid — login ulang. ($detail)';
    if (response.statusCode == 422)
      detail = 'Format data tidak valid (422): $detail';
    return {'success': false, 'message': detail};
  } catch (e, stack) {
    debugPrint('[ApiService] createForm exception: $e\n$stack');
    String msg = e.toString();
    if (msg.contains('TimeoutException'))
      msg =
          'Timeout koneksi ke ${ApiService.baseUrl} — cek backend jalan & adb reverse / API_URL';
    return {'success': false, 'message': msg};
  }
}

// FIX Bug 18: PATCH status form menjadi published setelah create
Future<Map<String, dynamic>> _formUpdate(
  String formId,
  Map<String, dynamic> payload,
) async {
  ApiService._logHtmlDiagnostic('updateForm (SEND)', payload['questions']);
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};
    final response = await http
        .patch(
          Uri.parse('${ApiService.baseUrl}/forms/$formId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200) return {'success': true, 'data': data};
    String detail = data is Map && data['detail'] is String
        ? data['detail']
        : 'Failed to update form';
    if (data is Map && data['detail'] is List) {
      try {
        detail = (data['detail'] as List)
            .map((e) => '${e['loc']?.last ?? 'field'}: ${e['msg']}')
            .join(', ');
      } catch (_) {}
    }
    if (response.statusCode == 401)
      detail = 'Sesi habis / token tidak valid — login ulang. ($detail)';
    if (response.statusCode == 422)
      detail = 'Format data tidak valid (422): $detail';
    return {'success': false, 'message': detail};
  } catch (e, stack) {
    debugPrint('[ApiService] updateForm exception: $e\n$stack');
    String msg = e.toString();
    if (msg.contains('TimeoutException'))
      msg =
          'Timeout koneksi ke ${ApiService.baseUrl} — cek backend jalan & adb reverse / API_URL';
    return {'success': false, 'message': msg};
  }
}

// Ambil detail form lengkap (termasuk questions) milik owner — dipakai untuk
// melanjutkan draft form di FormMaker.
Future<Map<String, dynamic>> _formGet(String formId) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};
    final response = await http
        .get(
          Uri.parse('${ApiService.baseUrl}/forms/$formId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 10));
    final parsed = ApiService._safeJson(response.body);
    if (response.statusCode == 200) {
      if (parsed is Map)
        ApiService._logHtmlDiagnostic('getForm (RECV)', parsed['questions']);
      return {'success': true, 'data': parsed};
    }
    final msg = parsed is Map
        ? (parsed['detail'] ?? 'Failed: ${response.statusCode}')
        : 'Failed: ${response.statusCode}';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}

// Hanya form dengan status 'draft' — sumber data section "Draft Saya" di Dashboard.
Future<Map<String, dynamic>> _formGetDrafts() async {
  // Via fasad agar satu-satunya definisi logika getMyForms dipakai ulang.
  final res = await ApiService.getMyForms();
  if (res['success'] != true) return res;
  final rawList = res['data'];
  if (rawList is! List) return {'success': true, 'data': []};
  final drafts = rawList
      .where((e) => e is Map && e['status'] == 'draft')
      .toList();
  return {'success': true, 'data': drafts};
}

// Hapus form beserta semua responsnya (permanen, tidak bisa dibatalkan).
Future<Map<String, dynamic>> _formDelete(String formId) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};
    final response = await http
        .delete(
          Uri.parse('${ApiService.baseUrl}/forms/$formId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 10));
    final data = ApiService._safeJson(response.body);
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
Future<Map<String, dynamic>> _formPublish(String formId) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};
    final response = await http
        .post(
          Uri.parse('${ApiService.baseUrl}/forms/$formId/publish'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 10));
    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200) return {'success': true, 'data': data};
    final msg = data is Map
        ? (data['detail'] ?? 'Failed to publish form')
        : 'Failed to publish form';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}

Future<Map<String, dynamic>> _formRegenToken(String formId) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};
    final response = await http
        .post(
          Uri.parse('${ApiService.baseUrl}/forms/$formId/regenerate-join-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 10));
    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200) return {'success': true, 'data': data};
    final msg = data is Map
        ? (data['detail'] ?? 'Failed to regenerate join token')
        : 'Failed to regenerate join token';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}

// Fungsi Generate QR Code
Future<Map<String, dynamic>> _formQr(String formId) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }

    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/forms/$formId/generate-qr'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {'success': true, 'data': data};
    } else {
      final msg = data is Map
          ? (data['detail'] ?? 'Failed to generate QR code')
          : 'Failed to generate QR code';
      return {'success': false, 'message': msg.toString()};
    }
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}

// Fungsi Get My Forms (untuk Dashboard & History)
Future<Map<String, dynamic>> _formGetMine() async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};

    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/forms'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return {'success': true, 'data': ApiService._safeJson(response.body)};
    }
    final body = ApiService._safeJson(response.body);
    final msg = body is Map ? (body['detail'] ?? 'Failed') : 'Failed';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}

// Fungsi Validate Form Link (untuk Join with Link)
Future<Map<String, dynamic>> _formValidateLink(String link) async {
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

    final token = await ApiService.getToken();

    // Gunakan endpoint get_form_by_slug yang sudah ada di backend
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/forms/public/$slug'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200) {
      return {
        'success': true,
        'data': {'slug': slug, if (data is Map) ...data},
      };
    } else {
      final msg = data is Map
          ? (data['detail'] ?? 'Form tidak ditemukan')
          : 'Form tidak ditemukan';
      return {'success': false, 'message': msg.toString()};
    }
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}
