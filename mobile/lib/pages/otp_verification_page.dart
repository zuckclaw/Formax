import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Halaman Verifikasi OTP Mobile yang responsif, mendukung light/dark mode,
/// dan jumlah kotak/digit OTP yang dinamis (misal: 4, 6, dsb).
class OtpVerificationPage extends StatefulWidget {
  final String email;
  final int length;
  final String title;
  final String? subtitle;
  final String buttonText;
  final int initialSeconds;

  /// Callback kustom verifikasi OTP (opsional). Jika mengembalikan true,
  /// halaman akan pop dengan nilai true.
  final Future<bool> Function(String otp)? onVerify;

  /// Callback kustom kirim ulang OTP (opsional).
  final Future<bool> Function()? onResend;

  /// Opsional untuk alur registrasi default Form4x
  final String? fullName;
  final String? password;

  /// Opsional untuk alur reset password
  final bool isPasswordReset;

  const OtpVerificationPage({
    super.key,
    required this.email,
    this.length = 6,
    this.title = 'Verifikasi OTP',
    this.subtitle,
    this.buttonText = 'Konfirmasi & Buat Akun',
    this.initialSeconds = 300, // 5 menit
    this.onVerify,
    this.onResend,
    this.fullName,
    this.password,
    this.isPasswordReset = false,
  }) : assert(length > 0 && length <= 10, 'Panjang OTP harus antara 1 dan 10');

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  late final TextEditingController _rawOtpController;
  late final FocusNode _focusNode;

  Timer? _timer;
  late int _seconds;
  bool _submitting = false;
  String? _error;
  String _currentOtp = '';

  @override
  void initState() {
    super.initState();
    _seconds = widget.initialSeconds;
    _rawOtpController = TextEditingController();
    _focusNode = FocusNode();

    _rawOtpController.addListener(_onOtpInputChanged);

    _startTimer();

    // Auto-focus setelah frame selesai dimuat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onOtpInputChanged() {
    final text = _rawOtpController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > widget.length) {
      final truncated = text.substring(0, widget.length);
      _rawOtpController.value = TextEditingValue(
        text: truncated,
        selection: TextSelection.collapsed(offset: truncated.length),
      );
      return;
    }

    if (text != _currentOtp) {
      setState(() {
        _currentOtp = text;
        _error = null;
      });

      // Otomatis verifikasi bila sudah lengkap terisi
      if (_currentOtp.length == widget.length) {
        _submitOtp();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
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
    _rawOtpController.removeListener(_onOtpInputChanged);
    _rawOtpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      if (text.isNotEmpty) {
        final target = text.length > widget.length
            ? text.substring(0, widget.length)
            : text;
        _rawOtpController.value = TextEditingValue(
          text: target,
          selection: TextSelection.collapsed(offset: target.length),
        );
        HapticFeedback.lightImpact();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada kode angka pada papan klip'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _resendOtp() async {
    if (_seconds > 0 || _submitting) return;

    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      bool success = false;
      String? errorMessage;

      if (widget.onResend != null) {
        success = await widget.onResend!();
      } else if (widget.isPasswordReset) {
        final res = await ApiService.requestPasswordReset(widget.email);
        success = res['success'] == true;
        errorMessage = res['message'] as String?;
      } else {
        final res = await ApiService.sendOtp(widget.email);
        success = res['success'] == true;
        errorMessage = res['message'] as String?;
      }

      if (!mounted) return;

      if (success) {
        setState(() {
          _seconds = widget.initialSeconds;
          _rawOtpController.clear();
          _submitting = false;
        });
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kode OTP baru telah dikirimkan ke email Anda'),
            backgroundColor: Color(0xFF0053DB),
          ),
        );
      } else {
        setState(() {
          _submitting = false;
          _error = errorMessage ?? 'Gagal mengirim ulang OTP';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Terjadi kesalahan saat mengirim ulang kode';
      });
    }
  }

  Future<void> _submitOtp() async {
    if (_currentOtp.length != widget.length || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (widget.onVerify != null) {
        final success = await widget.onVerify!(_currentOtp);
        if (!mounted) return;
        if (success) {
          Navigator.pop(context, _currentOtp);
        } else {
          setState(() {
            _submitting = false;
            _error ??= 'Kode OTP tidak valid.';
          });
        }
        return;
      }

      // Alur bawaan registrasi Form4x
      if (widget.fullName != null && widget.password != null) {
        final res = await ApiService.register(
          widget.fullName!,
          widget.email,
          widget.password!,
          _currentOtp,
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
        return;
      }

      // Alur bawaan reset password
      if (widget.isPasswordReset) {
        final res = await ApiService.verifyPasswordResetOtp(
          widget.email,
          _currentOtp,
        );
        if (!mounted) return;
        if (res['success'] == true) {
          Navigator.pop(context, _currentOtp);
        } else {
          setState(() {
            _error = res['message'] as String? ?? 'Kode OTP tidak valid.';
            _submitting = false;
          });
        }
        return;
      }

      // Default: pop OTP string
      Navigator.pop(context, _currentOtp);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Terjadi kendala verifikasi. Silakan coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final urgent = _seconds < 60;
    final subtitleText = widget.subtitle ??
        'Kode ${widget.length} digit telah dikirim ke email kamu. Masukkan di bawah untuk lanjut.';

    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      body: Stack(
        children: [
          // Background wave atas
          Align(
            alignment: Alignment.topCenter,
            child: Opacity(
              opacity: isDark ? 0.4 : 1.0,
              child: Image.asset(
                'assets/images/bgafmx.png',
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Background wave bawah
          Align(
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: isDark ? 0.35 : 1.0,
              child: Image.asset(
                'assets/images/bgbfmx.png',
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Konten Utama
          SafeArea(
            child: Column(
              children: [
                // Top bar dengan tombol kembali
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                        tooltip: 'Kembali',
                        onPressed: _submitting ? null : () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                ),

                // Card tengah scrollable
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 390),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 26,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF23233F)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF2D2D4A)
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.35 : 0.07,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Judul
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark
                                    ? AppColors.darkTextHeading
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Subtitle
                            Text(
                              subtitleText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Email pill dengan status dot hijau
                            _buildEmailPill(isDark),
                            const SizedBox(height: 18),

                            // Ilustrasi Amplop OTP dengan ikon centang
                            _buildEnvelopeIllustration(isDark),
                            const SizedBox(height: 16),

                            // Garis/Dash indikator progres sesuai panjang digit OTP
                            _buildProgressDashes(isDark),
                            const SizedBox(height: 14),

                            // Kotak Input Angka OTP (Jumlah dinamis sesuai widget.length)
                            _buildOtpBoxes(isDark),
                            const SizedBox(height: 10),

                            // Helper text: Tempel kode
                            InkWell(
                              onTap: _pasteFromClipboard,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  'Tempel kode dari email — otomatis terisi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? const Color(0xFF7A8599)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Baris Kirim Ulang & Countdown Timer
                            _buildTimerRow(isDark, urgent),

                            // Pesan Error jika ada
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFDC2626).withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 18),

                            // Tombol Konfirmasi Utama (#0053DB)
                            _buildConfirmButton(isDark),
                            const SizedBox(height: 14),

                            // Catatan Keamanan Footer
                            _buildSecurityNote(isDark),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // ─── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildEmailPill(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A5C) : const Color(0xFFDBEAFE),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Green active dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.email,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvelopeIllustration(bool isDark) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF2A2A4A), Color(0xFF1E1E3A)]
              : const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A5C) : const Color(0xFFBFDBFE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0053DB).withValues(
              alpha: isDark ? 0.2 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 52,
          height: 52,
          child: CustomPaint(
            painter: _EnvelopeIconPainter(isDark: isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDashes(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        final isFilled = index < _currentOtp.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: (22.0 - (widget.length > 6 ? (widget.length - 6) * 2.0 : 0.0))
              .clamp(12.0, 22.0),
          height: 3.5,
          decoration: BoxDecoration(
            gradient: isFilled
                ? const LinearGradient(
                    colors: [Color(0xFF0053DB), Color(0xFF60A5FA)],
                  )
                : null,
            color: isFilled
                ? null
                : (isDark ? const Color(0xFF3A3A5C) : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildOtpBoxes(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = 8.0 * (widget.length - 1);
        final itemWidth =
            ((constraints.maxWidth - totalSpacing) / widget.length)
                .clamp(34.0, 48.0);
        final itemHeight = (itemWidth * 1.18).clamp(44.0, 56.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focusNode.requestFocus();
            _rawOtpController.selection =
                TextSelection.collapsed(offset: _currentOtp.length);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Row of custom visual boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.length, (index) {
                  final hasDigit = index < _currentOtp.length;
                  final isCurrent = index == _currentOtp.length &&
                      _focusNode.hasFocus;
                  final digit = hasDigit ? _currentOtp[index] : '';

                  Color borderColor;
                  if (isCurrent) {
                    borderColor = const Color(0xFF0053DB);
                  } else if (hasDigit) {
                    borderColor = isDark
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFF0053DB);
                  } else {
                    borderColor = isDark
                        ? const Color(0xFF3A3A5C)
                        : const Color(0xFFD6E6FB);
                  }

                  return Container(
                    width: itemWidth,
                    height: itemHeight,
                    margin: EdgeInsets.only(
                      right: index == widget.length - 1 ? 0 : 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? (hasDigit
                              ? const Color(0xFF2E2E55)
                              : const Color(0xFF252545))
                          : (hasDigit ? const Color(0xFFF8FBFF) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: isCurrent ? 2.0 : 1.5,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0053DB).withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      digit,
                      style: TextStyle(
                        fontSize: (itemWidth * 0.48).clamp(18.0, 24.0),
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextHeading
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  );
                }),
              ),

              // Hidden transparent TextField to handle keyboard input, autofill & paste
              Opacity(
                opacity: 0.0,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: itemHeight,
                  child: TextField(
                    controller: _rawOtpController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: widget.length,
                    enableInteractiveSelection: true,
                    showCursor: false,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimerRow(bool isDark, bool urgent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252545) : const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A5C) : const Color(0xFFE0EAFF),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bagian Kiri: Belum dapat kode + Kirim Ulang
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF94A3B8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Belum dapat kode?',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF475569),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _seconds == 0 && !_submitting ? _resendOtp : null,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _seconds == 0
                          ? const Color(0xFF0053DB)
                          : (isDark
                              ? const Color(0xFF1E1E3A)
                              : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: _seconds == 0
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0053DB).withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      'Kirim ulang',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _seconds == 0
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFF7A8599)
                                : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Bagian Kanan: Timer badge pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: urgent
                  ? (isDark
                      ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                      : const Color(0xFFFEE2E2))
                  : (isDark ? const Color(0xFF1E1E3A) : Colors.white),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: urgent
                    ? const Color(0xFFDC2626).withValues(alpha: 0.3)
                    : (isDark
                        ? const Color(0xFF3A3A5C)
                        : const Color(0xFFE2E8F0)),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.2 : 0.04,
                  ),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: urgent
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0053DB),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (urgent
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF0053DB))
                            .withValues(alpha: 0.35),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTime(_seconds),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: urgent
                        ? (isDark
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFDC2626))
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(bool isDark) {
    final isReady = _currentOtp.length == widget.length && !_submitting;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isReady ? _submitOtp : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0053DB),
          disabledBackgroundColor: isDark
              ? const Color(0xFF2E2E55)
              : const Color(0xFFCBD5E1),
          foregroundColor: Colors.white,
          disabledForegroundColor: isDark
              ? const Color(0xFF7A8599)
              : const Color(0xFF64748B),
          elevation: isReady ? 4 : 0,
          shadowColor: const Color(0xFF0053DB).withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.buttonText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  Widget _buildSecurityNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252545) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D4A) : const Color(0xFFEDF2F7),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 14,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Kode berlaku 5 menit · jaga kerahasiaan kode',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter menggambar ikon amplop dengan circular checkmark badge di tengah
class _EnvelopeIconPainter extends CustomPainter {
  final bool isDark;

  _EnvelopeIconPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeColor = const Color(0xFF0053DB);
    final badgeBg = isDark ? const Color(0xFF1E1E3A) : Colors.white;

    // Body amplop
    final envelopeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 10, size.width - 8, size.height - 18),
      const Radius.circular(8),
    );

    final bgPaint = Paint()
      ..color = (isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF0F7FF))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(envelopeRect, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFBFDBFE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(envelopeRect, borderPaint);

    // Flap lipatan amplop (V-shape)
    final flapPath = Path()
      ..moveTo(4, 12)
      ..lineTo(size.width / 2, size.height / 2 + 3)
      ..lineTo(size.width - 4, 12);

    final flapPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.8;
    canvas.drawPath(flapPath, flapPaint);

    // Lingkaran badge di tengah
    final badgeCenter = Offset(size.width / 2, size.height / 2 + 2);
    const badgeRadius = 10.0;

    final circleBgPaint = Paint()
      ..color = badgeBg
      ..style = PaintingStyle.fill;
    canvas.drawCircle(badgeCenter, badgeRadius, circleBgPaint);

    final circleBorderPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(badgeCenter, badgeRadius, circleBorderPaint);

    // Simbol centang di dalam badge
    final checkPath = Path()
      ..moveTo(badgeCenter.dx - 4.2, badgeCenter.dy + 0.2)
      ..lineTo(badgeCenter.dx - 1.2, badgeCenter.dy + 3.2)
      ..lineTo(badgeCenter.dx + 4.6, badgeCenter.dy - 2.8);

    final checkPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.8;
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _EnvelopeIconPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
