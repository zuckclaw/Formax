import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:form4x/services/api_service.dart';

/// Regresi fail-closed auth: tanpa sesi valid, akses DITOLAK.
/// Helper murni (tanpa network) — gerbang sesungguhnya memakai
/// ApiService.hasValidSession() yang memanggil /auth/me.
void main() {
  String tokenWithExp(int expSec) {
    String b64(Map<String, dynamic> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    return '${b64({'alg': 'HS256'})}.${b64({'sub': 'u1', 'exp': expSec})}.sig';
  }

  group('isTokenExpired (cek exp JWT lokal)', () {
    test('token exp lewat → true', () {
      final past = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
      expect(ApiService.isTokenExpired(tokenWithExp(past)), isTrue);
    });

    test('token exp masa depan → false', () {
      final future = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      expect(ApiService.isTokenExpired(tokenWithExp(future)), isFalse);
    });

    test('token rusak → false (validasi final via backend)', () {
      expect(ApiService.isTokenExpired('bukan-token'), isFalse);
      expect(ApiService.isTokenExpired(''), isFalse);
    });
  });

  group('klasifikasi result auth', () {
    test('expired → sesi invalid', () {
      expect(
        ApiService.isAuthInvalidResult(
            {'success': false, 'expired': true}),
        isTrue,
      );
      expect(
        ApiService.isAuthInvalidResult({'success': false}),
        isFalse,
      );
    });

    test('pesan transport → connection failure', () {
      expect(
        ApiService.isConnectionFailureResult(
            {'success': false, 'connection': true}),
        isTrue,
      );
      expect(
        ApiService.isConnectionFailureResult({
          'success': false,
          'message': 'Tidak dapat terhubung ke server. Pastikan backend.'
        }),
        isTrue,
      );
      expect(
        ApiService.isConnectionFailureResult(
            {'success': false, 'message': 'Form tidak ditemukan'}),
        isFalse,
      );
      expect(
        ApiService.isConnectionFailureResult(
            {'success': false, 'message': 'Token salah atau belum diisi'}),
        isFalse,
      );
    });
  });
}
