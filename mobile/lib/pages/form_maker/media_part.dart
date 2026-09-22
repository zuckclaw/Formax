// Share, gambar & sheet FormMakerPage — dialog share, picker gambar/banner,
// terapkan wajib/opsional massal, bottom-sheet tambah soal + ikon tipenya.
// Dipindah verbatim dari `lib/pages/formmakerpage.dart` (Tahap 6d) tanpa
// perubahan logika. File ini adalah `part` dari library yang sama sehingga
// akses ke state privat tetap sah; call-site tidak berubah.
// Penyesuaian wajib: 1 situs setState (_pickBanner) didelegasikan ke helper
// State._applyBannerUrl (extension dilarang memanggil protected member
// langsung); urutan + isi statement identik.
// Extension privat (nama underscore) agar tidak bocor ke public API.
part of '../formmakerpage.dart';

extension _FormMakerMedia on _FormMakerPageState {
  void _showShareDialog(
    String link,
    String qrUrl,
    String formId,
    String title,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShareFormDialog(link: link, qrUrl: qrUrl),
    ).then((_) {
      if (mounted) {
        Navigator.pop(
          context,
          FormMakerResult(draftFormId: formId, draftFormTitle: title),
        );
      }
    });
  }

  Future<String?> _showImageSourcePicker({required String title}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = await showModalBottomSheet<String>(
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF2563EB)),
                  title: const Text('Galeri Foto'),
                  onTap: () => Navigator.pop(ctx, 'gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF2563EB)),
                  title: const Text('Kamera'),
                  onTap: () => Navigator.pop(ctx, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.link_outlined, color: Color(0xFF2563EB)),
                  title: const Text('Link Gambar (URL)'),
                  onTap: () => Navigator.pop(ctx, 'url'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return null;

    if (source == 'url') {
      final ctrl = TextEditingController();
      return showDialog<String>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Masukkan Link Gambar'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'https://example.com/gambar.png',
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
                final url = ctrl.text.trim();
                Navigator.pop(dCtx, url.isNotEmpty ? url : null);
              },
              child: const Text('Gunakan Gambar'),
            ),
          ],
        ),
      );
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedFile == null || !mounted) return null;

    final uploadResult = await ApiService.uploadFile(pickedFile);
    if (!mounted) return null;
    if (uploadResult['success'] == true && uploadResult['file_url'] != null) {
      return uploadResult['file_url'] as String;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal upload gambar: ${uploadResult['message'] ?? 'Error'}'),
        ),
      );
      return null;
    }
  }

  void _pickImage() async {
    try {
      final fileUrl = await _showImageSourcePicker(title: 'Tambah Gambar Soal');
      if (fileUrl == null || !mounted) return;

      final activePageId =
          _builderState.activePageId ?? _builderState.pages.first.id;

      final attached = _builderState.attachImageToActiveQuestion(fileUrl);
      if (!attached) {
        _builderState.addQuestion(
          activePageId,
          QuestionType.image,
          imageUrl: fileUrl,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar: $e')),
      );
    }
  }

  /// Pilih & tempelkan gambar ke pertanyaan tertentu (perilaku Google Form,
  /// tombol gambar di toolbar pertanyaan aktif). Tidak membuat pertanyaan baru.
  /// Gambar kedua dst. menumpuk di bawah gambar pertama — teks pertanyaan
  /// (label) tidak pernah diubah.
  Future<void> _pickImageForQuestion(QuestionData q) async {
    final fileUrl = await _showImageSourcePicker(title: 'Tempel Gambar ke Pertanyaan');
    if (fileUrl == null || !mounted) return;
    q.addAttachedImage(fileUrl);
    _builderState.triggerUpdate();
  }

  Future<void> _pickBanner() async {
    final fileUrl = await _showImageSourcePicker(title: 'Unggah Banner Formulir');
    if (fileUrl == null || !mounted) return;
    _applyBannerUrl(fileUrl);
  }

  void _applyRequiredToAll() {
    _builderState.setAllQuestionsRequired(true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua pertanyaan dijadikan wajib diisi'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    }
  }

  void _applyOptionalToAll() {
    _builderState.setAllQuestionsRequired(false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua pertanyaan dijadikan opsional')),
      );
    }
  }

  void _showAddQuestionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          // Parity web (QUESTION_TYPES): hanya 6 jenis soal + Section lewat
          // tombol "Tambah Bagian". Lihat QuestionTypeExtension.pickerTypes.
          children: QuestionTypeExtension.pickerTypes.map((type) {
                return ListTile(
                  leading: Icon(_getIconForType(type), color: _primaryColor),
                  title: Text(
                    type.label,
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    final activePageId =
                        _builderState.activePageId ??
                        _builderState.pages.first.id;
                    _builderState.addQuestion(activePageId, type);
                    Navigator.pop(context);
                  },
                );
              })
              .toList(),
        );
      },
    );
  }

  IconData _getIconForType(QuestionType type) {
    switch (type) {
      case QuestionType.shortAnswer:
        return Icons.short_text;
      case QuestionType.paragraph:
        return Icons.notes;
      case QuestionType.multipleChoice:
        return Icons.radio_button_checked;
      case QuestionType.checkboxes:
        return Icons.check_box;
      case QuestionType.dropdown:
        return Icons.arrow_drop_down_circle;
      case QuestionType.fileUpload:
        return Icons.cloud_upload;
      case QuestionType.linearScale:
        return Icons.linear_scale;
      case QuestionType.rating:
        return Icons.star;
      case QuestionType.date:
        return Icons.event;
      case QuestionType.time:
        return Icons.access_time;
      case QuestionType.image:
        return Icons.image_outlined;
      default:
        return Icons.widgets;
    }
  }
}
