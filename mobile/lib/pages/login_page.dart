import 'dart:async';

import 'package:flutter/material.dart';
import 'home_page.dart';
import '../services/api_service.dart';

// Part: dialog OTP — Tahap 9a. Seluruh class pindah utuh (setState tetap sah
// sebagai member State); call-site tidak berubah.
part 'login/otp_dialog_part.dart';

// Part: dialog lupa-password — Tahap 9b. Mutasi via setDialogState lokal,
// tanpa delegasi; call-site tidak berubah.
part 'login/forgot_password_part.dart';

// Part: field builder — Tahap 9c. setState didelegasikan ke
// _toggleShowPassword; static const di-qualify (tetap const).
// Call-site di build() tidak berubah.
part 'login/fields_part.dart';

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

  // Helper toggle password untuk extension fields (login/fields_part.dart):
  // setState HANYA di member State. Isi = pindahan verbatim callback eye-icon.
  void _toggleShowPassword() {
    setState(() => _showPassword = !_showPassword);
  }

  // NOTE (Tahap 9b): _showForgotPasswordDialog pindah ke
  // login/forgot_password_part.dart (verbatim; mutasi via setDialogState
  // lokal, tanpa delegasi). Tanpa perubahan logika/call-site.

  // Halaman login/register dirancang dengan kartu terang (light) dan textfield
  // berlatar putih, apapun tema sistem. Warna teks ditetapkan eksplisit agar
  // label & ketikan selalu hitam (tidak ikut tema gelap yang membuatnya putih
  // sehingga tak terlihat di atas latar putih/light-blue yang dikunci).
  static const _labelColor = Color(0xFF111827);
  static const _inputTextColor = Color(0xFF111827);
  static const _hintColor = Color(0xFF9CA3AF);

  // NOTE (Tahap 9c): _buildLabel & _buildTextField pindah ke
  // login/fields_part.dart; setState eye-icon didelegasikan ke
  // _toggleShowPassword, static const di-qualify (tetap const-evaluable).
  // Tanpa perubahan logika/call-site.
}

// NOTE (Tahap 9a): _OtpDialog + _OtpDialogState pindah utuh ke
// login/otp_dialog_part.dart (verbatim; setState tetap sah sebagai member
// State). Tanpa perubahan logika/call-site.
