import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../utils/quill_html.dart';

/// A polished rich text editor backed by an HTML string, using flutter_quill.
///
/// The [initialHtml] is parsed into a Quill document and [onChanged] emits the
/// current content as HTML (so it round-trips with the web builder, which
/// stores HTML).
///
/// Set [compact] to `true` for a slimmer toolbar that only exposes inline
/// formatting (bold, italic, underline, strikethrough, link). This is useful
/// for short fields such as option labels.
class RichTextField extends StatefulWidget {
  final String initialHtml;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final int? minLines;
  final int? maxLines;

  /// When `true`, shows a compact toolbar with only inline-formatting buttons.
  final bool compact;

  const RichTextField({
    super.key,
    this.initialHtml = '',
    required this.onChanged,
    this.hintText,
    this.minLines = 2,
    this.maxLines,
    this.compact = false,
  });

  @override
  State<RichTextField> createState() => _RichTextFieldState();
}

class _RichTextFieldState extends State<RichTextField> {
  late QuillController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _controller = QuillController(
      document: QuillHtml.documentFromHtml(widget.initialHtml),
      selection: const TextSelection.collapsed(offset: 0),
    );
    // Trigger rebuild hanya untuk update border color saat focus berubah
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    // Hanya satu listener untuk emit HTML agar tidak double emit
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
      // FIX Bug 8: bandingkan HTML penuh, bukan plain text — agar perubahan formatting terdeteksi
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

  QuillSimpleToolbarConfig _buildToolbarConfig() {
    if (widget.compact) {
      return const QuillSimpleToolbarConfig(
        showDividers: false,
        showFontFamily: false,
        showFontSize: false,
        showBoldButton: true,
        showItalicButton: true,
        showUnderLineButton: true,
        showStrikeThrough: false,
        showColorButton: false,
        showBackgroundColorButton: false,
        showClearFormat: false,
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
        showLink: true,
        showUndo: false,
        showRedo: false,
        showSearchButton: false,
        showSubscript: false,
        showSuperscript: false,
        showCodeBlock: false,
        showInlineCode: false,
        showIndent: false,
        showDirection: false,
      );
    }

    return const QuillSimpleToolbarConfig(
      showDividers: true,
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
      showLeftAlignment: true,
      showCenterAlignment: true,
      showRightAlignment: true,
      showJustifyAlignment: false,
      showHeaderStyle: true,
      showListNumbers: true,
      showListBullets: true,
      showListCheck: false,
      showQuote: false,
      showLink: true,
      showUndo: true,
      showRedo: true,
      showSearchButton: false,
      showSubscript: false,
      showSuperscript: false,
      showCodeBlock: false,
      showInlineCode: false,
      showIndent: false,
      showDirection: false,
    );
  }

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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );

    if (pickedFile == null || !mounted) return;

    setState(() => _isUploadingImage = true);

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
              content: Text(
                'Gambar disisipkan secara lokal (tanpa koneksi server).',
              ),
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
      if (mounted) setState(() => _isUploadingImage = false);
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
                            if (_isUploadingImage)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else
                              IconButton(
                                icon: const Icon(
                                  Icons.image_outlined,
                                  size: 20,
                                ),
                                tooltip: 'Tambah Gambar',
                                onPressed: _onPickImagePressed,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
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

class _QuillEditorImageEmbedBuilder extends EmbedBuilder {
  final QuillController controller;

  _QuillEditorImageEmbedBuilder(this.controller);

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final String imageSource = embedContext.node.value.data as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget imageWidget;
    if (imageSource.startsWith('http://') ||
        imageSource.startsWith('https://')) {
      imageWidget = Image.network(
        imageSource,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 160,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
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
      imageWidget = Image.network(
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageSource.startsWith('data:image')
                    ? Image.memory(base64Decode(imageSource.split(',').last))
                    : File(imageSource).existsSync()
                    ? Image.file(File(imageSource))
                    : Image.network(imageSource),
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
