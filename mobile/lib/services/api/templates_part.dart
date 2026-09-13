// Endpoint TEMPLATE ApiService — create, update, get, mine, delete.
// Dipindah verbatim dari `services/api_service.dart` (Tahap 8b) tanpa
// perubahan logika. File ini adalah `part` dari library yang sama.
// ApiService.* tetap menjadi fasad publik (forwarder satu baris) sehingga
// call-site di seluruh app TIDAK berubah.
// Catatan: static member ApiService WAJIB di-qualify (ApiService.xxx) dari
// fungsi top-level (aturan Dart, pelajaran Tahap 3a/8a). debugPrint/http/
// jsonEncode adalah top-level & tidak perlu qualify.
// _logHtmlDiagnostic SENGAJA tetap di file utama: dipakai template DAN form.
part of '../api_service.dart';

Future<Map<String, dynamic>> _tplCreate(
  Map<String, dynamic> payload,
) async {
  ApiService._logHtmlDiagnostic('createTemplate (SEND)', payload['questions']);
  try {
    final token = await ApiService.getToken();
    if (token == null) {
      debugPrint(
        '[ApiService] createTemplate gagal: No token (belum login?)',
      );
      return {
        'success': false,
        'message': 'No token found — silakan login ulang',
      };
    }

    final response = await http
        .post(
          Uri.parse('${ApiService.baseUrl}/templates'),
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
    } else {
      // Tampilkan detail validasi Pydantic (422) yang sering jadi penyebab draft tidak tersimpan
      String detail = 'Failed to create template';
      if (data is Map) {
        if (data['detail'] is String) {
          detail = data['detail'];
        } else if (data['detail'] is List) {
          // FastAPI 422 returns list of errors
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
    }
  } catch (e, stack) {
    debugPrint('[ApiService] createTemplate exception: $e\n$stack');
    String msg = e.toString();
    if (msg.contains('TimeoutException'))
      msg =
          'Timeout koneksi ke ${ApiService.baseUrl} — cek backend jalan & adb reverse / API_URL';
    return {'success': false, 'message': msg};
  }
}

// Fungsi Update Template (PATCH) — untuk draft save berikutnya, cegah duplikat POST
Future<Map<String, dynamic>> _tplUpdate(
  String id,
  Map<String, dynamic> payload,
) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};
    final response = await http
        .patch(
          Uri.parse('${ApiService.baseUrl}/templates/$id'),
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
        : 'Failed to update template';
    if (data is Map && data['detail'] is List) {
      try {
        detail = (data['detail'] as List)
            .map((e) => '${e['loc']?.last ?? 'field'}: ${e['msg']}')
            .join(', ');
      } catch (_) {}
    }
    return {'success': false, 'message': detail};
  } catch (e, stack) {
    debugPrint('[ApiService] updateTemplate exception: $e\n$stack');
    return {'success': false, 'message': e.toString()};
  }
}

// FIX: ambil detail template lengkap dengan questions (untuk search -> edit)
Future<Map<String, dynamic>> _tplGet(String id) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};
    final response = await http
        .get(
          Uri.parse('${ApiService.baseUrl}/templates/$id'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final parsed = ApiService._safeJson(response.body);
      if (parsed is Map)
        ApiService._logHtmlDiagnostic('getTemplate (RECV)', parsed['questions']);
      return {'success': true, 'data': parsed};
    }
    final body = ApiService._safeJson(response.body);
    final msg = body is Map
        ? (body['detail'] ?? 'Failed: ${response.statusCode}')
        : 'Failed: ${response.statusCode}';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}

// Fungsi Get My Templates — DIPERBAIKI: timeout + logging
Future<Map<String, dynamic>> _tplGetMine() async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};

    final response = await http
        .get(
          Uri.parse('${ApiService.baseUrl}/templates/mine'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final parsed = ApiService._safeJson(response.body);
      final questions = <dynamic>[];
      if (parsed is List) {
        for (final t in parsed) {
          if (t is Map && t['questions'] is List) {
            questions.addAll(t['questions'] as List);
          }
        }
      } else if (parsed is Map) {
        final items =
            parsed['items'] ?? parsed['questions'] ?? parsed['data'];
        if (items is List) {
          for (final t in items) {
            if (t is Map && t['questions'] is List) {
              questions.addAll(t['questions'] as List);
            }
          }
        }
      }
      ApiService._logHtmlDiagnostic('getMyTemplates (RECV)', questions);
      return {'success': true, 'data': parsed};
    }
    final body = ApiService._safeJson(response.body);
    final msg = body is Map
        ? (body['detail'] ?? 'Failed: ${response.statusCode}')
        : 'Failed: ${response.statusCode}';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    debugPrint('[ApiService] getMyTemplates exception: $e');
    return {'success': false, 'message': e.toString()};
  }
}

Future<Map<String, dynamic>> _tplDelete(String templateId) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};
    final response = await http
        .delete(
          Uri.parse('${ApiService.baseUrl}/templates/$templateId'),
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
