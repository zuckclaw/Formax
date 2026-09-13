// Dialog Lupa-Password 3 langkah (email → OTP → password baru).
// Dipindah verbatim dari `pages/login_page.dart` (Tahap 9b) tanpa perubahan
// apa pun: semua mutasi state dialog memakai setDialogState LOKAL dari
// StatefulBuilder (bukan setState State), sehingga tidak ada delegasi yang
// diperlukan. File ini adalah `part` dari library yang sama; call-site
// (tombol lupa password di build) tidak berubah.
part of '../login_page.dart';

extension _LoginForgotPassword on _LoginPageState {
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
}
