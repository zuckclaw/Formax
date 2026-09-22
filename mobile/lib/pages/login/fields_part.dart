// Field builder LoginPage — label + textfield terang (light-locked).
// Dipindah verbatim dari `pages/login_page.dart` (Tahap 9c) tanpa perubahan
// logika. File ini adalah `part` dari library yang sama; call-site di build()
// tidak berubah.
// Penyesuaian wajib (aturan Dart, pelajaran Tahap 3a):
//  1. setState toggle eye-icon → helper State._toggleShowPassword (isi identik).
//  2. static const warna (_labelColor dkk. tetap di State karena dipakai
//     build() juga) → di-qualify _LoginPageState.xxx; tetap const-evaluable
//     sehingga `const TextStyle(...)` tidak berubah sifatnya.
// Extension privat (nama underscore) agar tidak bocor ke public API.
part of '../login_page.dart';

extension _LoginFields on _LoginPageState {
  Widget _buildLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            // Parity web: --text-body (#1e293b / #e2e8f0).
            color: isDark
                ? const Color(0xFFE2E8F0)
                : _LoginPageState._labelColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      autocorrect: autocorrect,
      obscureText: isPassword ? !_showPassword : obscureText,
      style: TextStyle(
        // Parity web: input terang di light, gelap #eef2ff di dark.
        color: isDark
            ? const Color(0xFFEEF2FF)
            : _LoginPageState._inputTextColor,
        fontSize: 14,
      ),
      cursorColor: const Color(0xFF1E66D0),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark
              ? const Color(0xFF7A8599)
              : _LoginPageState._hintColor,
          fontSize: 14,
        ),
        filled: true,
        fillColor:
            isDark ? const Color(0xFF2A2A4A) : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
              color: isDark
                  ? const Color(0xFF3A3A5C)
                  : const Color(0xFFE5E7EB)),
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
                onPressed: () => _toggleShowPassword(),
              )
            : null,
      ),
    );
  }
}
