import 'dart:async';

import 'package:flutter/material.dart';
import 'home_page.dart';
import '../services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLogin = true;
  bool _isLoading = false;
  bool _rememberMe = true; // State untuk remember me
  bool _showPassword =
      false; // Toggle tampilkan/sembunyikan password (parity web)

  final TextEditingController loginEmailController = TextEditingController();
  final TextEditingController loginPasswordController = TextEditingController();

  final TextEditingController registerEmailController = TextEditingController();
  final TextEditingController registerPasswordController =
      TextEditingController();
  final TextEditingController registerFullNameController =
      TextEditingController();

  @override
  void dispose() {
    loginEmailController.dispose();
    loginPasswordController.dispose();
    registerEmailController.dispose();
    registerPasswordController.dispose();
    registerFullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Top image
          Align(
            alignment: Alignment.topCenter,
            child: Image.asset(
              'assets/images/bgafmx.png',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // Bottom image
          Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset(
              'assets/images/bgbfmx.png',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),

                      // Logo
                      Align(
                        alignment: Alignment.topCenter,
                        child: Image.asset('assets/icons/logoForm4x.png'),
                      ),

                      const SizedBox(height: 20),

                      // Toggle buttons
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isLogin = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLogin
                                        ? const Color(0xFF1E66D0)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Login',
                                    style: TextStyle(
                                      color: isLogin
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isLogin = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !isLogin
                                        ? const Color(0xFF1E66D0)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Register',
                                    style: TextStyle(
                                      color: !isLogin
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (!isLogin) ...[
                        _buildLabel('Full Name*'),
                        _buildTextField(
                          key: const ValueKey('register_fullname'),
                          controller: registerFullNameController,
                          hint: 'Enter your full name',
                        ),
                        const SizedBox(height: 14),
                      ],

                      _buildLabel('Email Address*'),
                      _buildTextField(
                        key: isLogin
                            ? const ValueKey('login_email')
                            : const ValueKey('register_email'),
                        controller: isLogin
                            ? loginEmailController
                            : registerEmailController,
                        hint: 'Enter your email address',
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                      ),

                      const SizedBox(height: 14),

                      _buildLabel('Password*'),
                      _buildTextField(
                        key: isLogin
                            ? const ValueKey('login_password')
                            : const ValueKey('register_password'),
                        controller: isLogin
                            ? loginPasswordController
                            : registerPasswordController,
                        hint: 'Enter your password',
                        isPassword: true,
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _rememberMe = value);
                              }
                            },
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const Text(
                            'Remember me',
                            style: TextStyle(fontSize: 12, color: _labelColor),
                          ),
                          if (isLogin) ...[
                            const Spacer(),
                            TextButton(
                              onPressed: _showForgotPasswordDialog,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF1E66D0),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Lupa password?',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E66D0),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  setState(() {
                                    _isLoading = true;
                                  });

                                  final rawEmail = isLogin
                                      ? loginEmailController.text.trim()
                                      : registerEmailController.text.trim();
                                  final email = rawEmail.toLowerCase();
                                  final password = isLogin
                                      ? loginPasswordController.text.trim()
                                      : registerPasswordController.text.trim();

                                  // Validasi format email dengan Regex sederhana
                                  final bool emailValid = RegExp(
                                    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                                  ).hasMatch(email);

                                  if (email.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Email tidak boleh kosong!',
                                        ),
                                      ),
                                    );
                                    setState(() => _isLoading = false);
                                    return;
                                  } else if (!emailValid) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Format email tidak valid!',
                                        ),
                                      ),
                                    );
                                    setState(() => _isLoading = false);
                                    return;
                                  }

                                  if (password.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Password tidak boleh kosong!',
                                        ),
                                      ),
                                    );
                                    setState(() => _isLoading = false);
                                    return;
                                  } else if (password.length < 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Password minimal 6 karakter!',
                                        ),
                                      ),
                                    );
                                    setState(() => _isLoading = false);
                                    return;
                                  }

                                  Map<String, dynamic>? result;
                                  if (isLogin) {
                                    result = await ApiService.login(
                                      email,
                                      password,
                                      rememberMe: _rememberMe,
                                    );
                                  } else {
                                    final fullName = registerFullNameController
                                        .text
                                        .trim();
                                    if (fullName.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Full name cannot be empty',
                                          ),
                                        ),
                                      );
                                      setState(() {
                                        _isLoading = false;
                                      });
                                      return;
                                    }

                                    final otpResult = await ApiService.sendOtp(
                                      email,
                                    );
                                    if (otpResult['success'] == true) {
                                      if (!context.mounted) return;
                                      setState(() {
                                        _isLoading = false;
                                      });

                                      // Loop: tetap di dialog OTP (countdown berjalan)
                                      // sampai verifikasi sukses / dibatalkan — seperti web.
                                      final registered = await _showOtpDialog(
                                        fullName,
                                        email,
                                        password,
                                      );
                                      // registered == true hanya saat
                                      // verifikasi OTP BERHASIL (pop true).
                                      // Batal / waktu habis → pop false →
                                      // jangan lanjut masuk aplikasi.
                                      if (registered == true) {
                                        result = {'success': true};
                                      } else {
                                        return;
                                      }
                                    } else {
                                      result = otpResult;
                                    }
                                  }

                                  if (!context.mounted) return;
                                  setState(() {
                                    _isLoading = false;
                                  });

                                  if (result['success'] == true) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const HomePage(),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          result['message'] ??
                                              'An error occurred',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E66D0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(isLogin ? 'Login' : 'Register'),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLogin
                                ? "No account? "
                                : "Already have an account? ",
                            style: const TextStyle(
                              fontSize: 12,
                              color: _labelColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isLogin &&
                                    loginEmailController.text.isNotEmpty &&
                                    registerEmailController.text.isEmpty) {
                                  registerEmailController.text =
                                      loginEmailController.text.trim();
                                } else if (!isLogin &&
                                    registerEmailController.text.isNotEmpty &&
                                    loginEmailController.text.isEmpty) {
                                  loginEmailController.text =
                                      registerEmailController.text.trim();
                                }
                                isLogin = !isLogin;
                              });
                            },
                            child: Text(
                              isLogin ? 'Register' : 'Login',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1E66D0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ), // closes SafeArea
        ],
      ),
    );
  }

  Future<bool?> _showOtpDialog(String fullName, String email, String password) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _OtpDialog(fullName: fullName, email: email, password: password),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(
      text: loginEmailController.text.trim(),
    );
    final otpController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    var step = 0;
    var loading = false;
    var showNewPassword = false;
    var showConfirmPassword = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.lock_reset, color: Color(0xFF1E66D0)),
                const SizedBox(width: 10),
                Text(
                  step == 0
                      ? 'Lupa password'
                      : step == 1
                      ? 'Verifikasi OTP'
                      : 'Password baru',
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step == 0
                        ? 'Masukkan email akun yang ingin diubah passwordnya.'
                        : step == 1
                        ? 'Masukkan kode OTP yang dikirim ke email Anda.'
                        : 'Buat password baru untuk akun Anda.',
                  ),
                  const SizedBox(height: 16),
                  if (step == 0)
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                  if (step == 1) const SizedBox(height: 12),
                  if (step == 1)
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Kode OTP',
                        prefixIcon: Icon(Icons.pin_outlined),
                        counterText: '',
                      ),
                    ),
                  if (step == 2) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: !showNewPassword,
                      decoration: InputDecoration(
                        labelText: 'Password baru',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: showNewPassword
                              ? 'Sembunyikan password'
                              : 'Lihat password',
                          icon: Icon(
                            showNewPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setDialogState(
                            () => showNewPassword = !showNewPassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: !showConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Ketik ulang password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: showConfirmPassword
                              ? 'Sembunyikan password'
                              : 'Lihat password',
                          icon: Icon(
                            showConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setDialogState(
                            () => showConfirmPassword = !showConfirmPassword,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        final email = emailController.text.trim().toLowerCase();
                        if (step == 0 && !email.contains('@')) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Masukkan email yang valid'),
                            ),
                          );
                          return;
                        }
                        if (step == 1 &&
                            otpController.text.trim().length != 6) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Masukkan 6 digit kode OTP'),
                            ),
                          );
                          return;
                        }
                        if (step == 2 &&
                            (passwordController.text.length < 6 ||
                                passwordController.text !=
                                    confirmController.text)) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password minimal 6 karakter dan harus sama',
                              ),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => loading = true);
                        final result = step == 0
                            ? await ApiService.requestPasswordReset(email)
                            : step == 1
                            ? await ApiService.verifyPasswordResetOtp(
                                email,
                                otpController.text.trim(),
                              )
                            : await ApiService.resetPassword(
                                email,
                                otpController.text.trim(),
                                passwordController.text,
                              );
                        if (!dialogContext.mounted) return;
                        setDialogState(() => loading = false);
                        if (result['success'] == true) {
                          if (step < 2) {
                            setDialogState(() => step++);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Kode reset telah dikirim ke email Anda',
                                ),
                              ),
                            );
                          } else {
                            Navigator.pop(dialogContext);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomePage(),
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['message'] ?? 'Proses reset gagal',
                              ),
                            ),
                          );
                        }
                      },
                child: Text(
                  step == 0
                      ? 'Confirm email'
                      : step == 1
                      ? 'Confirm OTP'
                      : 'Confirm password',
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      emailController.dispose();
      otpController.dispose();
      passwordController.dispose();
      confirmController.dispose();
    }
  }

  // Halaman login/register dirancang dengan kartu terang (light) dan textfield
  // berlatar putih, apapun tema sistem. Warna teks ditetapkan eksplisit agar
  // label & ketikan selalu hitam (tidak ikut tema gelap yang membuatnya putih
  // sehingga tak terlihat di atas latar putih/light-blue yang dikunci).
  static const _labelColor = Color(0xFF111827);
  static const _inputTextColor = Color(0xFF111827);
  static const _hintColor = Color(0xFF9CA3AF);

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _labelColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    bool isPassword = false,
    TextInputType? keyboardType,
    bool autocorrect = true,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      autocorrect: autocorrect,
      obscureText: isPassword ? !_showPassword : obscureText,
      style: const TextStyle(color: _inputTextColor, fontSize: 14),
      cursorColor: const Color(0xFF1E66D0),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _hintColor, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF1E66D0), width: 1.5),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: Colors.black45,
                ),
                tooltip: _showPassword
                    ? 'Sembunyikan password'
                    : 'Tampilkan password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
              )
            : null,
      ),
    );
  }
}

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
