// lib/pages/profile_page.dart
// Halaman pengaturan profil pengguna. Mendukung edit username/foto profil,
// menampilkan email read-only, dan menyimpan perubahan ke backend.
// Seluruh warna memakai colorScheme tema agar tampil benar di mode terang & gelap.

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/ngrok_image.dart';
import '../theme/theme_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  String _email = '';
  String? _avatarUrl;
  File? _pickedImage;
  bool _isLoading = true;
  bool _isSaving = false;

  // Store originals to detect changes / cancel
  String _originalName = '';
  String? _originalAvatarUrl;

  // ─── Ganti Password (parity web ProfilePage) ─────────────────────────
  final TextEditingController _oldPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  bool _showOldPass = false;
  bool _showNewPass = false;
  bool _showConfirmPass = false;
  bool _passSaving = false;
  String? _passErr;
  String? _passMsg;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final result = await ApiService.getMe();
    if (result['success'] == true && mounted) {
      final data = result['data'];
      final profile = data is Map ? Map<String, dynamic>.from(data) : null;
      if (profile == null) {
        setState(() => _isLoading = false);
        return;
      }
      setState(() {
        _nameController.text = profile['full_name'] as String? ?? '';
        _email = profile['email'] as String? ?? '';
        _avatarUrl = profile['avatar_url'] as String?;
        _originalName = _nameController.text;
        _originalAvatarUrl = _avatarUrl;
        _isLoading = false;
      });
    } else if (mounted) {
      // Fail-closed: profil tak bisa dimuat karena sesi invalid (hook
      // global sudah menendang) atau backend mati → force logout.
      final m = Map<String, dynamic>.from(result);
      if (ApiService.isAuthInvalidResult(m) ||
          ApiService.isConnectionFailureResult(m)) {
        await ApiService.forceLogout();
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  /// Cek emoji (parity web containsEmoji): password tak boleh ber-emoji.
  static bool _containsEmoji(String s) {
    return RegExp(
      r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE00}-\u{FE0F}\u{1F000}-\u{1F2FF}]',
      unicode: true,
    ).hasMatch(s);
  }

  Future<void> _submitPasswordChange() async {
    final oldPass = _oldPassController.text;
    final newPass = _newPassController.text;
    final confirmPass = _confirmPassController.text;
    setState(() {
      _passSaving = true;
      _passErr = null;
      _passMsg = null;
    });
    // Validasi parity web handlePasswordSubmit.
    if (_containsEmoji(oldPass) || _containsEmoji(newPass)) {
      setState(() {
        _passErr = 'Password tidak boleh mengandung emoji';
        _passSaving = false;
      });
      return;
    }
    if (oldPass.isEmpty) {
      setState(() {
        _passErr = 'Masukkan password lama Anda';
        _passSaving = false;
      });
      return;
    }
    if (newPass.length < 6) {
      setState(() {
        _passErr = 'Password baru minimal 6 karakter';
        _passSaving = false;
      });
      return;
    }
    if (newPass != confirmPass) {
      setState(() {
        _passErr = 'Konfirmasi password baru tidak cocok dengan password baru';
        _passSaving = false;
      });
      return;
    }
    final res = await ApiService.changePassword(oldPass, newPass);
    if (!mounted) return;
    if (res['success'] == true) {
      _oldPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
      setState(() {
        _passMsg = 'Password Anda berhasil diperbarui!';
        _showOldPass = false;
        _showNewPass = false;
        _showConfirmPass = false;
        _passSaving = false;
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _passMsg = null);
      });
    } else {
      final m = Map<String, dynamic>.from(res);
      if (ApiService.isAuthInvalidResult(m) ||
          ApiService.isConnectionFailureResult(m)) {
        await ApiService.forceLogout();
        return;
      }
      setState(() {
        _passErr = res['message']?.toString() ?? 'Gagal mengubah password';
        _passSaving = false;
      });
    }
  }

  bool get _hasChanges {
    return _nameController.text != _originalName ||
        _pickedImage != null ||
        _avatarUrl != _originalAvatarUrl;
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildImagePickerSheet(),
    );
  }

  Widget _buildImagePickerSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Foto Profil',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          _sheetOption(
            icon: Icons.camera_alt_outlined,
            label: 'Ambil Foto',
            color: const Color(0xFF2563EB),
            onTap: () {
              Navigator.pop(context);
              _getImage(ImageSource.camera);
            },
          ),
          _sheetOption(
            icon: Icons.photo_library_outlined,
            label: 'Pilih dari Galeri',
            color: const Color(0xFF0891B2),
            onTap: () {
              Navigator.pop(context);
              _getImage(ImageSource.gallery);
            },
          ),
          if (_avatarUrl != null || _pickedImage != null)
            _sheetOption(
              icon: Icons.delete_outline,
              label: 'Hapus Foto Profil',
              color: const Color(0xFFDC2626),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _pickedImage = null;
                  _avatarUrl = null;
                });
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color == const Color(0xFFDC2626)
                    ? color
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      if (kIsWeb) {
        // On web, it might fall back to file picker if camera is blocked/unavailable.
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Kamera tidak didukung pada platform desktop, membuka file explorer...',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        source = ImageSource.gallery;
      }
    }

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        setState(() {
          _pickedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (mounted) setState(() => _isSaving = true);

    String? uploadedAvatarUrl;

    // Upload the new image first if picked
    if (_pickedImage != null) {
      final uploadResult = await ApiService.uploadFile(XFile(_pickedImage!.path));
      if (!mounted) return;
      if (uploadResult['success'] == true) {
        uploadedAvatarUrl = uploadResult['file_url'] as String;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upload foto: ${uploadResult['message']}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }
    }

    final payload = <String, dynamic>{};
    if (_nameController.text != _originalName) {
      payload['full_name'] = _nameController.text;
    }

    // If new image uploaded or avatar removed
    if (uploadedAvatarUrl != null) {
      payload['avatar_url'] = uploadedAvatarUrl;
    } else if (_avatarUrl == null && _originalAvatarUrl != null) {
      // Avatar was removed
      payload['avatar_url'] = '';
    }

    if (payload.isEmpty) {
      if (mounted) setState(() => _isSaving = false);
      if (mounted) Navigator.pop(context, true);
      return;
    }

    final result = await ApiService.updateProfile(payload);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui!'),
          backgroundColor: Color(0xFF059669),
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancel() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: cs.onSurface),
          onPressed: _cancel,
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outlineVariant),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Section Title
                  Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─── Profile Avatar ──────────────────────────────────────
                  _buildAvatarSection(),
                  const SizedBox(height: 40),

                  // ─── Username Field ──────────────────────────────────────
                  _buildField(
                    label: 'Username',
                    child: TextField(
                      controller: _nameController,
                      onChanged: (_) =>
                          setState(() {}), // trigger rebuild for hasChanges
                      style: TextStyle(fontSize: 15, color: cs.onSurface),
                      cursorColor: const Color(0xFF2563EB),
                      decoration: InputDecoration(
                        hintText: 'Nama kamu',
                        hintStyle: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── Email Field (Read-Only) ─────────────────────────────
                  _buildField(
                    label: 'Email',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(
                        _email,
                        style: TextStyle(
                          fontSize: 15,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ─── Keamanan / Ganti Password (parity web) ──────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Keamanan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPasswordSection(),
                  const SizedBox(height: 48),

                  // ─── Tampilan / Dark Mode ───────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tampilan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildThemeToggle(),
                  const SizedBox(height: 48),

                  // ─── Action Buttons ──────────────────────────────────────
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Stack(
          children: [
            // Avatar circle
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.outlineVariant, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(child: _buildAvatarImage()),
            ),
            // Camera badge
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _nameController.text.isNotEmpty ? _nameController.text : 'User',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _email,
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildAvatarImage() {
    if (_pickedImage != null) {
      if (kIsWeb) {
        return Image.network(
          _pickedImage!.path,
          width: 110,
          height: 110,
          fit: BoxFit.cover,
        );
      }
      return Image.file(
        _pickedImage!,
        width: 110,
        height: 110,
        fit: BoxFit.cover,
      );
    }
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      String url = _avatarUrl!;
      if (url.contains('localhost')) {
        final apiHost = Uri.parse(ApiService.baseUrl).host;
        url = url.replaceAll('localhost', apiHost);
      }
      return NgrokImage(
        url,
        width: 110,
        height: 110,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildDefaultAvatar(),
      );
    }
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 110,
      height: 110,
      color: const Color(0xFFEEF2FF),
      child: const Icon(Icons.person, size: 50, color: Color(0xFF9CA3AF)),
    );
  }

  Widget _buildPasswordSection() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ganti Kata Sandi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'Minimal 6 karakter, tanpa emoji',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _oldPassController,
            label: 'Password lama',
            show: _showOldPass,
            onToggle: () => setState(() => _showOldPass = !_showOldPass),
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            controller: _newPassController,
            label: 'Password baru',
            show: _showNewPass,
            onToggle: () => setState(() => _showNewPass = !_showNewPass),
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            controller: _confirmPassController,
            label: 'Konfirmasi password baru',
            show: _showConfirmPass,
            onToggle: () =>
                setState(() => _showConfirmPass = !_showConfirmPass),
          ),
          if (_passErr != null) ...[
            const SizedBox(height: 8),
            Text(
              _passErr!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ],
          if (_passMsg != null) ...[
            const SizedBox(height: 8),
            Text(
              _passMsg!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF059669)),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _passSaving ? null : _submitPasswordChange,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                disabledBackgroundColor: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _passSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Ubah Password',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool show,
    required VoidCallback onToggle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: !show,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(
            show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: cs.onSurfaceVariant,
          ),
          tooltip: show ? 'Sembunyikan password' : 'Tampilkan password',
          onPressed: onToggle,
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final dark = ThemeController.instance.isDark;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 22,
                color: dark
                    ? const Color(0xFF60A5FA)
                    : const Color(0xFF2563EB),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Gelap',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      dark
                          ? 'Aktif — tema gelap menyala'
                          : 'Nonaktif — tema terang',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: dark,
                activeThumbColor: Colors.white,
                onChanged: (_) => ThemeController.instance.toggle(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildActionButtons() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
              side: BorderSide(color: cs.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton(
            onPressed: (_isSaving || !_hasChanges) ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              disabledBackgroundColor: cs.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }
}
