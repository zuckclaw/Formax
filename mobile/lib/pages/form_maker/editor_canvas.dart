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
      child: PageHeaderCard(
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
    );
  }

  Widget _buildQuestionCard(
    FormPageModel page,
    QuestionData q,
    int index, {
    required Key key,
  }) {
    final isActive = widget.state.activeQuestionId == q.id;
    return QuestionCard(
      key: key,
      index: index,
      question: q,
      isActive: isActive,
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
