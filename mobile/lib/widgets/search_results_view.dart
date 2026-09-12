import 'package:flutter/material.dart';
import '../models/form_model.dart';
import '../models/form_template.dart';
import '../services/api_service.dart';
import '../pages/historypage.dart';
import '../pages/formmakerpage.dart';

class SearchResultsView extends StatelessWidget {
  final Map<String, dynamic> searchData;
  final VoidCallback onRefresh;

  const SearchResultsView({
    super.key,
    required this.searchData,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final List<dynamic> sysTemplatesRaw = searchData['system_templates'] ?? [];
    final List<dynamic> usrTemplatesRaw = searchData['user_templates'] ?? [];
    final List<dynamic> pubFormsRaw = searchData['published_forms'] ?? [];

    final systemTemplates = sysTemplatesRaw
        .map((e) => FormTemplate.fromJson(e))
        .toList();
    final userTemplates = usrTemplatesRaw
        .map((e) => FormTemplate.fromJson(e))
        .toList();
    final publishedForms = pubFormsRaw
        .map((e) => FormModel.fromJson(e))
        .toList();

    final hasTemplates = systemTemplates.isNotEmpty || userTemplates.isNotEmpty;
    final hasHistory = publishedForms.isNotEmpty;

    if (!hasTemplates && !hasHistory) {
      return _buildEmptyState(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTemplates) ...[
            Text(
              'Templates',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (systemTemplates.isNotEmpty) ...[
              ...systemTemplates.map(
                (t) => _buildTemplateResult(context, t, true),
              ),
            ],
            if (userTemplates.isNotEmpty) ...[
              ...userTemplates.map(
                (t) => _buildTemplateResult(context, t, false),
              ),
            ],
            const SizedBox(height: 24),
          ],
          if (hasHistory) ...[
            Text(
              'Published Forms / History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            ...publishedForms.map((f) => _buildFormResult(context, f)),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplateResult(
    BuildContext context,
    FormTemplate template,
    bool isBuiltIn,
  ) {
    return InkWell(
      onTap: () async {
        // FIX Bug 4 & 21: fetch full template dengan questions, lalu buka FormMakerPage
        FormTemplate fullTemplate = template;
        if (template.id != null) {
          final res = await ApiService.getTemplate(template.id!);
          if (res['success'] == true && res['data'] != null) {
            fullTemplate = FormTemplate.fromJson(res['data'] as Map);
          }
        }
        if (!context.mounted) return;
        final result = await Navigator.push<FormMakerResult>(
          context,
          MaterialPageRoute(
            builder: (_) => FormMakerPage(initialTemplate: fullTemplate),
          ),
        );
        if (result != null) {
          onRefresh();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isBuiltIn
                    ? const Color(0xFFF3F4F6)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isBuiltIn
                    ? Icons.dashboard_customize_outlined
                    : Icons.description_outlined,
                color: isBuiltIn
                    ? const Color(0xFF4B5563)
                    : const Color(0xFF1E40AF),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.plainTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isBuiltIn ? 'Template Bawaan' : 'Template Saya',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormResult(BuildContext context, FormModel form) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: AppBar(
                title: Text(
                  'Detail Form',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                elevation: 0.5,
              ),
              body: HistoryPage(highlightFormId: form.id),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.assignment_turned_in_outlined,
                color: Color(0xFF059669),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    form.plainTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${form.totalSubmissions} responden',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.search_off, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Tidak ada template atau form yang ditemukan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coba gunakan kata kunci pencarian yang lain.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
