import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../models/question_model.dart';
import '../../../widgets/ngrok_image.dart';
import '../../../widgets/rich_text_field.dart';
import '../../../widgets/rich_text_view.dart';

class QuestionEditor extends StatefulWidget {
  final QuestionData question;
  final VoidCallback onChanged;
  final VoidCallback onTypeChangeTap;

  const QuestionEditor({
    super.key,
    required this.question,
    required this.onChanged,
    required this.onTypeChangeTap,
  });

  @override
  State<QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<QuestionEditor> {
  // Debounce controllers for linear scale configs etc.
  late TextEditingController _minLabelCtrl;
  late TextEditingController _maxLabelCtrl;
  late TextEditingController _pointsCtrl;

  @override
  void initState() {
    super.initState();
    _minLabelCtrl = TextEditingController(text: widget.question.minLabel);
    _maxLabelCtrl = TextEditingController(text: widget.question.maxLabel);
    _pointsCtrl = TextEditingController(text: '${widget.question.points}');
  }

  @override
  void didUpdateWidget(covariant QuestionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _minLabelCtrl.text = widget.question.minLabel;
      _maxLabelCtrl.text = widget.question.maxLabel;
      _pointsCtrl.text = '${widget.question.points}';
    }
  }

  @override
  void dispose() {
    _minLabelCtrl.dispose();
    _maxLabelCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FB);
    final typeBorder = isDark ? const Color(0xFF334155) : Colors.black12;
    final textColor = isDark ? const Color(0xFFF8FAFC) : Colors.black87;
    final iconColor = isDark ? const Color(0xFF94A3B8) : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag Handle
        Center(
          child: Icon(
            Icons.drag_handle,
            color: isDark ? const Color(0xFF64748B) : Colors.black26,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),

        // Title and Type Selector
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  RichTextField(
                    key: ValueKey('q_label_${widget.question.id}'),
                    initialHtml: widget.question.label,
                    onChanged: (html) {
                      widget.question.label = html;
                      widget.onChanged();
                    },
                    hintText: widget.question.type == QuestionType.text
                        ? 'Judul Teks'
                        : (widget.question.type == QuestionType.image
                              ? 'Caption (opsional)'
                              : 'Pertanyaan'),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            if (widget.question.type != QuestionType.image &&
                widget.question.type != QuestionType.text) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: widget.onTypeChangeTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: typeBg,
                      border: Border.all(color: typeBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.question.type.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, size: 20, color: iconColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // Poin per soal (bobot nilai) — hanya untuk jenis yang bisa dinilai
        if (_canGrade(widget.question)) ...[
          _buildPointsRow(widget.question, isDark),
          const SizedBox(height: 12),
        ],

        // Editor Body based on type
        _buildEditorBody(),
      ],
    );
  }

  bool _canGrade(QuestionData q) {
    return q.type != QuestionType.image &&
        q.type != QuestionType.text &&
        q.type != QuestionType.pageBreak &&
        q.type != QuestionType.fileUpload;
  }

  Widget _buildPointsRow(QuestionData q, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E6F0),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_outlined, size: 18, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Poin soal',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFFF8FAFC)
                    : const Color(0xFF374151),
              ),
            ),
          ),
          Container(
            width: 56,
            height: 34,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFD1D5DB),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _pointsCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                q.points = (parsed ?? 0).clamp(0, 99999);
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'poin',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorBody() {
    final q = widget.question;

    if (q.type == QuestionType.image) {
      final urls = q.allImageUrls;
      if (urls.isEmpty) {
        return const SizedBox(
          height: 100,
          child: Center(
            child: Icon(Icons.image, color: Colors.black26, size: 40),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          children: [
            for (final url in urls)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: (kIsWeb || url.startsWith('http'))
                    ? NgrokImage(url, fit: BoxFit.cover)
                    : Image.file(File(url), fit: BoxFit.cover),
              ),
          ],
        ),
      );
    }

    // Untuk tipe lain, tampilkan gambar yang ditempel di atas konten pertanyaan
    // (perilaku seperti Google Form) lengkap dengan tombol hapus.
    final attachedImage = _buildAttachedImage();
    final body = _buildTypeBody();
    if (attachedImage == null) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [attachedImage, const SizedBox(height: 12), body],
    );
  }

  /// Gambar-gambar yang ditempel ke pertanyaan non-gambar, ditumpuk vertikal
  /// dengan tombol hapus pada masing-masing gambar.
  Widget? _buildAttachedImage() {
    final q = widget.question;
    if (q.type == QuestionType.image) return null;
    final urls = q.allImageUrls;
    if (urls.isEmpty) return null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < urls.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (kIsWeb || urls[i].startsWith('http'))
                      ? NgrokImage(
                          urls[i],
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(urls[i]),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
                IconButton(
                  tooltip: 'Hapus gambar',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.black54 : Colors.white,
                    foregroundColor: isDark ? Colors.white : Colors.black54,
                    padding: const EdgeInsets.all(6),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    widget.question.removeAttachedImageAt(i);
                    widget.onChanged();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTypeBody() {
    final q = widget.question;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (q.type == QuestionType.linearScale) {
      return Column(
        children: [
          Row(
            children: [
              DropdownButton<int>(
                value: q.scaleMin,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('0')),
                  DropdownMenuItem(value: 1, child: Text('1')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    q.scaleMin = v;
                    widget.onChanged();
                  }
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('sampai'),
              ),
              DropdownButton<int>(
                value: q.scaleMax,
                items: List.generate(9, (index) => index + 2)
                    .map(
                      (val) =>
                          DropdownMenuItem(value: val, child: Text('$val')),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    q.scaleMax = v;
                    widget.onChanged();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${q.scaleMin}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _minLabelCtrl,
                  onChanged: (v) {
                    q.minLabel = v;
                    widget.onChanged();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Label opsional',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${q.scaleMax}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _maxLabelCtrl,
                  onChanged: (v) {
                    q.maxLabel = v;
                    widget.onChanged();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Label opsional',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (q.type == QuestionType.rating) {
      return Row(
        children: [
          const Text('Jumlah Tingkat: '),
          DropdownButton<int>(
            value: q.ratingCount,
            items: List.generate(8, (i) => i + 3)
                .map((val) => DropdownMenuItem(value: val, child: Text('$val')))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                q.ratingCount = v;
                widget.onChanged();
              }
            },
          ),
          const SizedBox(width: 24),
          const Text('Bentuk: '),
          DropdownButton<String>(
            value: q.ratingIcon,
            items: const [
              DropdownMenuItem(value: 'star', child: Text('Bintang')),
              DropdownMenuItem(value: 'heart', child: Text('Hati')),
            ],
            onChanged: (v) {
              if (v != null) {
                q.ratingIcon = v;
                widget.onChanged();
              }
            },
          ),
        ],
      );
    }

    if (!q.type.hasOptions) {
      return Container(); // No specific body editor needed for text/date/time
    }

    return Column(
      children: [
        ...q.options.asMap().entries.map((entry) {
          final i = entry.key;
          final opt = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Icon(
                    q.type == QuestionType.multipleChoice
                        ? Icons.radio_button_unchecked
                        : (q.type == QuestionType.checkboxes
                              ? Icons.check_box_outline_blank
                              : Icons.circle_outlined),
                    size: 20,
                    color: isDark ? const Color(0xFF64748B) : Colors.black26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: opt.isOther
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Text(
                            'Lainnya...',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        )
                      : TextFormField(
                          key: ValueKey('opt_${opt.id}'),
                          initialValue: RichTextView.stripHtml(opt.label),
                          onChanged: (value) {
                            opt.label = value;
                            widget.onChanged();
                          },
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          minLines: 1,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Opsi ${i + 1}',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : Colors.black38,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                        ),
                ),
                if (q.options.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : Colors.black38,
                      ),
                      onPressed: () {
                        q.options.removeAt(i);
                        widget.onChanged();
                      },
                    ),
                  ),
                if (!opt.isOther &&
                    (q.type == QuestionType.multipleChoice ||
                        q.type == QuestionType.checkboxes ||
                        q.type == QuestionType.dropdown))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Tooltip(
                      message: opt.isCorrect
                          ? 'Kunci Jawaban'
                          : 'Jadikan Kunci Jawaban',
                      child: InkWell(
                        key: ValueKey('is_correct_${opt.id}'),
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          _toggleCorrect(q, opt);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                opt.isCorrect
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 22,
                                color: opt.isCorrect
                                    ? const Color(0xFF4F46E5)
                                    : (isDark
                                          ? const Color(0xFF64748B)
                                          : Colors.black26),
                              ),
                              if (opt.isCorrect)
                                const Text(
                                  'Kunci',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF4F46E5),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        Row(
          children: [
            Icon(
              q.type == QuestionType.multipleChoice
                  ? Icons.radio_button_unchecked
                  : (q.type == QuestionType.checkboxes
                        ? Icons.check_box_outline_blank
                        : Icons.circle_outlined),
              size: 20,
              color: isDark ? const Color(0xFF64748B) : Colors.black26,
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () {
                q.options.add(
                  QuestionOptionData(label: 'Opsi ${q.options.length + 1}'),
                );
                widget.onChanged();
              },
              child: Text(
                'Tambah opsi',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
            if (!q.options.any((o) => o.isOther) &&
                (q.type == QuestionType.multipleChoice ||
                    q.type == QuestionType.checkboxes)) ...[
              Text(
                ' atau ',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : Colors.black54,
                  fontSize: 14,
                ),
              ),
              InkWell(
                onTap: () {
                  q.options.add(
                    QuestionOptionData(label: 'Lainnya', isOther: true),
                  );
                  widget.onChanged();
                },
                child: const Text(
                  'tambahkan "Lainnya"',
                  style: TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _toggleCorrect(QuestionData q, QuestionOptionData opt) {
    if (q.type == QuestionType.checkboxes) {
      opt.isCorrect = !opt.isCorrect;
    } else {
      final willBeCorrect = !opt.isCorrect;
      for (final o in q.options) {
        o.isCorrect = false;
      }
      opt.isCorrect = willBeCorrect;
    }
    widget.onChanged();
  }
}
