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

    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/forms/$formId/submissions'),
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

// AKTIVITAS SAYA — daftar form yang pernah/sedang diisi user sebagai responden.
// Endpoint backend: GET /submissions/me → List[MySubmissionOut]
Future<Map<String, dynamic>> _miscMySubs() async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};

    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/submissions/me'),
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

// Hasil submission milik responden (untuk "Lihat Hasil" di Aktivitas Saya).
// Endpoint backend: GET /submissions/{submission_id}/result → SubmissionResultOut
Future<Map<String, dynamic>> _miscSubResult(
  String submissionId,
) async {
  try {
    final token = await ApiService.getToken();
    final respondentKey = await ApiService.getRespondentKey();
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/submissions/$submissionId/result'),
      headers: {
        'Content-Type': 'application/json',
        'X-Respondent-Key': respondentKey,
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }
    final msg = data is Map
        ? (data['detail'] ?? 'Gagal memuat hasil')
        : 'Gagal memuat hasil';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
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

    final response = await http.get(
      uri,
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

// Fungsi Update Profile
Future<Map<String, dynamic>> _miscUpdateProfile(
  Map<String, dynamic> payload,
) async {
  try {
    final token = await ApiService.getToken();
    if (token == null) return {'success': false, 'message': 'No token found'};

    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    }
    final msg = data is Map
        ? (data['detail'] ?? 'Failed to update profile')
        : 'Failed to update profile';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
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
    final response = await http
        .get(
          Uri.parse('${ApiService.baseUrl}/forms/$formId/export'),
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
    final body = ApiService._safeJson(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    final msg = body is Map
        ? (body['detail'] ?? 'Export gagal (${response.statusCode})')
        : 'Export gagal (${response.statusCode})';
    return {'success': false, 'message': msg.toString()};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
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
Future<Map<String, dynamic>> _uploadOnce(dynamic file) async {
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
      filename = file.name as String;
    } catch (_) {
      try {
        filename = file.path.toString().split('/').last;
      } catch (_) {}
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes as List<int>,
        filename: filename,
      ),
    );
  } else {
    request.files.add(
      await http.MultipartFile.fromPath('file', file.path as String),
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
