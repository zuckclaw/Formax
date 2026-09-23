// Halaman & Alur Lupa Password Modern (Input Email -> Verifikasi OTP -> Password Baru).
// Terintegrasi langsung dengan OtpVerificationPage dan backend Form4x.
part of '../login_page.dart';

extension _LoginForgotPassword on _LoginPageState {
  Future<void> _showForgotPasswordDialog() {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(
          initialEmail: loginEmailController.text.trim(),
        ),
      ),
    );
  }
}

/// Halaman 1 Lupa Password: Input Email untuk Mengirimkan Kode OTP
class ForgotPasswordPage extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController _emailController;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    final bool emailValid = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    ).hasMatch(email);

    if (email.isEmpty) {
      setState(() => _error = 'Email tidak boleh kosong');
      return;
    }
    if (!emailValid) {
      setState(() => _error = 'Format email tidak valid');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService.requestPasswordReset(email);
      if (!mounted) return;

      setState(() => _loading = false);

      if (res['success'] == true) {
        // Tampilkan pesan konfirmasi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kode OTP telah dikirimkan ke $email'),
            backgroundColor: const Color(0xFF0053DB),
            duration: const Duration(seconds: 3),
          ),
        );

        // Setelah memasukkan email -> LANGSUNG MASUK KE PAGE VERIFIKASI OTP
        final verifiedOtp = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationPage(
              email: email,
              isPasswordReset: true,
              title: 'Verifikasi OTP',
              subtitle:
                  'Kode 6 digit telah dikirim ke email kamu. Masukkan di bawah untuk lanjut.',
              buttonText: 'Verifikasi & Lanjut',
            ),
          ),
        );

        if (!mounted) return;

        // Jika OTP sukses terverifikasi, lanjut ke form Password Baru
        if (verifiedOtp != null && verifiedOtp is String && verifiedOtp.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResetPasswordPage(
                email: email,
                otp: verifiedOtp,
              ),
            ),
          );
        }
      } else {
        setState(() {
          _error = res['message'] as String? ?? 'Gagal mengirimkan kode OTP reset';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Terjadi kendala jaringan. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      body: Stack(
        children: [
          // Wave atas
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

          // Wave bawah
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
                // Top bar panah kembali
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
                        ),
                        tooltip: 'Kembali',
                        onPressed: _loading ? null : () => Navigator.pop(context),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 390),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF23233F) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2D2D4A) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Ilustrasi Ikon Kunci / Shield
                            Container(
                              width: 80,
                              height: 80,
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
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.lock_reset_rounded,
                                  color: Color(0xFF0053DB),
                                  size: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Judul
                            Text(
                              'Lupa Password',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Subtitle
                            Text(
                              'Masukkan email akun Anda. Kami akan mengirimkan 6 digit kode OTP untuk verifikasi reset password.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Input Email
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Email Address*',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF111827),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              style: TextStyle(
                                color: isDark ? const Color(0xFFEEF2FF) : const Color(0xFF111827),
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Masukkan email Anda',
                                hintStyle: TextStyle(
                                  color: isDark ? const Color(0xFF7A8599) : const Color(0xFF9CA3AF),
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  size: 20,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF2A2A4A) : Colors.white,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isDark ? const Color(0xFF3A3A5C) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0053DB),
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                              ),
                              onSubmitted: (_) => _handleSendOtp(),
                            ),

                            // Pesan Error jika ada
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFDC2626).withValues(alpha: 0.3),
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

                            const SizedBox(height: 20),

                            // Tombol Kirim Kode OTP
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _handleSendOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0053DB),
                                  disabledBackgroundColor: isDark
                                      ? const Color(0xFF2E2E55)
                                      : const Color(0xFFCBD5E1),
                                  foregroundColor: Colors.white,
                                  elevation: _loading ? 0 : 4,
                                  shadowColor: const Color(0xFF0053DB).withValues(alpha: 0.35),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Kirim Kode OTP',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Link kembali ke Login
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Ingat password? Kembali ke Login',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF0053DB),
                                ),
                              ),
                            ),
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
    );
  }
}

/// Halaman 2 Lupa Password: Form Password Baru setelah OTP terverifikasi
class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String otp;

  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.length < 6) {
      setState(() => _error = 'Password minimal 6 karakter');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _error = 'Konfirmasi password tidak cocok');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService.resetPassword(
        widget.email,
        widget.otp,
        newPass,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password berhasil diubah! Selamat datang kembali.'),
            backgroundColor: Color(0xFF0053DB),
          ),
        );

        // Masuk langsung ke HomePage
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else {
        setState(() {
          _error = res['message'] as String? ?? 'Gagal mengubah password.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Terjadi kesalahan. Silakan coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      body: Stack(
        children: [
          // Wave atas
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

          // Wave bawah
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
                        ),
                        tooltip: 'Kembali',
                        onPressed: _loading ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 390),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF23233F) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2D2D4A) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Ikon gembok sukses
                            Container(
                              width: 80,
                              height: 80,
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
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.shield_outlined,
                                  color: Color(0xFF0053DB),
                                  size: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Judul
                            Text(
                              'Password Baru',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),

                            Text(
                              'Buat password baru minimal 6 karakter untuk akun Anda.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Email pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF0F7FF),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF3A3A5C) : const Color(0xFFDBEAFE),
                                ),
                              ),
                              child: Text(
                                widget.email,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Field Password Baru
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Password Baru*',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF111827),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _newPasswordController,
                              obscureText: !_showNewPassword,
                              style: TextStyle(
                                color: isDark ? const Color(0xFFEEF2FF) : const Color(0xFF111827),
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Minimal 6 karakter',
                                hintStyle: TextStyle(
                                  color: isDark ? const Color(0xFF7A8599) : const Color(0xFF9CA3AF),
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  size: 20,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showNewPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  onPressed: () =>
                                      setState(() => _showNewPassword = !_showNewPassword),
                                ),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF2A2A4A) : Colors.white,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isDark ? const Color(0xFF3A3A5C) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0053DB),
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Field Konfirmasi Password
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Konfirmasi Password Baru*',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF111827),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: !_showConfirmPassword,
                              style: TextStyle(
                                color: isDark ? const Color(0xFFEEF2FF) : const Color(0xFF111827),
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ketik ulang password baru',
                                hintStyle: TextStyle(
                                  color: isDark ? const Color(0xFF7A8599) : const Color(0xFF9CA3AF),
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  size: 20,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  onPressed: () => setState(
                                      () => _showConfirmPassword = !_showConfirmPassword),
                                ),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF2A2A4A) : Colors.white,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isDark ? const Color(0xFF3A3A5C) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0053DB),
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                              ),
                              onSubmitted: (_) => _handleReset(),
                            ),

                            // Error jika ada
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFDC2626).withValues(alpha: 0.3),
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

                            const SizedBox(height: 20),

                            // Tombol Simpan & Masuk
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _handleReset,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0053DB),
                                  disabledBackgroundColor: isDark
                                      ? const Color(0xFF2E2E55)
                                      : const Color(0xFFCBD5E1),
                                  foregroundColor: Colors.white,
                                  elevation: _loading ? 0 : 4,
                                  shadowColor: const Color(0xFF0053DB).withValues(alpha: 0.35),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Simpan & Masuk',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                              ),
                            ),
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
    );
  }
}
