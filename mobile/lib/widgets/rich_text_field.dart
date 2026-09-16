import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../services/api_service.dart';
import '../utils/quill_html.dart';
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
    'Arial': 'arial',
    'Georgia': 'georgia',
    'Times New Roman': 'times-new-roman',
    'Courier New': 'courier-new',
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

  void _insertFormula(String formula) {
    if (!mounted) return;
    int index = _controller.selection.baseOffset;
    if (index < 0) {
      index = _controller.document.length - 1;
      if (index < 0) index = 0;
    }

    _controller.replaceText(index, 0, BlockEmbed.custom(CustomBlockEmbed('formula', formula)), null);
    _controller.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      ChangeSource.local,
    );
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
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                    color: Color(0xFF4F46E5),
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
                    color: Color(0xFF4F46E5),
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
                    color: Color(0xFF4F46E5),
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
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                leading: const Icon(Icons.audio_file_outlined, color: Color(0xFF4F46E5)),
                title: const Text('Unggah Berkas Audio'),
                subtitle: const Text('Pilih file MP3, WAV, M4A dari perangkat'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAudioFile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_outlined, color: Color(0xFF4F46E5)),
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

  // ── Math / Formula Dialog (Symbols & LaTeX) ────────────────────────────────
  void _showMathFormulaDialog() {
    final controller = TextEditingController();
    const symbols = [
      '²', '³', '√', 'π', '∑', '∫', '±', '×', '÷',
      '∞', '≤', '≥', '≠', 'α', 'β', 'θ', 'λ', 'μ',
      'x/y', 'x_n', 'x^n',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Row(
              children: [
                Text('𝑓𝑥', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                SizedBox(width: 8),
                Text('Sisipkan Rumus Matematika'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Simbol cepat:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: symbols.map((sym) {
                      return InkWell(
                        onTap: () {
                          final cur = controller.text;
                          controller.text = '$cur$sym';
                          controller.selection = TextSelection.collapsed(offset: controller.text.length);
                          setDlgState(() {});
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(sym, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Teks Rumus / Notasi:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Mis. E = mc² atau \\sqrt{x}',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  final formula = controller.text.trim();
                  if (formula.isNotEmpty) {
                    _insertFormula(formula);
                  }
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
    final editorBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FB);
    final editorBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFD1D5DB);
    final toolbarBg = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF0F1F4);
    final dividerColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE5E7EB);
    final textColor = isDark
        ? const Color(0xFFF8FAFC)
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
                  ? const Color(0xFF4F46E5)
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
                                      style: const TextStyle(fontSize: 11, color: Colors.black54),
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
                                    color: Color(0xFF4F46E5),
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

    Widget imageWidget;
    if (imageSource.startsWith('http://') ||
        imageSource.startsWith('https://')) {
      imageWidget = NgrokImage(
        imageSource,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gagal memuat gambar ($imageSource)',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else if (imageSource.startsWith('data:image')) {
      try {
        final base64Data = imageSource.split(',').last;
        final bytes = base64Decode(base64Data);
        imageWidget = Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        imageWidget = const Icon(Icons.broken_image, color: Colors.red);
      }
    } else if (File(imageSource).existsSync()) {
      imageWidget = Image.file(File(imageSource), fit: BoxFit.contain);
    } else {
      imageWidget = NgrokImage(
        imageSource,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, color: Colors.red),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: imageWidget,
              ),
            ),
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

  void _showImageActionsDialog(
    BuildContext context,
    EmbedContext embedContext,
    String imageSource,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.fullscreen, color: Color(0xFF4F46E5)),
                title: const Text('Lihat Penuh'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFullImageDialog(context, imageSource);
                },
              ),
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
                child: imageSource.startsWith('data:image')
                    ? Image.memory(base64Decode(imageSource.split(',').last))
                    : File(imageSource).existsSync()
                    ? Image.file(File(imageSource))
                    : NgrokImage(imageSource),
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
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
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
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.audiotrack, color: Color(0xFF4F46E5), size: 22),
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
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
              ),
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

    return Text('[$type: $data]');
  }
}
