// Endpoint AUTH ApiService — login, OTP, reset password, register, profil.
// Dipindah verbatim dari `services/api_service.dart` (Tahap 8a) tanpa
// perubahan logika. File ini adalah `part` dari library yang sama sehingga
// helper privat (_safeJson, _friendlyError, saveToken, ...) tetap sah.
// ApiService.* tetap menjadi fasad publik (forwarder satu baris) sehingga
// puluhan call-site di seluruh app TIDAK berubah.
// Catatan: static member ApiService (baseUrl, _safeJson, ...) WAJIB
// di-qualify (ApiService.xxx) dari fungsi top-level — aturan Dart yang sama
// seperti extension (lihat pelajaran Tahap 3a).
part of '../api_service.dart';

Future<Map<String, dynamic>> _authLogin(
  String email,
  String password, {
  bool rememberMe = true,
}) async {
  try {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200 &&
        data is Map &&
        data['access_token'] is String &&
        (data['access_token'] as String).isNotEmpty) {
      await ApiService.saveToken(data['access_token'], rememberMe: rememberMe);
      return {'success': true, 'data': data};
    } else {
      return {
        'success': false,
        'message': ApiService._friendlyError(response, 'Login gagal'),
      };
    }
  } catch (e) {
    return {'success': false, 'message': ApiService._friendlyException(e)};
  }
}

// Fungsi Request OTP
Future<Map<String, dynamic>> _authSendOtp(String email) async {
  try {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200 &&
        data is Map &&
        data['message'] != null) {
      return {'success': true, 'data': data};
    } else {
      return {
        'success': false,
        'message': ApiService._friendlyError(response, 'Gagal mengirim OTP'),
      };
    }
  } catch (e) {
    return {'success': false, 'message': ApiService._friendlyException(e)};
  }
}

Future<Map<String, dynamic>> _authRequestPasswordReset(String email) async {
  try {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200 &&
        data is Map &&
        data['message'] != null) {
      return {'success': true, 'data': data};
    } else {
      return {
        'success': false,
        'message': ApiService._friendlyError(response, 'Gagal meminta reset password'),
      };
    }
  } catch (e) {
    return {'success': false, 'message': ApiService._friendlyException(e)};
  }
}

Future<Map<String, dynamic>> _authResetPassword(
  String email,
  String otp,
  String newPassword,
) async {
  try {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      }),
    );
    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200 &&
        data is Map &&
        data['message'] != null &&
        data['access_token'] is String) {
      await ApiService.saveToken(data['access_token'] as String);
      return {'success': true, 'data': data};
    }
    return {
      'success': false,
      'message': ApiService._friendlyError(response, 'Gagal mengubah password'),
    };
  } catch (e) {
    return {'success': false, 'message': ApiService._friendlyException(e)};
  }
}

Future<Map<String, dynamic>> _authVerifyPasswordResetOtp(
  String email,
  String otp,
) async {
  try {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/auth/verify-reset-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200 &&
        data is Map &&
        data['message'] != null) {
      return {'success': true, 'data': data};
    }
    return {
      'success': false,
      'message': ApiService._friendlyError(response, 'Kode OTP tidak valid'),
    };
  } catch (e) {
    return {'success': false, 'message': ApiService._friendlyException(e)};
  }
}

// Fungsi Register (Signup)
Future<Map<String, dynamic>> _authRegister(
  String fullName,
  String email,
  String password,
  String otp,
) async {
  try {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
        'otp': otp,
      }),
    );

    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (data is Map && data.containsKey('access_token')) {
        await ApiService.saveToken(data['access_token']);
      }
      return {'success': true, 'data': data};
    } else {
      final msg = data is Map
          ? (data['detail'] ?? 'Registration failed')
          : 'Registration failed';
      return {'success': false, 'message': msg.toString()};
    }
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}

// Fungsi Get User Profile
Future<Map<String, dynamic>> _authGetMe() async {
  try {
    final token = await ApiService.getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }

    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = ApiService._safeJson(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    } else {
      final msg = data is Map
          ? (data['detail'] ?? 'Failed to get profile')
          : 'Failed to get profile';
      return {'success': false, 'message': msg.toString()};
    }
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}
