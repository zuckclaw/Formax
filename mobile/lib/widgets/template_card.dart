import 'package:flutter/material.dart';
import '../models/form_template.dart';
import '../pages/formmakerpage.dart';
import 'rich_text_view.dart';

class TemplateCard extends StatelessWidget {
  final FormTemplate template;
  final bool isBuiltIn;
  final Future<void> Function(FormMakerResult? result)? onSaved;
  final bool handleNavigation;
  final Future<void> Function()? onDelete;

  const TemplateCard({
    super.key,
    required this.template,
    this.isBuiltIn = false,
    this.onSaved,
    this.handleNavigation = true,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final showDelete = onDelete != null && template.id != null && !isBuiltIn;
    return GestureDetector(
      onTap: handleNavigation
          ? () async {
              final result = await Navigator.push<FormMakerResult>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FormMakerPage(initialTemplate: template),
                ),
              );
              // FIX: reload di tombol back — back dari FormMaker (result null) tetap trigger reload di Home
              if (onSaved != null) {
                await onSaved!(result);
              }
            }
          : null,
      child: ClipRRect(
        // FIX: clip jadikan thumbnail & tombol hapus ikut membulat, jadi tombol
        // hapus "menyatu" dengan kartu (tidak terlihat terpisah).
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail Area — Expanded biar memenuhi sisa tinggi kartu
                  // (tinggi kartu diatur grid lewat mainAxisExtent, jadi tidak memanjang).
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCE4FB), // Light blue background
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.assignment_outlined,
                          size: 40,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                  // Text Area
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.plainTitle.isNotEmpty
                              ? template.plainTitle
                              : RichTextView.stripHtml(template.title),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          template.plainSubtitle.isNotEmpty
                              ? template.plainSubtitle
                              : (template.subtitle.isEmpty
                                    ? '${template.questionsJson?.length ?? 0} pertanyaan'
                                    : template.subtitle),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (showDelete)
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
