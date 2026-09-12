import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import '../services/api_service.dart';
import 'fillformpage.dart';

class ScanQRPage extends StatefulWidget {
  const ScanQRPage({super.key});

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage> {
  bool _isProcessing = false;
  String? _errorText;
  QRViewController? _controller;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      _controller?.pauseCamera();
    }
    _controller?.resumeCamera();
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (_isProcessing) return;

      final link = scanData.code ?? '';
      if (link.isEmpty) return;

      setState(() => _isProcessing = true);

      final result = await ApiService.validateFormLink(link);
      if (!mounted) return;

      if (result['success'] == true) {
        final slug = result['data']['slug'] ?? '';
        if (slug.isNotEmpty) {
          _controller?.pauseCamera();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => FillFormPage(slug: slug)),
          );
        } else {
          setState(() => _errorText = 'Form tidak ditemukan');
        }
      } else {
        setState(() => _errorText = result['message'] ?? 'Link tidak valid');
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _errorText != null) {
            setState(() => _errorText = null);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB4C5D4),
        title: const Text('Scan QR', style: TextStyle(color: Colors.white)),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: QRView(
              key: _qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: const Color(0xFFB4C5D4),
                borderRadius: 12,
                borderLength: 30,
                borderWidth: 8,
                cutOutSize: 280,
              ),
            ),
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _errorText!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
