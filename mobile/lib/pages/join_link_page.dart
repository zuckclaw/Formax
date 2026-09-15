import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'fillformpage.dart';

class JoinLinkPage extends StatefulWidget {
  const JoinLinkPage({super.key});

  @override
  State<JoinLinkPage> createState() => _JoinLinkPageState();
}

class _JoinLinkPageState extends State<JoinLinkPage> {
  final TextEditingController _linkController = TextEditingController();
  String? _errorText;
  bool _isLoading = false;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _validateAndEnter() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) {
      setState(() => _errorText = 'Silakan masukkan link');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    final result = await ApiService.validateFormLink(link);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['success'] == true) {
      final data = result['data'];
      final slug = ((data is Map) ? data['slug'] : null)?.toString() ?? '';
      if (slug.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FillFormPage(slug: slug)),
        );
      } else {
        setState(() => _errorText = 'Form tidak ditemukan');
      }
    } else {
      setState(() => _errorText = result['message'] ?? 'Link tidak valid');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB4C5D4),
        title: const Text(
          'Gabung dengan Link',
          style: TextStyle(color: Colors.white),
        ),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                labelText: 'Masukkan URL Form',
                hintText: 'https://example.com/form/slug',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _validateAndEnter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E66D0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Gabung',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
