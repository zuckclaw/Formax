import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../services/api_service.dart';
import '../utils/quill_html.dart';
import 'math_tex.dart';
import 'ngrok_image.dart';

/// Toolbar variants matching web:
/// - [full]: For form description / header cards (all options)
/// - [compact]: For question labels
/// - [option]: For answer choice options (inline, slimmer)
enum RichTextVariant {
  full,
  compact,
  option,
}

/// A polished rich text editor backed by an HTML string, using flutter_quill.
///
/// The [initialHtml] is parsed into a Quill document and [onChanged] emits the
/// current content as HTML (so it round-trips with the web builder, which
/// stores HTML).
class RichTextField extends StatefulWidget {
  final String initialHtml;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final int? minLines;
  final int? maxLines;

  /// The toolbar variant: full, compact, or option.
  final RichTextVariant variant;

  /// Backwards-compatible flag: if true, uses [RichTextVariant.compact].
  final bool? compact;

  const RichTextField({
    super.key,
    this.initialHtml = '',
    required this.onChanged,
    this.hintText,
    this.minLines = 2,
    this.maxLines,
    this.variant = RichTextVariant.full,
    this.compact,
  });

  @override
  State<RichTextField> createState() => _RichTextFieldState();
}

class _RichTextFieldState extends State<RichTextField> {
  late QuillController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  bool _isUploading = false;
  String _uploadProgressText = '';

  RichTextVariant get _effectiveVariant {
    if (widget.compact == true) return RichTextVariant.compact;
    return widget.variant;
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _controller = QuillController(
      document: QuillHtml.documentFromHtml(widget.initialHtml),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    void emitHtml() {
      final html = QuillHtml.documentToHtml(_controller.document);
      widget.onChanged(html);
    }

    _controller.addListener(emitHtml);
  }

  @override
  void didUpdateWidget(covariant RichTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialHtml != widget.initialHtml) {
      final newHtml = (widget.initialHtml).trim();
      final oldHtml = QuillHtml.documentToHtml(_controller.document).trim();
      if (newHtml != oldHtml) {
        final oldController = _controller;
        _controller = QuillController(
          document: QuillHtml.documentFromHtml(widget.initialHtml),
          selection: const TextSelection.collapsed(offset: 0),
        );
        void emitHtml2() {
          final html = QuillHtml.documentToHtml(_controller.document);
          widget.onChanged(html);
        }

        _controller.addListener(emitHtml2);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => oldController.dispose(),
        );
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Fonts & Sizes Parity with Web ──────────────────────────────────────────
  static const Map<String, String> _fontFamilyItems = {
    'Inter': 'inter',
    'Roboto': 'roboto',
    'Poppins': 'poppins',
    'Montserrat': 'montserrat',
    'Open Sans': 'open-sans',
    'Lato': 'lato',
    'Nunito': 'nunito',
    'Raleway': 'raleway',
    'Source Code Pro': 'source-code-pro',
    'Fira Code': 'fira-code',
    'JetBrains Mono': 'jetbrains-mono',
    'Arial': 'arial',
    'Georgia': 'georgia',
    'Times New Roman': 'times-new-roman',
    'Courier New': 'courier-new',
    'Comic Sans': 'comic-sans',
  };

  static const Map<String, String> _fontSizeItems = {
    '10': '10',
    '12': '12',
    '14': '14',
    '16': '16',
    '18': '18',
    '20': '20',
    '24': '24',
    '28': '28',
    '32': '32',
    '36': '36',
    '48': '48',
  };

  QuillSimpleToolbarConfig _buildToolbarConfig() {
    switch (_effectiveVariant) {
      case RichTextVariant.option:
        return const QuillSimpleToolbarConfig(
          showDividers: false,
          showFontFamily: false,
          showFontSize: true,
          showBoldButton: true,
          showItalicButton: true,
          showUnderLineButton: true,
          showStrikeThrough: true,
          showColorButton: true,
          showBackgroundColorButton: false,
          showClearFormat: true,
          showAlignmentButtons: false,
          showLeftAlignment: false,
          showCenterAlignment: false,
          showRightAlignment: false,
          showJustifyAlignment: false,
          showHeaderStyle: false,
          showListNumbers: false,
          showListBullets: false,
          showListCheck: false,
          showQuote: false,
          showLink: false,
          showUndo: false,
          showRedo: false,
          showSearchButton: false,
          showSubscript: false,
          showSuperscript: false,
          showCodeBlock: false,
          showInlineCode: false,
          showIndent: false,
          showDirection: false,
          buttonOptions: QuillSimpleToolbarButtonOptions(
            fontSize: QuillToolbarFontSizeButtonOptions(items: _fontSizeItems),
          ),
        );

      case RichTextVariant.compact:
        return const QuillSimpleToolbarConfig(
          showDividers: true,
          showFontFamily: true,
          showFontSize: true,
          showBoldButton: true,
          showItalicButton: true,
          showUnderLineButton: true,
          showStrikeThrough: true,
          showColorButton: true,
          showBackgroundColorButton: true,
          showClearFormat: true,
          showAlignmentButtons: false,
          showLeftAlignment: true,
          showCenterAlignment: true,
          showRightAlignment: true,
          showJustifyAlignment: true,
          showHeaderStyle: false,
          showListNumbers: true,
          showListBullets: true,
          showListCheck: false,
          showQuote: true,
          showLink: true,
          showUndo: true,
          showRedo: true,
          showSearchButton: false,
          showSubscript: false,
          showSuperscript: false,
          showCodeBlock: true,
          showInlineCode: false,
          showIndent: false,
          showDirection: false,
          buttonOptions: QuillSimpleToolbarButtonOptions(
            fontFamily: QuillToolbarFontFamilyButtonOptions(items: _fontFamilyItems),
            fontSize: QuillToolbarFontSizeButtonOptions(items: _fontSizeItems),
          ),
        );

      case RichTextVariant.full:
        return const QuillSimpleToolbarConfig(
          showDividers: true,
          showFontFamily: true,
          showFontSize: true,
          showBoldButton: true,
          showItalicButton: true,
          showUnderLineButton: true,
          showStrikeThrough: true,
          showColorButton: true,
          showBackgroundColorButton: true,
          showClearFormat: true,
          showAlignmentButtons: false,
          showLeftAlignment: true,
          showCenterAlignment: true,
          showRightAlignment: true,
          showJustifyAlignment: true,
          showHeaderStyle: true,
          showListNumbers: true,
          showListBullets: true,
          showListCheck: false,
          showQuote: true,
          showLink: true,
          showUndo: true,
          showRedo: true,
          showSearchButton: false,
          showSubscript: false,
          showSuperscript: false,
          showCodeBlock: true,
          showInlineCode: false,
          showIndent: false,
          showDirection: false,
          buttonOptions: QuillSimpleToolbarButtonOptions(
            fontFamily: QuillToolbarFontFamilyButtonOptions(items: _fontFamilyItems),
            fontSize: QuillToolbarFontSizeButtonOptions(items: _fontSizeItems),
          ),
        );
    }
  }

  // ── Embed Inserters ────────────────────────────────────────────────────────
  void _insertImageSource(String imageUrl) {
    if (!mounted) return;
    int index = _controller.selection.baseOffset;
    if (index < 0) {
      index = _controller.document.length - 1;
      if (index < 0) index = 0;
    }

    _controller.replaceText(index, 0, BlockEmbed.image(imageUrl), null);
    _controller.replaceText(index + 1, 0, '\n', null);
    _controller.updateSelection(
      TextSelection.collapsed(offset: index + 2),
      ChangeSource.local,
    );
  }

  void _insertVideoEmbed(String videoUrl) {
    if (!mounted) return;
    int index = _controller.selection.baseOffset;
    if (index < 0) {
      index = _controller.document.length - 1;
      if (index < 0) index = 0;
    }

    _controller.replaceText(index, 0, BlockEmbed.custom(CustomBlockEmbed('video', videoUrl)), null);
    _controller.replaceText(index + 1, 0, '\n', null);
    _controller.updateSelection(
      TextSelection.collapsed(offset: index + 2),
      ChangeSource.local,
    );
  }

  void _insertAudioEmbed(String audioUrl) {
    if (!mounted) return;
    int index = _controller.selection.baseOffset;
    if (index < 0) {
      index = _controller.document.length - 1;
      if (index < 0) index = 0;
    }

    _controller.replaceText(index, 0, BlockEmbed.custom(CustomBlockEmbed('audio', audioUrl)), null);
    _controller.replaceText(index + 1, 0, '\n', null);
    _controller.updateSelection(
      TextSelection.collapsed(offset: index + 2),
      ChangeSource.local,
    );
  }

  void _insertFormula(String formula, {bool isDisplay = false}) {
    if (!mounted) return;
    int index = _controller.selection.baseOffset;
    if (index < 0) {
      index = _controller.document.length - 1;
      if (index < 0) index = 0;
    }

    final blotType = isDisplay ? 'displayMath' : 'formula';
    _controller.replaceText(index, 0, BlockEmbed.custom(CustomBlockEmbed(blotType, formula)), null);
    if (isDisplay) {
      _controller.replaceText(index + 1, 0, '\n', null);
      _controller.updateSelection(
        TextSelection.collapsed(offset: index + 2),
        ChangeSource.local,
      );
    } else {
      _controller.updateSelection(
        TextSelection.collapsed(offset: index + 1),
        ChangeSource.local,
      );
    }
  }

  // ── Image Picker & Uploader ────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );

    if (pickedFile == null || !mounted) return;

    setState(() {
      _isUploading = true;
      _uploadProgressText = 'Mengunggah gambar...';
    });

    try {
      final uploadResult = await ApiService.uploadFile(pickedFile);
      if (!mounted) return;

      if (uploadResult['success'] == true && uploadResult['file_url'] != null) {
        final fileUrl = uploadResult['file_url'] as String;
        _insertImageSource(fileUrl);
      } else {
        // Fallback: sertakan gambar sebagai base64 Data URL jika server offline/error
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);
        final mimeType = pickedFile.path.endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        final dataUrl = 'data:$mimeType;base64,$base64String';
        _insertImageSource(dataUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gambar disisipkan secara lokal.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[RichTextField] Gagal upload gambar: $e');
      if (mounted) {
        try {
          final bytes = await pickedFile.readAsBytes();
          final base64String = base64Encode(bytes);
          final dataUrl = 'data:image/jpeg;base64,$base64String';
          _insertImageSource(dataUrl);
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showImageUrlDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sisipkan Link Gambar'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/gambar.png',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                _insertImageSource(url);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Sisipkan'),
          ),
        ],
      ),
    );
  }

  void _onPickImagePressed() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF23233F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF2563EB),
                  ),
                  title: const Text('Galeri Foto'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF2563EB),
                  ),
                  title: const Text('Kamera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.link_outlined,
                    color: Color(0xFF2563EB),
                  ),
                  title: const Text('Link Gambar (URL)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showImageUrlDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Video Link Dialog (YouTube / Vimeo / Drive / MP4) ──────────────────────
  void _showVideoDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.smart_display_outlined, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Sisipkan Video'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mendukung link YouTube, Vimeo, Google Drive, atau link langsung MP4:',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'https://www.youtube.com/watch?v=...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                _insertVideoEmbed(url);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Sisipkan Video'),
          ),
        ],
      ),
    );
  }

  // ── Audio Upload & Link Dialog ─────────────────────────────────────────────
  Future<void> _pickAudioFile() async {
    try {
      final file = await FilePicker.pickFile();
      if (file == null || !mounted) return;
      final path = file.path;
      if (path == null) return;

      setState(() {
        _isUploading = true;
        _uploadProgressText = 'Mengunggah audio...';
      });

      final uploadResult = await ApiService.uploadFile(XFile(path));
      if (!mounted) return;

      if (uploadResult['success'] == true && uploadResult['file_url'] != null) {
        _insertAudioEmbed(uploadResult['file_url'] as String);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal upload audio: ${uploadResult['message'] ?? 'Error'}',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[RichTextField] Gagal pick audio: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAudioDialog() {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF23233F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.audio_file_outlined, color: Color(0xFF2563EB)),
                title: const Text('Unggah Berkas Audio'),
                subtitle: const Text('Pilih file MP3, WAV, M4A dari perangkat'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAudioFile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_outlined, color: Color(0xFF2563EB)),
                title: const Text('Link Audio (URL)'),
                subtitle: const Text('Masukkan link audio eksternal langsung'),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Sisipkan Link Audio'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'https://example.com/audio.mp3',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.url,
                        autofocus: true,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          onPressed: () {
                            final url = controller.text.trim();
                            if (url.isNotEmpty) _insertAudioEmbed(url);
                            Navigator.pop(dCtx);
                          },
                          child: const Text('Sisipkan'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Math Presets — SAMA PERSIS dengan web MathPicker.jsx ───────────────────
  static const List<Map<String, dynamic>> _mathCategories = [
    {
      'category': 'Umum',
      'items': [
        {'label': 'Pecahan', 'latex': r'\frac{a}{b}', 'symbol': 'a/b'},
        {'label': 'Pecahan kompleks', 'latex': r'\frac{\frac{a}{b}}{c}', 'symbol': '(a/b)/c'},
        {'label': 'Akar kuadrat', 'latex': r'\sqrt{x}', 'symbol': '√x'},
        {'label': 'Akar pangkat-n', 'latex': r'\sqrt[n]{x}', 'symbol': 'ⁿ√x'},
        {'label': 'Pangkat', 'latex': r'x^{n}', 'symbol': 'xⁿ'},
        {'label': 'Subscript', 'latex': r'x_{i}', 'symbol': 'xᵢ'},
        {'label': 'Pangkat+sub', 'latex': r'x_{i}^{n}', 'symbol': 'xᵢⁿ'},
        {'label': 'Plus-minus', 'latex': r'x \pm y', 'symbol': 'x ± y'},
        {'label': 'Kali silang', 'latex': r'x \times y', 'symbol': 'x × y'},
        {'label': 'Bagi (÷)', 'latex': r'x \div y', 'symbol': 'x ÷ y'},
        {'label': 'Titik tengah', 'latex': r'x \cdot y', 'symbol': 'x · y'},
      ],
    },
    {
      'category': 'Operasi Besar',
      'items': [
        {'label': 'Jumlah (∑)', 'latex': r'\sum_{i=1}^{n} x_i', 'symbol': '∑'},
        {'label': 'Produk (∏)', 'latex': r'\prod_{i=1}^{n} x_i', 'symbol': '∏'},
        {'label': 'Integral', 'latex': r'\int_{a}^{b} f(x)\,dx', 'symbol': '∫'},
        {'label': 'Integral lipat', 'latex': r'\iint_{D} f(x,y)\,dx\,dy', 'symbol': '∬'},
        {'label': 'Limit', 'latex': r'\lim_{x \to \infty} f(x)', 'symbol': 'lim'},
        {'label': 'Turunan', 'latex': r'\frac{dy}{dx}', 'symbol': 'dy/dx'},
        {'label': 'Integral tentu besar', 'latex': r'\int\limits_{0}^{\infty} e^{-x^2} dx', 'symbol': '∫₀^∞'},
        {'label': 'Union', 'latex': r'A \cup B', 'symbol': '∪'},
        {'label': 'Intersection', 'latex': r'A \cap B', 'symbol': '∩'},
      ],
    },
    {
      'category': 'Relasi & Logika',
      'items': [
        {'label': 'Sama dengan', 'latex': 'a = b', 'symbol': '='},
        {'label': 'Tidak sama', 'latex': r'a \neq b', 'symbol': '≠'},
        {'label': 'Kurang-lebih', 'latex': r'a \approx b', 'symbol': '≈'},
        {'label': 'Identik', 'latex': r'a \equiv b', 'symbol': '≡'},
        {'label': 'Sebanding', 'latex': r'a \propto b', 'symbol': '∝'},
        {'label': 'Lebih kecil', 'latex': 'a < b', 'symbol': '<'},
        {'label': 'Lebih besar', 'latex': 'a > b', 'symbol': '>'},
        {'label': '≤', 'latex': r'a \leq b', 'symbol': '≤'},
        {'label': '≥', 'latex': r'a \geq b', 'symbol': '≥'},
        {'label': 'Implikasi', 'latex': r'p \Rightarrow q', 'symbol': '⇒'},
        {'label': 'Ekuivalen', 'latex': r'p \Leftrightarrow q', 'symbol': '⇔'},
        {'label': 'Elemen', 'latex': r'x \in A', 'symbol': '∈'},
        {'label': 'Bukan elemen', 'latex': r'x \notin A', 'symbol': '∉'},
        {'label': 'Subset', 'latex': r'A \subset B', 'symbol': '⊂'},
        {'label': 'For all', 'latex': r'\forall x', 'symbol': '∀'},
        {'label': 'Exists', 'latex': r'\exists x', 'symbol': '∃'},
      ],
    },
    {
      'category': 'Fungsi & Trigonometri',
      'items': [
        {'label': 'Sin', 'latex': r'\sin x', 'symbol': 'sin'},
        {'label': 'Cos', 'latex': r'\cos x', 'symbol': 'cos'},
        {'label': 'Tan', 'latex': r'\tan x', 'symbol': 'tan'},
        {'label': 'Log', 'latex': r'\log_{a} b', 'symbol': 'log'},
        {'label': 'Ln', 'latex': r'\ln x', 'symbol': 'ln'},
        {'label': 'Exp', 'latex': r'e^{x}', 'symbol': 'eˣ'},
        {'label': 'Min', 'latex': r'\min(a,b)', 'symbol': 'min'},
        {'label': 'Max', 'latex': r'\max(a,b)', 'symbol': 'max'},
      ],
    },
    {
      'category': 'Yunani',
      'items': [
        {'label': 'Alpha', 'latex': r'\alpha', 'symbol': 'α'},
        {'label': 'Beta', 'latex': r'\beta', 'symbol': 'β'},
        {'label': 'Gamma', 'latex': r'\gamma', 'symbol': 'γ'},
        {'label': 'Delta', 'latex': r'\delta', 'symbol': 'δ'},
        {'label': 'Epsilon', 'latex': r'\epsilon', 'symbol': 'ε'},
        {'label': 'Theta', 'latex': r'\theta', 'symbol': 'θ'},
        {'label': 'Lambda', 'latex': r'\lambda', 'symbol': 'λ'},
        {'label': 'Mu', 'latex': r'\mu', 'symbol': 'μ'},
        {'label': 'Pi', 'latex': r'\pi', 'symbol': 'π'},
        {'label': 'Sigma kecil', 'latex': r'\sigma', 'symbol': 'σ'},
        {'label': 'Sigma besar', 'latex': r'\Sigma', 'symbol': 'Σ'},
        {'label': 'Omega', 'latex': r'\omega', 'symbol': 'ω'},
        {'label': 'Omega besar', 'latex': r'\Omega', 'symbol': 'Ω'},
        {'label': 'Phi', 'latex': r'\phi', 'symbol': 'φ'},
        {'label': 'Psi', 'latex': r'\psi', 'symbol': 'ψ'},
      ],
    },
    {
      'category': 'Matriks & Vektor',
      'items': [
        {'label': 'Matriks 2×2', 'latex': r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}', 'symbol': '[2×2]'},
        {'label': 'Determinan', 'latex': r'\begin{vmatrix} a & b \\ c & d \end{vmatrix}', 'symbol': '|2×2|'},
        {'label': 'Vektor', 'latex': r'\vec{a}', 'symbol': 'a⃗'},
        {'label': 'Vektor tebal', 'latex': r'\mathbf{a}', 'symbol': '𝐚'},
        {'label': 'Norma', 'latex': r'\| \vec{a} \|', 'symbol': '‖a‖'},
        {'label': 'Transpos', 'latex': r'A^{T}', 'symbol': 'Aᵀ'},
        {'label': 'Sistem persamaan', 'latex': r'\begin{cases} x + y = 1 \\ x - y = 2 \end{cases}', 'symbol': '{..}'},
        {'label': 'Barisan', 'latex': r'a_n = a_{n-1} + d', 'symbol': 'aₙ'},
      ],
    },
    {
      'category': 'Lainnya',
      'items': [
        {'label': 'Tak hingga', 'latex': r'\infty', 'symbol': '∞'},
        {'label': 'Derajat', 'latex': r'90^{\circ}', 'symbol': '°'},
        {'label': 'Persen', 'latex': r'100\%', 'symbol': '%'},
        {'label': 'Akar + pecahan', 'latex': r'\sqrt{\frac{a}{b}}', 'symbol': '√(a/b)'},
        {'label': 'Kombinasi', 'latex': r'\binom{n}{k}', 'symbol': '(n k)'},
        {'label': 'Floor', 'latex': r'\left\lfloor x \right\rfloor', 'symbol': '⌊x⌋'},
        {'label': 'Ceil', 'latex': r'\left\lceil x \right\rceil', 'symbol': '⌈x⌉'},
        {'label': 'Panah kanan', 'latex': r'\rightarrow', 'symbol': '→'},
        {'label': 'Panah dua arah', 'latex': r'\leftrightarrow', 'symbol': '↔'},
      ],
    },
  ];

  // ── Math / Formula Dialog (parity web MathPicker: search, preset, edit,
  // custom LaTeX, display toggle, live KaTeX preview) ──
  void _showMathFormulaDialog() {
    final controller = TextEditingController(text: r'\frac{a}{b}');
    final searchController = TextEditingController();
    int selectedCategoryIndex = 0;
    bool isDisplayMode = false;
    String searchQuery = '';

    // Preset yang cocok dengan pencarian (parity web filteredPresets).
    List<Map<String, dynamic>> filteredItems() {
      if (searchQuery.trim().isEmpty) {
        return (_mathCategories[selectedCategoryIndex]['items'] as List)
            .cast<Map<String, dynamic>>();
      }
      final q = searchQuery.toLowerCase();
      final out = <Map<String, dynamic>>[];
      for (final cat in _mathCategories) {
        for (final it in (cat['items'] as List).cast<Map<String, dynamic>>()) {
          if ((it['label'] as String).toLowerCase().contains(q) ||
              (it['latex'] as String).toLowerCase().contains(q)) {
            out.add(it);
          }
        }
      }
      return out;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final currentItems = filteredItems();

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            title: const Row(
              children: [
                Text(
                  '𝑓𝑥',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF2563EB),
                  ),
                ),
                SizedBox(width: 8),
                Text('Sisipkan Rumus Matematika'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search (parity web MathPicker search)
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari rumus, simbol, Yunani...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  searchController.clear();
                                  setDlgState(() => searchQuery = '');
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) =>
                          setDlgState(() => searchQuery = v),
                    ),
                    const SizedBox(height: 10),

                    // Category selector chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_mathCategories.length, (idx) {
                          final catName = _mathCategories[idx]['category'] as String;
                          final isSel = idx == selectedCategoryIndex;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(catName, style: const TextStyle(fontSize: 12)),
                              selected: isSel,
                              selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: isSel
                                    ? const Color(0xFF2563EB)
                                    : (isDark ? const Color(0xFF94A3B8) : Colors.black87),
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (_) {
                                setDlgState(() => selectedCategoryIndex = idx);
                              },
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Preset buttons
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2D2D4A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: currentItems.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Tidak ada hasil untuk "$searchQuery"',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : Colors.black54,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: currentItems.map((item) {
                            final label = item['label'] as String;
                            final latex = item['latex'] as String;
                            final symbol = item['symbol'] as String? ?? label;

                            return Tooltip(
                              message: '$label: $latex',
                              child: InkWell(
                                onTap: () {
                                  controller.text = latex;
                                  controller.selection = TextSelection.collapsed(
                                    offset: controller.text.length,
                                  );
                                  setDlgState(() {});
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF23233F)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF2D2D4A)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        symbol,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Custom LaTeX textfield
                    const Text(
                      'Teks Rumus / Notasi LaTeX:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: r'Mis. \frac{a}{b} atau E = mc^2',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Display mode toggle (Block vs Inline)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Mode Display (Blok Tengah)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isDisplayMode
                            ? 'Rumus tampil sebagai baris tersendiri di tengah (block)'
                            : 'Rumus menyatu dengan aliran teks biasa (inline)',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: isDisplayMode,
                      activeTrackColor: const Color(0xFF2563EB),
                      onChanged: (val) {
                        setDlgState(() => isDisplayMode = val);
                      },
                    ),
                    const SizedBox(height: 4),

                    // Live KaTeX preview (parity web PreviewBox)
                    const Text(
                      'Pratinjau Live (KaTeX):',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF23233F)
                            : const Color(0xFFFAFBFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2D2D4A)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: controller.text.trim().isEmpty
                          ? Text(
                              'Pratinjau akan muncul di sini',
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: isDark
                                    ? const Color(0xFF7A8599)
                                    : const Color(0xFF94A3B8),
                              ),
                            )
                          : (isDisplayMode
                              ? MathTex.display(controller.text,
                                  isDark: isDark)
                              : MathTex.inline(controller.text,
                                  isDark: isDark)),
                    ),
                    if (controller.text.trim().isNotEmpty &&
                        !MathTex.looksValid(controller.text))
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0x2EEF4444)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFFECACA)),
                        ),
                        child: const Text(
                          'Rumus tidak valid — periksa kurung { }',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFEF4444)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  searchController.dispose();
                  Navigator.pop(ctx);
                },
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  final formula = controller.text.trim();
                  if (formula.isNotEmpty) {
                    _insertFormula(formula, isDisplay: isDisplayMode);
                  }
                  searchController.dispose();
                  Navigator.pop(ctx);
                },
                child: const Text('Sisipkan Rumus'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editorBg = isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF8F9FB);
    final editorBorder = isDark
        ? const Color(0xFF2D2D4A)
        : const Color(0xFFD1D5DB);
    final toolbarBg = isDark
        ? const Color(0xFF2E2E55)
        : const Color(0xFFF0F1F4);
    final dividerColor = isDark
        ? const Color(0xFF2D2D4A)
        : const Color(0xFFE5E7EB);
    final textColor = isDark
        ? const Color(0xFFEEF2FF)
        : const Color(0xFF1F2937);
    final hintColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF9CA3AF);

    final isEmpty = _controller.document.toPlainText().trim().isEmpty;
    final minH = (widget.minLines ?? 1) * 22.0 + 16;
    final maxH = (widget.maxLines ?? 6) * 22.0 + 16;
    final showMedia = _effectiveVariant != RichTextVariant.option;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Editor area ──
        Container(
          decoration: BoxDecoration(
            color: editorBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? const Color(0xFF2563EB)
                  : editorBorder,
              width: _focusNode.hasFocus ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Toolbar ──
              TapRegion(
                onTapOutside: (_) {},
                child: FocusScope(
                  canRequestFocus: false,
                  child: GestureDetector(
                    onTap: () {
                      if (!_focusNode.hasFocus) _focusNode.requestFocus();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      decoration: BoxDecoration(
                        color: toolbarBg,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(9),
                        ),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            QuillSimpleToolbar(
                              controller: _controller,
                              config: _buildToolbarConfig(),
                            ),
                            Container(
                              height: 20,
                              width: 1,
                              color: dividerColor,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                            if (_isUploading)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _uploadProgressText,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : Colors.black54),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              // 1. Image button
                              IconButton(
                                icon: const Icon(Icons.image_outlined, size: 20),
                                tooltip: 'Sisipkan Gambar',
                                onPressed: _onPickImagePressed,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                              // 2. Video button (full & compact)
                              if (showMedia)
                                IconButton(
                                  icon: const Icon(Icons.smart_display_outlined, size: 20),
                                  tooltip: 'Sisipkan Video',
                                  onPressed: _showVideoDialog,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              // 3. Audio button (full & compact)
                              if (showMedia)
                                IconButton(
                                  icon: const Icon(Icons.audiotrack_outlined, size: 20),
                                  tooltip: 'Sisipkan Audio',
                                  onPressed: _showAudioDialog,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              // 4. Formula / Math button (all variants)
                              IconButton(
                                icon: const Text(
                                  '𝑓𝑥',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: -0.5,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                tooltip: 'Sisipkan Rumus Matematika',
                                onPressed: _showMathFormulaDialog,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: dividerColor),

              // ── Quill editor area ──
              GestureDetector(
                onTap: () {
                  _focusNode.requestFocus();
                },
                child: Container(
                  constraints: BoxConstraints(minHeight: minH, maxHeight: maxH),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Stack(
                    children: [
                      if (isEmpty && widget.hintText != null)
                        Positioned(
                          top: 2,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Text(
                              widget.hintText!,
                              style: TextStyle(
                                color: hintColor,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      QuillEditor.basic(
                        controller: _controller,
                        focusNode: _focusNode,
                        scrollController: _scrollController,
                        config: QuillEditorConfig(
                          padding: EdgeInsets.zero,
                          expands: false,
                          autoFocus: false,
                          embedBuilders: [
                            _QuillEditorImageEmbedBuilder(_controller),
                            _QuillEditorCustomEmbedBuilder(_controller),
                          ],
                          customStyles: DefaultStyles(
                            sizeSmall: const TextStyle(fontSize: 12),
                            sizeLarge: const TextStyle(fontSize: 18),
                            sizeHuge: const TextStyle(fontSize: 24),
                            paragraph: DefaultTextBlockStyle(
                              TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: textColor,
                              ),
                              HorizontalSpacing.zero,
                              VerticalSpacing.zero,
                              VerticalSpacing.zero,
                              null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Embed Builder for Images ──────────────────────────────────────────────────
class _QuillEditorImageEmbedBuilder extends EmbedBuilder {
  final QuillController controller;

  _QuillEditorImageEmbedBuilder(this.controller);

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final rawSource = embedContext.node.value.data as String;
    final imageSource = QuillHtml.resolveImageUrl(rawSource);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Lebar pilihan user (parity web drag-handle resize), disimpan sebagai
    // atribut `width` pada op delta → terserialisasi ke HTML (style+attr).
    final widthAttr =
        embedContext.node.style.attributes['width']?.value?.toString();
    final displayWidth = _resolveDisplayWidth(context, widthAttr);

    final imageWidget = NgrokImage(
      imageSource,
      fit: BoxFit.contain,
    );

    Widget framed = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? const Color(0xFF2D2D4A)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: imageWidget,
      ),
    );
    if (displayWidth != null) {
      framed = Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(width: displayWidth, child: framed),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: GestureDetector(
        onTap: () {
          _showImageActionsDialog(context, embedContext, imageSource);
        },
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            framed,
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  tooltip: 'Hapus Gambar',
                  onPressed: () {
                    _deleteEmbedNode(embedContext);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEmbedNode(EmbedContext embedContext) {
    try {
      final offset = embedContext.node.offset;
      controller.document.delete(offset, 1);
    } catch (e) {
      debugPrint('[RichTextField] Gagal hapus gambar: $e');
    }
  }

  /// Terjemahkan atribut width ("50%" / "300px") ke lebar layar.
  /// null = penuh (perilaku lama).
  double? _resolveDisplayWidth(BuildContext context, String? widthAttr) {
    if (widthAttr == null) return null;
    final s = widthAttr.trim();
    if (s.endsWith('%')) {
      final pct = double.tryParse(s.substring(0, s.length - 1));
      if (pct == null || pct <= 0) return null;
      if (pct >= 100) return null;
      final full = MediaQuery.of(context).size.width - 32;
      return full * (pct / 100).clamp(0.1, 1.0);
    }
    final px = RegExp(r'(\d+(\.\d+)?)')
        .firstMatch(s)
        ?.group(1);
    final w = px == null ? null : double.tryParse(px);
    if (w == null || w <= 0) return null;
    final full = MediaQuery.of(context).size.width - 32;
    return w > full ? full : w;
  }

  /// Terapkan lebar gambar (parity web resize handle).
  /// Disimpan sebagai atribut `width` pada op delta → awet ke HTML.
  void _applyImageWidth(EmbedContext embedContext, String width) {
    try {
      final offset = embedContext.node.offset;
      controller.formatText(
        offset,
        1,
        Attribute.fromKeyValue('width', width),
      );
    } catch (e) {
      debugPrint('[RichTextField] Gagal ubah ukuran gambar: $e');
    }
  }

  void _showImageActionsDialog(
    BuildContext context,
    EmbedContext embedContext,
    String imageSource,
  ) {
    const sizes = [
      ('Penuh', '100%'),
      ('Besar', '75%'),
      ('Sedang', '50%'),
      ('Kecil', '25%'),
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.fullscreen, color: Color(0xFF2563EB)),
                title: const Text('Lihat Penuh'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFullImageDialog(context, imageSource);
                },
              ),
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Ukuran gambar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              for (final s in sizes)
                ListTile(
                  leading: const Icon(Icons.photo_size_select_large_outlined,
                      color: Color(0xFF2563EB)),
                  title: Text('${s.$1} (${s.$2})'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyImageWidth(embedContext, s.$2);
                  },
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Hapus Gambar',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteEmbedNode(embedContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFullImageDialog(BuildContext context, String imageSource) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: NgrokImage(imageSource, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Embed Builder for Video, Audio, & Formula ─────────────────────────
class _QuillEditorCustomEmbedBuilder extends EmbedBuilder {
  final QuillController controller;

  _QuillEditorCustomEmbedBuilder(this.controller);

  @override
  String get key => 'custom';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final customEmbed = embedContext.node.value as CustomBlockEmbed;
    final type = customEmbed.type;
    final data = customEmbed.data.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void deleteMe() {
      try {
        final offset = embedContext.node.offset;
        controller.document.delete(offset, 1);
      } catch (_) {}
    }

    if (type == 'video') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23233F) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3B82F6)),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_fill, color: Color(0xFF2563EB), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Video: $data',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.grey),
              onPressed: deleteMe,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ),
      );
    }

    if (type == 'audio') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23233F) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.audiotrack, color: Color(0xFF2563EB), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Audio: ${data.split('/').last}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.grey),
              onPressed: deleteMe,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ),
      );
    }

    if (type == 'formula') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D4A) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Render KaTeX asli (parity web quill formula blot).
            Flexible(
              child: MathTex.inline(data, isDark: isDark, fontSize: 14),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: deleteMe,
              child: const Icon(Icons.close, size: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (type == 'displayMath') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23233F) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF2D2D4A) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              // Render KaTeX asli (parity web DisplayMathBlot).
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: MathTex.display(data, isDark: isDark, fontSize: 15),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: deleteMe,
              child: const Icon(Icons.close, size: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Text('[$type: $data]');
  }
}
