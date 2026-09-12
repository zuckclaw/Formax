import 'package:flutter/material.dart';
import '../models/form_builder_state.dart';
import '../../../widgets/rich_text_field.dart';
import '../../../widgets/rich_text_view.dart';

class PageHeaderCard extends StatelessWidget {
  final FormPageModel page;
  final bool isActive;
  final int sectionIndex;
  final int totalSections;
  final VoidCallback onTap;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  const PageHeaderCard({
    super.key,
    required this.page,
    required this.isActive,
    required this.sectionIndex,
    required this.totalSections,
    required this.onTap,
    required this.onChanged,
    this.onDelete,
  });

  bool _looksLikeHtml(String s) => s.contains('<');
  bool get _isFirstPage => sectionIndex == 1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : Colors.black87;
    final descColor = isDark ? const Color(0xFF94A3B8) : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isFirstPage)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF4F46E5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bagian $sectionIndex dari $totalSections',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (isActive && onDelete != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) {
                        if (value == 'delete') {
                          onDelete!();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Hapus bagian'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: _isFirstPage
                  ? BorderRadius.circular(8)
                  : const BorderRadius.vertical(bottom: Radius.circular(8)),
              border: isActive
                  ? const Border(
                      left: BorderSide(color: Color(0xFF4F46E5), width: 4),
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isFirstPage)
                  Container(
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4F46E5),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Title Field (field biasa, tanpa rich text editor) ---
                      isActive
                          ? TextFormField(
                              key: ValueKey('page_title_${page.id}'),
                              initialValue: RichTextView.stripHtml(page.title),
                              onChanged: (value) {
                                page.title = value;
                                onChanged();
                              },
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: titleColor,
                              ),
                              minLines: 1,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: _isFirstPage
                                    ? 'Judul Formulir'
                                    : 'Judul Bagian',
                                hintStyle: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : Colors.black26,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            )
                          : _buildTitleView(titleColor),
                      const SizedBox(height: 16),
                      // --- Description Field ---
                      isActive
                          ? RichTextField(
                              key: ValueKey('page_desc_${page.id}'),
                              initialHtml: page.description,
                              onChanged: (html) {
                                page.description = html;
                                onChanged();
                              },
                              hintText: 'Deskripsi',
                              minLines: 1,
                              maxLines: 3,
                            )
                          : _buildDescriptionView(descColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleView(Color textColor) {
    final displayText = page.title.isEmpty
        ? (_isFirstPage ? 'Judul Formulir' : 'Judul Bagian')
        : page.title;

    if (_looksLikeHtml(displayText)) {
      return RichTextView(
        html: displayText,
        textStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      );
    }
    return Text(
      displayText,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  Widget _buildDescriptionView(Color textColor) {
    if (page.description.isEmpty) return const SizedBox.shrink();

    if (_looksLikeHtml(page.description)) {
      return RichTextView(
        html: page.description,
        textStyle: TextStyle(fontSize: 15, color: textColor),
      );
    }
    return Text(
      page.description,
      style: TextStyle(fontSize: 15, color: textColor),
    );
  }
}
