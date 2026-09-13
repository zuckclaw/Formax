// Dialog Verifikasi OTP — countdown + kirim ulang + verifikasi register.
// Dipindah verbatim dari `pages/login_page.dart` (Tahap 9a) tanpa perubahan
// apa pun: SELURUH class (_OtpDialog + _OtpDialogState) pindah utuh sehingga
// setState di dalamnya tetap sah sebagai member State. File ini adalah `part`
// dari library yang sama; ApiService/Timer/Material ikut via import induk.
// Call-site (_showOtpDialog) tidak berubah.
part of '../login_page.dart';

/// Dialog Verifikasi OTP dengan countdown 5 menit + tombol kirim ulang
/// (parity dengan web: timer direset saat resend, merah saat < 60 detik).
class _OtpDialog extends StatefulWidget {
  final String fullName;
  final String email;
  final String password;

  const _OtpDialog({
    required this.fullName,
    required this.email,
    required this.password,
  });

  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  final TextEditingController _otpController = TextEditingController();
  Timer? _timer;
  int _seconds = 300; // 5 menit, sama dengan web
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_seconds <= 0) {
        _timer?.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  String _formatTime() {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _resend() async {
    if (_seconds > 0) return;
    setState(() => _error = null);
    final res = await ApiService.sendOtp(widget.email);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _otpController.clear();
        _seconds = 300;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal mengirim ulang OTP'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Masukkan 6 digit kode OTP.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final res = await ApiService.register(
      widget.fullName,
      widget.email,
      widget.password,
      code,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _error = res['message'] as String? ?? 'Kode OTP tidak valid.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _seconds < 60;
    return AlertDialog(
      title: const Text('Verifikasi Email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Masukkan 6 digit kode OTP yang dikirim ke email Anda.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            enabled: !_submitting,
            decoration: const InputDecoration(
              hintText: 'Kode OTP',
              counterText: '',
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 15,
                color: urgent
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                'Kode berlaku ${_formatTime()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: urgent ? FontWeight.w600 : FontWeight.w400,
                  color: urgent
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Flexible(
                child: Text(
                  "Belum menerima kode?",
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ),
              TextButton(
                onPressed: _seconds > 0 || _submitting ? null : _resend,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _seconds > 0 ? 'Kirim ulang' : 'Kirim ulang',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E66D0),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFDC2626),
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E66D0),
            foregroundColor: Colors.white,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Verifikasi'),
        ),
      ],
    );
  }
}
