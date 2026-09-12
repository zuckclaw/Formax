// lib/utils/export_helper.dart
// Export respons form ke file .xlsx dari backend, lalu bagi via OS share sheet
// (bisa disimpan ke File/GDrive dst.) — parity dengan export Excel di web.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';

Future<void> exportFormSubmissionsWithShare(
  BuildContext context,
  String formId,
  String fallbackName,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Menyiapkan export Excel...')),
  );

  final res = await ApiService.exportFormSubmissions(formId);
  if (res['success'] != true || res['bytes'] == null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Export gagal: ${res['message'] ?? 'terjadi kesalahan'}'),
        backgroundColor: Colors.red.shade700,
      ),
    );
    return;
  }

  try {
    final dir = await getTemporaryDirectory();
    final filename = (res['filename'] as String?) ?? fallbackName;
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(res['bytes'] as List<int>);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: filename,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Gagal menyimpan file export: $e'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}
