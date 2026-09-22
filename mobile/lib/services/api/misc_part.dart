// Endpoint MISC ApiService — submissions, search, profil, export, upload.
// Dipindah verbatim dari `services/api_service.dart` (Tahap 8d) tanpa
// perubahan logika. File ini adalah `part` dari library yang sama.
// ApiService.* tetap menjadi fasad publik (forwarder satu baris) sehingga
// call-site di seluruh app TIDAK berubah.
// Catatan: static member ApiService WAJIB di-qualify (ApiService.xxx) dari
// fungsi top-level (aturan Dart, pelajaran Tahap 3a/8a). Helper privat
// _extractFilename & _uploadOnce ikut pindah (pemakainya hanya di sini)
// sehingga tetap top-level privat satu library tanpa rename.
part of '../api_service.dart';

Future<Map<String, dynamic>> _miscFormSubs(String formId) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};

    final response = await ApiService.client.get(
      Uri.parse('${ApiService.baseUrl}/forms/$formId/submissions'),
      headers: ApiService.defaultHeaders(token: token),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return {'success': true, 'data': ApiService._safeJson(response.body)};
    }
    final body = ApiService._safeJson(response.body);
    if (ApiService._isSessionExpired(response.statusCode, body)) {
      return ApiService._unauthorizedResult(body);
    }
    final msg = body is Map ? (body['detail'] ?? 'Failed') : 'Failed';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': ApiService._friendlyException(e)};
  }
}

// AKTIVITAS SAYA — daftar form yang pernah/sedang diisi user sebagai responden.
// Endpoint backend: GET /submissions/me → List[MySubmissionOut]
Future<Map<String, dynamic>> _miscMySubs() async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};

    final response = await ApiService.client.get(
      Uri.parse('${ApiService.baseUrl}/submissions/me'),
      headers: ApiService.defaultHeaders(token: token),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return {'success': true, 'data': ApiService._safeJson(response.body)};
    }
    final body = ApiService._safeJson(response.body);
    if (ApiService._isSessionExpired(response.statusCode, body)) {
      return ApiService._unauthorizedResult(body);
    }
    final msg = body is Map ? (body['detail'] ?? 'Failed') : 'Failed';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {
      'success': false,
      'message': ApiService._friendlyException(e),
      'connection': true,
    };
  }
}

// Hapus respons individu (owner form only) agar responden bisa mengerjakan ulang.
// Endpoint backend: DELETE /submissions/{submission_id} → 204
// Parity web deleteSubmission (DashboardPage → "Hapus Respons").
Future<Map<String, dynamic>> _miscDeleteSub(
  String submissionId,
) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};
    final response = await ApiService.client.delete(
      Uri.parse('${ApiService.baseUrl}/submissions/$submissionId'),
      headers: ApiService.defaultHeaders(token: token),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200 || response.statusCode == 204) {
      return {'success': true};
    }
    final body = ApiService._safeJson(response.body);
    if (ApiService._isSessionExpired(response.statusCode, body)) {
      return ApiService._unauthorizedResult(body);
    }
    final msg = body is Map
        ? (body['detail'] ?? 'Gagal menghapus respons')
        : 'Gagal menghapus respons';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {
      'success': false,
      'message': ApiService._friendlyException(e),
      'connection': true,
    };
  }
}

// ── Import soal dari DOCX (parity web api/docx.js) ─────────────────────
// GET /import/template-docx → bytes template
Future<Map<String, dynamic>> _miscDocxTemplate() async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};
    final response = await ApiService.client.get(
      Uri.parse('${ApiService.baseUrl}/import/template-docx'),
      headers: {
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return {'success': true, 'bytes': response.bodyBytes};
    }
    final body = ApiService._safeJson(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    if (ApiService._isSessionExpired(response.statusCode, body)) {
      return ApiService._unauthorizedResult(body);
    }
    final msg = body is Map
        ? (body['detail'] ?? 'Gagal mengunduh template')
        : 'Gagal mengunduh template';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {
      'success': false,
      'message': ApiService._friendlyException(e),
      'connection': true,
    };
  }
}

// POST /forms/{form_id}/questions/import-docx/preview (multipart .docx)
Future<Map<String, dynamic>> _miscDocxPreview(
  String formId,
  String filePath, {
  String? fileName,
}) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
          '${ApiService.baseUrl}/forms/$formId/questions/import-docx/preview'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['ngrok-skip-browser-warning'] = 'true';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName ?? filePath.split('/').last,
      ),
    );
    final streamed = await request.send().timeout(
          const Duration(seconds: 60),
        );
    final bodyStr = await streamed.stream.bytesToString();
    final data = ApiService._safeJson(bodyStr);
    if (streamed.statusCode == 200) {
      return {'success': true, 'data': data};
    }
    if (ApiService._isSessionExpired(streamed.statusCode, data)) {
      return ApiService._unauthorizedResult(data);
    }
    final msg = data is Map
        ? (data['detail'] ?? 'Gagal memproses file DOCX')
        : 'Gagal memproses file DOCX';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {
      'success': false,
      'message': ApiService._friendlyException(e),
      'connection': true,
    };
  }
}

// POST /forms/{form_id}/questions/import-docx/confirm {questions:[...]}
Future<Map<String, dynamic>> _miscDocxConfirm(
  String formId,
  List<Map<String, dynamic>> questions,
) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};
    final response = await ApiService.client.post(
      Uri.parse(
          '${ApiService.baseUrl}/forms/$formId/questions/import-docx/confirm'),
      headers: ApiService.defaultHeaders(token: token),
      body: jsonEncode({'questions': questions}),
    ).timeout(const Duration(seconds: 30));
    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {'success': true, 'data': data};
    }
    if (ApiService._isSessionExpired(response.statusCode, data)) {
      return ApiService._unauthorizedResult(data);
    }
    final msg = data is Map
        ? (data['detail'] ?? 'Gagal mengimpor soal')
        : 'Gagal mengimpor soal';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {
      'success': false,
      'message': ApiService._friendlyException(e),
      'connection': true,
    };
  }
}

// Hasil submission milik responden (untuk "Lihat Hasil" di Aktivitas Saya).
// Endpoint backend: GET /submissions/{submission_id}/result → SubmissionResultOut
Future<Map<String, dynamic>> _miscSubResult(
  String submissionId,
) async {
  try {
    final token = await ApiService.getToken();
    final respondentKey = await ApiService.getRespondentKey();
    final response = await ApiService.client.get(
      Uri.parse('${ApiService.baseUrl}/submissions/$submissionId/result'),
      headers: ApiService.defaultHeaders(
        token: token,
        respondentKey: respondentKey,
      ),
    ).timeout(const Duration(seconds: 15));
    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }
    if (ApiService._isSessionExpired(response.statusCode, data)) {
      return ApiService._unauthorizedResult(data);
    }
    final msg = data is Map
        ? (data['detail'] ?? 'Gagal memuat hasil')
        : 'Gagal memuat hasil';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': ApiService._friendlyException(e)};
  }
}

// Tandai submission sebagai curang (keluar aplikasi / keluar fullscreen).
// Endpoint backend: POST /submissions/{submission_id}/flag-cheated
// Hanya aktif kalau form.require_fullscreen true (parity web flagCheated).
Future<Map<String, dynamic>> _miscFlagCheated(
  String submissionId,
) async {
  try {
    final token = await ApiService.getToken();
    final respondentKey = await ApiService.getRespondentKey();
    final response = await ApiService.client.post(
      Uri.parse('${ApiService.baseUrl}/submissions/$submissionId/flag-cheated'),
      headers: ApiService.defaultHeaders(
        token: token,
        respondentKey: respondentKey,
      ),
    ).timeout(const Duration(seconds: 15));
    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }
    if (ApiService._isSessionExpired(response.statusCode, data)) {
      return ApiService._unauthorizedResult(data);
    }
    final msg = data is Map
        ? (data['detail'] ?? 'Gagal menandai submission')
        : 'Gagal menandai submission';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': ApiService._friendlyException(e)};
  }
}

// Fungsi Search (untuk Dashboard Search)
Future<Map<String, dynamic>> _miscSearch(String query) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};

    final uri = Uri.parse(
      '${ApiService.baseUrl}/search',
    ).replace(queryParameters: query.isNotEmpty ? {'q': query} : null);

    final response = await ApiService.client.get(
      uri,
      headers: ApiService.defaultHeaders(token: token),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return {'success': true, 'data': ApiService._safeJson(response.body)};
    }
    final body = ApiService._safeJson(response.body);
    if (ApiService._isSessionExpired(response.statusCode, body)) {
      return ApiService._unauthorizedResult(body);
    }
    final msg = body is Map ? (body['detail'] ?? 'Failed') : 'Failed';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': ApiService._friendlyException(e)};
  }
}

// Fungsi Update Profile
Future<Map<String, dynamic>> _miscUpdateProfile(
  Map<String, dynamic> payload,
) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};

    final response = await ApiService.client.put(
      Uri.parse('${ApiService.baseUrl}/auth/me'),
      headers: ApiService.defaultHeaders(token: token),
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));

    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }
    if (ApiService._isSessionExpired(response.statusCode, data)) {
      return ApiService._unauthorizedResult(data);
    }
    final msg = data is Map
        ? (data['detail'] ?? 'Failed to update profile')
        : 'Failed to update profile';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': ApiService._friendlyException(e)};
  }
}

// Export respons form ke Excel (.xlsx). Backend mengembalikan file biner,
// jadi kembalikan bytes + nama file (dari Content-Disposition backend).
Future<Map<String, dynamic>> _miscExport(
  String formId,
) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};
    final response = await ApiService.client
        .get(
          Uri.parse('${ApiService.baseUrl}/forms/$formId/export'),
          headers: {
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
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
    final body = ApiService._safeJson(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    final msg = body is Map
        ? (body['detail'] ?? 'Export gagal (${response.statusCode})')
        : 'Export gagal (${response.statusCode})';
    if (ApiService._isSessionExpired(response.statusCode, body)) {
      return ApiService._unauthorizedResult(body);
    }
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': ApiService._friendlyException(e)};
  }
}

String? _extractFilename(String? contentDisposition) {
  if (contentDisposition == null) return null;
  final match = RegExp(
    r'filename="?([^";]+)"?',
  ).firstMatch(contentDisposition);
  return match?.group(1)?.trim();
}

// Fungsi Upload File (untuk avatar, file upload question, dll.)
// Satu percobaan upload. Dipisah agar bisa di-retry untuk error koneksi-level
// ("HTTPS request failed, statusCode: 0") yang sering terjadi karena tunnel
// ngrok free putus saat tubuh request besar, dan umumnya bersifat sementara.
Future<Map<String, dynamic>> _uploadOnce(XFile file) async {
  final token = await ApiService.getToken();
  if (token == null) return {'success': false, 'message': 'No token found'};

  final request = http.MultipartRequest(
    'POST',
    Uri.parse('${ApiService.baseUrl}/uploads'),
  );
  request.headers['Authorization'] = 'Bearer $token';
  // Ngrok free (ngrok-free.dev) mewajibkan header ini; tanpanya agen bisa
  // diarahkan ke halaman interstitial/warning (bukan JSON) sehingga upload
  // tampak gagal. Konsisten dengan web (api/config.js & NgrokImage).
  request.headers['ngrok-skip-browser-warning'] = 'true';
  if (kIsWeb) {
    // Web: XFile.path adalah blob URL, harus pakai bytes
    final bytes = await file.readAsBytes();
    String filename = 'upload';
    try {
      filename = file.name;
    } catch (_) {
      try {
        filename = file.path.toString().split('/').last;
      } catch (_) {}
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );
  } else {
    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );
  }

  final streamedResponse = await request.send().timeout(
    const Duration(seconds: 60),
  );
  final responseBody = await streamedResponse.stream.bytesToString();
  final data = ApiService._safeJson(responseBody);

  if (streamedResponse.statusCode == 200 ||
      streamedResponse.statusCode == 201) {
    final url = data is Map ? data['file_url'] : null;
    return {'success': true, 'file_url': url};
  }
  final msg = data is Map
      ? (data['detail'] ?? 'Upload failed')
      : 'Upload failed';
  return {'success': false, 'message': msg.toString()};
}

Future<Map<String, dynamic>> _miscUpload(dynamic file) async {
  // Maksimal 3 percobaan. Error koneksi-level (status c 0) / timeout adalah
  // transien di tunnel ngrok; mengulang dengan payload yang sudah dikompres
  // (lihat formmakerpage._pickImage/_pickBanner) sering berhasil.
  const maxAttempts = 3;
  Map<String, dynamic> lastResult = {
    'success': false,
    'message': 'Upload gagal',
  };
  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await _uploadOnce(file);
    } on TimeoutException {
      lastResult = {
        'success': false,
        'message': 'Upload timeout — file terlalu besar atau koneksi lambat.',
      };
    } catch (e) {
      final raw = e.toString();
      final transient =
          raw.contains('statusCode: 0') ||
          raw.contains('Connection closed') ||
          raw.contains('SocketException') ||
          raw.contains('Request timeout') ||
          raw.contains('HandshakeException');
      if (transient && attempt < maxAttempts - 1) {
        // Jeda singkat sebelum percobaan berikutnya.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        lastResult = {
          'success': false,
          'message': 'Gagal mengunggah (koneksi terputus), mencoba lagi…',
        };
        continue;
      }
      final msg = transient
          ? 'Gagal mengunggah gambar (koneksi terputus). Coba gambar resolusi lebih kecil.'
          : raw;
      lastResult = {'success': false, 'message': msg};
    }
  }
  return lastResult;
}
