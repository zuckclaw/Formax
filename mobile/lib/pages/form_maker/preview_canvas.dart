import 'package:flutter/material.dart';
import 'models/form_builder_state.dart';
import 'components/question_viewer.dart';
import '../../../widgets/rich_text_view.dart';

class PreviewCanvas extends StatelessWidget {
  final FormBuilderState state;

  const PreviewCanvas({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.pages.length,
        itemBuilder: (context, index) {
          final page = state.pages[index];
          return _buildPagePreview(context, page, index == 0);
        },
      ),
    );
  }

  Widget _buildPagePreview(
    BuildContext context,
    FormPageModel page,
    bool isFirst,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Page Header
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isFirst
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF8B5CF6),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FIX Bug 9: render HTML via RichTextView, bukan raw Text
                    RichTextView(
                      html: page.title.isEmpty
                          ? (isFirst ? state.formTitle : 'Bagian')
                          : page.title,
                      textStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    if (page.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      RichTextView(
                        html: page.description,
                        textStyle: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ] else if (isFirst && state.formDescription.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      RichTextView(
                        html: state.formDescription,
                        textStyle: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Questions
        ...page.questions.map(
          (q) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: QuestionViewer(question: q),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}
