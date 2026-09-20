import 'package:flutter/material.dart';
import 'models/form_builder_state.dart';
import 'components/question_card.dart';
import 'components/page_header_card.dart';
import '../../../models/question_model.dart';

class EditorCanvas extends StatefulWidget {
  final FormBuilderState state;
  final ValueChanged<QuestionData>? onAddImage;
  const EditorCanvas({super.key, required this.state, this.onAddImage});

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        widget.state.setActiveQuestion(null, null);
      },
      child: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        // ignore: deprecated_member_use
        onReorder: _handleReorder,
        itemCount: _getFlatItemCount(),
        itemBuilder: (context, index) {
          final item = _getFlatItem(index);
          if (item is _FlatPageHeader) {
            return _buildPageHeader(
              item.page,
              item.index,
              widget.state.pages.length,
              key: ValueKey('page_${item.page.id}'),
            );
          } else if (item is _FlatQuestion) {
            return _buildQuestionCard(
              item.page,
              item.question,
              index,
              key: ValueKey('q_${item.question.id}'),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  int _getFlatItemCount() {
    int count = 0;
    for (var page in widget.state.pages) {
      count++; // for the page header
      count += page.questions.length;
    }
    return count;
  }

  dynamic _getFlatItem(int index) {
    int currentIndex = 0;
    for (int i = 0; i < widget.state.pages.length; i++) {
      final page = widget.state.pages[i];
      if (currentIndex == index) return _FlatPageHeader(page, i);
      currentIndex++;

      for (var q in page.questions) {
        if (currentIndex == index) return _FlatQuestion(page, q);
        currentIndex++;
      }
    }
    return null;
  }

  Widget _buildPageHeader(
    FormPageModel page,
    int pageIndex,
    int totalPages, {
    required Key key,
  }) {
    final isActive =
        widget.state.activePageId == page.id &&
        widget.state.activeQuestionId == null;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeaderCard(
            page: page,
            isActive: isActive,
            sectionIndex: pageIndex + 1,
            totalSections: totalPages,
            onTap: () {
              widget.state.setActiveQuestion(null, page.id);
            },
            onChanged: () {
              if (pageIndex == 0) {
                // Sync the first page's title/description to the form's title/description
                widget.state.formTitle = page.title;
                widget.state.formDescription = page.description;
              }
              widget.state.triggerUpdate();
            },
            onDelete: () {
              widget.state.deletePage(page.id);
            },
          ),
          // Panel pilih banyak soal — tepat di bawah container
          // judul & deskripsi form (kartu header pertama).
          if (pageIndex == 0) _buildBulkPanel(),
        ],
      ),
    );
  }

  /// Panel bulk select di bawah judul/deskripsi form.
  Widget _buildBulkPanel() {
    final state = widget.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = state.pages.fold<int>(0, (n, p) => n + p.questions.length);
    final selected = state.selectedQuestionIds.length;
    final allSelected = total > 0 && selected >= total;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23233F) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: state.bulkSelectMode
              ? const Color(0xFFDC2626)
              : (isDark
                  ? const Color(0xFF2D2D4A)
                  : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: state.bulkSelectMode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: total == 0
                          ? null
                          : () {
                              if (allSelected) {
                                state.selectedQuestionIds.clear();
                                state.triggerUpdate();
                              } else {
                                state.selectAllQuestions();
                              }
                            },
                      icon: Icon(allSelected
                          ? Icons.deselect_outlined
                          : Icons.select_all_outlined),
                      label:
                          Text(allSelected ? 'Batal pilih' : 'Pilih semua'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Tutup mode seleksi',
                      onPressed: () => state.setBulkSelectMode(false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$selected dari $total dipilih',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFEEF2FF)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed:
                          selected == 0 ? null : () => _confirmBulkDelete(),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : InkWell(
              onTap: () => state.setBulkSelectMode(true),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.checklist_outlined,
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
                            'Pilih banyak soal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFEEF2FF)
                                  : Colors.black87,
                            ),
                          ),
                          Text(
                            'Centang beberapa soal lalu hapus sekaligus',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : Colors.black38,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Konfirmasi + eksekusi hapus massal soal terpilih.
  Future<void> _confirmBulkDelete() async {
    final count = widget.state.selectedQuestionIds.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 10),
            Text('Hapus Soal?'),
          ],
        ),
        content: Text(
          '$count soal akan dihapus permanen dan tidak bisa dikembalikan.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Ya, Hapus ($count)'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final removed = widget.state.deleteSelectedQuestions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$removed soal dihapus')),
    );
  }

  Widget _buildQuestionCard(
    FormPageModel page,
    QuestionData q,
    int index, {
    required Key key,
  }) {
    final bulkMode = widget.state.bulkSelectMode;
    final isActive = !bulkMode && widget.state.activeQuestionId == q.id;
    return QuestionCard(
      key: key,
      index: index,
      question: q,
      isActive: isActive,
      selectionMode: bulkMode,
      selected: widget.state.selectedQuestionIds.contains(q.id),
      onSelectionChanged: (_) {
        widget.state.toggleQuestionSelected(q.id);
      },
      onTap: () {
        widget.state.setActiveQuestion(q.id, page.id);
      },
      onDuplicate: () {
        widget.state.duplicateQuestion(page.id, q.id);
      },
      onDelete: () {
        widget.state.deleteQuestion(page.id, q.id);
      },
      onAddImage: widget.onAddImage == null
          ? null
          : () => widget.onAddImage!(q),
      onRequiredChanged: (val) {
        q.isRequired = val;
        widget.state.triggerUpdate();
      },
      onChanged: () {
        widget.state.triggerUpdate();
      },
      onTypeChangeTap: () {
        _showQuestionTypePicker(page.id, q);
      },
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    final flatList = List.generate(_getFlatItemCount(), (i) => _getFlatItem(i));
    final draggedItem = flatList[oldIndex];

    // Restrict moving page headers for simplicity in this implementation
    if (draggedItem is _FlatPageHeader) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pindah bagian belum didukung di mode ini.'),
        ),
      );
      return;
    }

    if (draggedItem is _FlatQuestion) {
      final oldPage = draggedItem.page;
      final q = draggedItem.question;

      // Determine new page based on newIndex
      FormPageModel? targetPage;
      for (int i = newIndex; i >= 0; i--) {
        if (flatList[i] is _FlatPageHeader) {
          targetPage = (flatList[i] as _FlatPageHeader).page;
          break;
        }
      }

      targetPage ??= widget.state.pages.first;

      setState(() {
        oldPage.questions.remove(q);

        // Calculate insert index in the new page
        int insertIdx = 0;
        int count = 0;
        for (var item in flatList) {
          if (count == newIndex) break;
          if (item is _FlatPageHeader && item.page == targetPage) {
            insertIdx = 0;
          } else if (item is _FlatQuestion && item.page == targetPage) {
            insertIdx++;
          }
          count++;
        }

        if (insertIdx > targetPage!.questions.length) {
          insertIdx = targetPage.questions.length;
        }

        targetPage.questions.insert(insertIdx, q);
        widget.state.triggerUpdate();
      });
    }
  }

  void _showQuestionTypePicker(String pageId, QuestionData q) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          // Parity web (QUESTION_TYPES): hanya 6 jenis soal. Section/ganti ke
          // tipe lain tidak ditawarkan — sama seperti dropdown tipe pada web.
          children: QuestionTypeExtension.pickerTypes.map((type) {
                return ListTile(
                  leading: Icon(_getIconForType(type), color: Colors.white),
                  title: Text(type.label),
                  onTap: () {
                    q.type = type;
                    if (type.hasOptions && q.options.isEmpty) {
                      q.options = [QuestionOptionData(label: 'Opsi 1')];
                    }
                    widget.state.triggerUpdate();
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
      default:
        return Icons.widgets;
    }
  }
}

class _FlatPageHeader {
  final FormPageModel page;
  final int index;
  _FlatPageHeader(this.page, this.index);
}

class _FlatQuestion {
  final FormPageModel page;
  final QuestionData question;
  _FlatQuestion(this.page, this.question);
}
