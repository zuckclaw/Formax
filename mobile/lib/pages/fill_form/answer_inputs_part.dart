// Bagian input jawaban FillFormPage — dispatcher, teks & pilihan ganda.
// Dipindah verbatim dari `lib/pages/fillformpage.dart` (Tahap 2a) tanpa
// perubahan logika. File ini adalah `part` dari library yang sama sehingga
// akses ke state privat (_answers, _updateAnswer, setState, ...) tetap sah.
// Call-site (`_buildAnswerInput(question)` di kartu soal) TIDAK berubah.
// Extension privat (nama underscore) agar tidak bocor ke public API.
part of '../fillformpage.dart';

extension _FillFormAnswerInputs on _FillFormPageState {
  Widget _buildAnswerInput(Question question) {
    switch (question.type) {
      case 'text':
      case 'paragraph':
        return _buildTextInput(question);
      case 'single_choice':
        return _buildSingleChoiceInput(question);
      case 'checkbox':
        return _buildCheckboxInput(question);
      case 'dropdown':
        return _buildDropdownInput(question);
      case 'date':
        return _buildDateInput(question);
      case 'time':
        return _buildTextInput(question);
      case 'linear_scale':
        return _buildLinearScaleInput(question);
      case 'rating':
        return _buildRatingInput(question);
      case 'multiple_choice_grid':
      case 'tick_box_grid':
        return _buildGridInput(question);
      case 'file_upload':
        return _buildFileUploadInput(question);
      case 'image':
        final urls = question.allImageUrls;
        if (urls.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final url in urls)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NgrokImage(
                    url,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        );
      case 'text_block':
        return const SizedBox.shrink();
      default:
        return _buildTextInput(question);
    }
  }

  // --- TEXT INPUT ---
  Widget _buildTextInput(Question question) {
    final ctrl = _getTextCtrl(question);
    return TextField(
      controller: ctrl,
      onChanged: (value) => _updateAnswer(question.id, text: value),
      maxLines: 3,
      decoration: InputDecoration(
        hintText: question.placeholder ?? 'Ketik jawaban di sini...',
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E66D0), width: 2),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  // --- SINGLE CHOICE (RADIO) ---
  // Render label opsi sebagai rich text bila berisi markup HTML (dari builder).
  Widget _renderOptionText(String label, TextStyle style) {
    return label.contains('<')
        ? RichTextView(html: label, textStyle: style)
        : Text(label, style: style);
  }

  TextEditingController _otherCtrl(String questionId) {
    return _otherCtrls.putIfAbsent(questionId, () => TextEditingController());
  }

  Widget _buildSingleChoiceInput(Question question) {
    final other = question.options.where((o) => o.isOther).firstOrNull;
    final selectedValue = _answers[question.id]?['answer_text'] ?? '';
    final otherActive = _otherSelected[question.id] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...question.options.map((option) {
          final isOther = option.isOther;
          final isSelected = isOther
              ? otherActive
              : selectedValue == option.label;
          return InkWell(
            onTap: () {
              if (isOther) {
                // setState tinggal di State (_selectSingleChoiceOther) —
                // extension dilarang memanggil protected member langsung.
                _selectSingleChoiceOther(question);
              } else {
                _otherSelected[question.id] = false;
                _otherCtrl(question.id).clear();
                _updateAnswer(question.id, text: option.label);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEFF6FF)
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1E66D0)
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected
                        ? const Color(0xFF1E66D0)
                        : const Color(0xFF9CA3AF),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _renderOptionText(
                      option.label,
                      TextStyle(
                        fontSize: 15,
                        color: isSelected
                            ? const Color(0xFF1E40AF)
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (other != null && otherActive)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child: TextField(
              key: ValueKey('other_${question.id}'),
              controller: _otherCtrl(question.id),
              onChanged: (v) => _updateAnswer(question.id, text: v),
              maxLines: 2,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tulis jawabanmu...',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFC7D2FE)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- CHECKBOX (MULTI CHOICE) ---
  Widget _buildCheckboxInput(Question question) {
    final other = question.options.where((o) => o.isOther).firstOrNull;
    final selectedOptions = List<String>.from(
      _answers[question.id]?['answer_options'] ?? [],
    );
    final otherActive = _otherSelected[question.id] ?? false;

    void commit(List<String> newOptions) {
      _updateAnswer(question.id, options: newOptions);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...question.options.map((option) {
          final isOther = option.isOther;
          final isSelected = isOther
              ? otherActive
              : selectedOptions.contains(option.label);
          return InkWell(
            onTap: () {
              final newOptions = List<String>.from(selectedOptions);
              if (isOther) {
                if (otherActive) {
                  _otherSelected[question.id] = false;
                  final last = _lastOtherText[question.id];
                  if (last != null && last.isNotEmpty) {
                    newOptions.remove(last);
                  }
                  _lastOtherText[question.id] = '';
                  _otherCtrl(question.id).clear();
                  commit(newOptions);
                } else {
                  _otherSelected[question.id] = true;
                  final text = _otherCtrl(question.id).text;
                  if (text.isNotEmpty && !newOptions.contains(text)) {
                    newOptions.add(text);
                  }
                  commit(newOptions);
                }
              } else {
                if (isSelected) {
                  newOptions.remove(option.label);
                } else {
                  newOptions.add(option.label);
                }
                commit(newOptions);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEFF6FF)
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1E66D0)
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: isSelected
                        ? const Color(0xFF1E66D0)
                        : const Color(0xFF9CA3AF),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _renderOptionText(
                      option.label,
                      TextStyle(
                        fontSize: 15,
                        color: isSelected
                            ? const Color(0xFF1E40AF)
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (other != null && otherActive)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child: TextField(
              key: ValueKey('other_${question.id}'),
              controller: _otherCtrl(question.id),
              onChanged: (v) {
                final newOptions = List<String>.from(
                  (_answers[question.id]?['answer_options'] as List? ?? [])
                      .where((x) => x.toString() != _lastOtherText[question.id])
                      .toList(),
                );
                if (v.isNotEmpty) newOptions.add(v);
                _lastOtherText[question.id] = v;
                commit(newOptions);
              },
              maxLines: 2,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tulis jawabanmu...',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFC7D2FE)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- DROPDOWN ---
  Widget _buildDropdownInput(Question question) {
    final selectedValue = _answers[question.id]?['answer_text'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedValue.isEmpty ? null : selectedValue,
          hint: const Text(
            'Pilih jawaban...',
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
          items: question.options.map((option) {
            return DropdownMenuItem<String>(
              value: option.label,
              child: _renderOptionText(
                option.label,
                const TextStyle(fontSize: 15, color: Color(0xFF374151)),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) _updateAnswer(question.id, text: value);
          },
        ),
      ),
    );
  }

  // --- DATE INPUT ---
  Widget _buildDateInput(Question question) {
    final currentDate = _answers[question.id]?['answer_text'] ?? '';

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF1E66D0),
                  brightness: Theme.of(context).brightness,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          final formatted =
              '${picked.day.toString().padLeft(2, '0')}/'
              '${picked.month.toString().padLeft(2, '0')}/'
              '${picked.year}';
          _updateAnswer(question.id, text: formatted);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              currentDate.isEmpty ? 'Pilih tanggal...' : currentDate,
              style: TextStyle(
                fontSize: 15,
                color: currentDate.isEmpty
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LINEAR SCALE ---
  Widget _buildLinearScaleInput(Question question) {
    final settings = question.settings;
    final min = settings['scale_min'] ?? 1;
    final max = settings['scale_max'] ?? 5;
    final current =
        int.tryParse(_answers[question.id]?['answer_text'] ?? '') ?? -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              settings['min_label'] ?? '$min',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              settings['max_label'] ?? '$max',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(max - min + 1, (i) {
            final val = min + i;
            final selected = current == val;
            return ChoiceChip(
              label: Text('$val'),
              selected: selected,
              onSelected: (_) => _updateAnswer(question.id, text: '$val'),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRatingInput(Question question) {
    final count = (question.settings['rating_count'] as int?) ?? 5;
    final current =
        int.tryParse(_answers[question.id]?['answer_text'] ?? '') ?? 0;
    return Row(
      children: List.generate(count, (i) {
        final filled = i < current;
        return IconButton(
          icon: Icon(
            filled ? Icons.star : Icons.star_border,
            color: const Color(0xFFF59E0B),
          ),
          onPressed: () => _updateAnswer(question.id, text: '${i + 1}'),
        );
      }),
    );
  }

  Widget _buildGridInput(Question question) {
    final rowLabels =
        (question.settings['row_labels'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['Baris 1'];
    final isRadio = question.type == 'multiple_choice_grid';
    final selectedSet =
        (_answers[question.id]?['answer_options'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toSet();
    // Setiap baris disimpan sebagai "NamaBaris => Opsi" supaya pilihan tiap baris
    // independen (FIX: sebelumnya radio membersihkan seluruh baris → data hilang).
    String keyFor(String row, String label) => '$row => $label';
    return Column(
      children: rowLabels.map((row) {
        final rowKeyPrefix = '$row => ';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _renderOptionText(
                row,
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: question.options.map((opt) {
                  final k = keyFor(row, opt.label);
                  final isSel = selectedSet.contains(k);
                  return FilterChip(
                    label: _renderOptionText(
                      opt.label,
                      const TextStyle(fontSize: 13),
                    ),
                    selected: isSel,
                    onSelected: (_) {
                      final cur = selectedSet.toList();
                      if (isRadio) {
                        cur.removeWhere((e) => e.startsWith(rowKeyPrefix));
                        cur.add(k);
                      } else {
                        if (cur.contains(k)) {
                          cur.remove(k);
                        } else {
                          cur.add(k);
                        }
                      }
                      _updateAnswer(question.id, text: null, options: cur);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- FILE UPLOAD ---
  Widget _buildFileUploadInput(Question question) {
    final fileUrl = _answers[question.id]?['file_url'] as String?;
    final uploading = _uploadingQids.contains(question.id);
    final colorScheme = Theme.of(context).colorScheme;

    final Widget content;
    if (uploading) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 10),
          Text(
            'Mengunggah file…',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      );
    } else if (fileUrl != null && fileUrl.isNotEmpty) {
      final fileName = _fileNameFromUrl(fileUrl);
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 40, color: Color(0xFF059669)),
          const SizedBox(height: 8),
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF065F46),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'File berhasil diunggah',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickAndUploadFile(question),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Ganti'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              TextButton.icon(
                onPressed: () => _removeFile(question),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Hapus'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            size: 40,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap untuk upload file',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            'Gambar, video, PDF, atau file lain',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return InkWell(
      onTap: uploading ? null : () => _pickAndUploadFile(question),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            style: BorderStyle.solid,
          ),
        ),
        child: content,
      ),
    );
  }

  Future<void> _pickAndUploadFile(Question question) async {
    // Mode pratinjau pemilik: jangan mengunggah file ke server.
    if (_isOwnerPreview) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Mode pratinjau pemilik — upload file dinonaktifkan.'),
          ),
        );
      }
      return;
    }
    if (_uploadingQids.contains(question.id)) return;

    final source = await showModalBottomSheet<_FileSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Text(
                    'Upload File',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, _FileSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, _FileSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Dokumen / File lain'),
              onTap: () => Navigator.pop(ctx, _FileSource.file),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    Uint8List? bytes;
    var fileName = '';
    try {
      if (source == _FileSource.gallery || source == _FileSource.camera) {
        final img = await ImagePicker().pickImage(
          source: source == _FileSource.gallery
              ? ImageSource.gallery
              : ImageSource.camera,
          maxWidth: 2048,
          imageQuality: 85,
        );
        if (img == null) return;
        bytes = await img.readAsBytes();
        fileName = img.name;
      } else {
        final picked = await FilePicker.pickFile();
        if (picked == null) return;
        bytes = await picked.readAsBytes();
        fileName = picked.name;
      }
      if (bytes.isEmpty) return;
      final upload = _performUpload(question, bytes, fileName);
      _pendingUploads[question.id] = upload;
      try {
        await upload;
      } finally {
        _pendingUploads.remove(question.id);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memilih file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performUpload(
    Question question,
    Uint8List bytes,
    String fileName,
  ) async {
    if (_submissionId == null) return;

    _markUploadStarted(question);
    try {
      final token = await ApiService.getToken();
      final respondentKey = await ApiService.getRespondentKey();

      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('${ApiService.baseUrl}/uploads'),
            )
            ..headers['X-Respondent-Key'] = respondentKey
            // Ngrok free mewajibkan header ini (konsisten dgn ApiService._uploadOnce);
            // tanpanya request bisa diarahkan ke halaman interstitial sehingga upload gagal.
            ..headers['ngrok-skip-browser-warning'] = 'true'
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: fileName,
                contentType: null,
              ),
            );
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response.body);
        final fileUrl = (data is Map) ? data['file_url'] : null;
        if (fileUrl is String && fileUrl.isNotEmpty) {
          final saved = await _applyUploadedFileUrl(question, fileUrl);
          if (!saved && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'File terunggah, tapi belum tersinkron — coba lagi',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File berhasil diunggah'),
                backgroundColor: Color(0xFF059669),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mengunggah file'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        final decoded = _safeJsonDecode(response.body);
        final detail = (decoded is Map && decoded['detail'] != null)
            ? decoded['detail'].toString()
            : 'Gagal mengunggah (${response.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal terhubung ke server'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _markUploadFinished(question.id);
    }
  }

  String _fileNameFromUrl(String url) {
    final segment = url.split('/').last;
    try {
      var name = Uri.decodeComponent(segment);
      if (name.length > 32) name = '${name.substring(0, 29)}...';
      return name;
    } catch (_) {
      return segment;
    }
  }
}
