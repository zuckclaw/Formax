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

  void _pickImage() async {
    final picker = ImagePicker();
    // Kompres gambar saat diambil agar ukuran file kecil. Foto kamera full-res
    // (bisa 4-12 MB) gagal diupload lewat tunnel ngrok HTTPS dengan error
    // "HTTPS request failed, statusCode: 0" (koneksi putus saat tubuh request besar).
    // Pola ini sama dengan profil (avatar) & isi form (file upload) yang sudah bekerja.
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      final activePageId =
          _builderState.activePageId ?? _builderState.pages.first.id;

      // Upload the image to the backend first
      final uploadResult = await ApiService.uploadFile(pickedFile);
      if (uploadResult['success'] == true) {
        final fileUrl = uploadResult['file_url'] as String;

        // Perilaku seperti Google Form: jika ada pertanyaan yang sedang dipilih,
        // gambar ditempel ke pertanyaan itu (bukan membuat pertanyaan baru).
        final attached = _builderState.attachImageToActiveQuestion(fileUrl);
        if (!attached) {
          _builderState.addQuestion(
            activePageId,
            QuestionType.image,
            imageUrl: fileUrl,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal unggah gambar: ${uploadResult['message']}'),
            ),
          );
        }
      }
    }
  }

  /// Pilih & tempelkan gambar ke pertanyaan tertentu (perilaku Google Form,
  /// tombol gambar di toolbar pertanyaan aktif). Tidak membuat pertanyaan baru.
  /// Gambar kedua dst. menumpuk di bawah gambar pertama â€” teks pertanyaan
  /// (label) tidak pernah diubah.
  Future<void> _pickImageForQuestion(QuestionData q) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedFile == null) return;
    final uploadResult = await ApiService.uploadFile(pickedFile);
    if (!mounted) return;
    if (uploadResult['success'] == true) {
      final fileUrl = uploadResult['file_url'] as String;
      q.addAttachedImage(fileUrl);
      _builderState.triggerUpdate();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal unggah gambar: ${uploadResult['message']}'),
        ),
      );
    }
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    // Kompres banner sama seperti _pickImage agar upload via ngrok tidak putus
    // dengan error "HTTPS request failed, statusCode: 0".
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedFile == null) return;
    final uploadResult = await ApiService.uploadFile(pickedFile);
    if (!mounted) return;
    if (uploadResult['success'] == true) {
      final fileUrl = uploadResult['file_url'] as String;
      _applyBannerUrl(fileUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal unggah banner: ${uploadResult['message']}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
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
