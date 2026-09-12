import 'package:flutter/material.dart';
import '../../../models/question_model.dart';
import 'question_editor.dart';
import 'question_viewer.dart';

class QuestionCard extends StatelessWidget {
  final int index;
  final QuestionData question;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback? onAddImage;
  final ValueChanged<bool> onRequiredChanged;
  final VoidCallback onChanged;
  final VoidCallback onTypeChangeTap;

  const QuestionCard({
    super.key,
    required this.index,
    required this.question,
    required this.isActive,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
    this.onAddImage,
    required this.onRequiredChanged,
    required this.onChanged,
    required this.onTypeChangeTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final iconColor = isDark ? const Color(0xFF94A3B8) : Colors.black54;
    final textColor = isDark ? const Color(0xFFF8FAFC) : Colors.black87;
    final dividerColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE5E7EB);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? const Border(
                  left: BorderSide(color: Color(0xFF4F46E5), width: 4),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? 0.3 : (isActive ? 0.08 : 0.03),
              ),
              blurRadius: isActive ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            if (isActive)
              Center(
                child: ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: isDark ? const Color(0xFF64748B) : Colors.black26,
                    ),
                  ),
                ),
              ),
            isActive
                ? QuestionEditor(
                    question: question,
                    onChanged: onChanged,
                    onTypeChangeTap: onTypeChangeTap,
                  )
                : QuestionViewer(question: question),

            // Footer Toolbar when active
            if (isActive) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: dividerColor),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onAddImage != null &&
                      question.type != QuestionType.pageBreak)
                    IconButton(
                      icon: Icon(
                        Icons.image_outlined,
                        color: iconColor,
                        size: 22,
                      ),
                      tooltip: 'Tambahkan Gambar ke Pertanyaan Ini',
                      onPressed: onAddImage,
                    ),
                  IconButton(
                    icon: Icon(Icons.copy_outlined, color: iconColor, size: 22),
                    tooltip: 'Duplikat',
                    onPressed: onDuplicate,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: iconColor,
                      size: 22,
                    ),
                    tooltip: 'Hapus',
                    onPressed: onDelete,
                  ),
                  if (question.type != QuestionType.image &&
                      question.type != QuestionType.text) ...[
                    Container(
                      height: 24,
                      width: 1,
                      color: dividerColor,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    Text(
                      'Wajib',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Switch(
                      value: question.isRequired,
                      onChanged: onRequiredChanged,
                      activeThumbColor: const Color(0xFF4F46E5),
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert, color: iconColor),
                      onPressed: () {},
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
