// lib/models/form_model.dart
// Model untuk data Form, Submission, dan Answer dari API backend.

class FormModel {
  final String id;
  final String title;
  final String description;
  final String slug;
  final String status;
  final DateTime createdAt;
  int totalSubmissions;

  FormModel({
    required this.id,
    required this.title,
    required this.description,
    required this.slug,
    required this.status,
    required this.createdAt,
    this.totalSubmissions = 0,
  });

  /// Plain text for compact list display — strips HTML tags so rich-text
  /// form titles (stored as HTML) never leak raw `<p>`/`<strong>` markup.
  String get plainTitle => _stripHtml(title);

  static String _stripHtml(String? html) {
    if (html == null || html.trim().isEmpty) return '';
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  factory FormModel.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json);
    return FormModel(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Tanpa Judul',
      description: map['description'] ?? '',
      slug: map['slug'] ?? '',
      status: map['status'] ?? 'draft',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at']) ?? DateTime.now()
          : DateTime.now(),
      totalSubmissions: map['total_submissions'] ?? 0,
    );
  }
}

class SubmissionModel {
  final String id;
  final String respondentName;
  final String respondentEmail;
  final DateTime? submittedAt; // null = masih dalam proses (belum dikirim)
  final bool isAutoSubmitted;
  final bool isCheated;
  final Map<String, AnswerModel> answersById; // questionId -> jawaban

  SubmissionModel({
    required this.id,
    required this.respondentName,
    required this.respondentEmail,
    this.submittedAt,
    this.isAutoSubmitted = false,
    this.isCheated = false,
    this.answersById = const {},
  });

  List<AnswerModel> get answers => answersById.values.toList();

  factory SubmissionModel.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json);
    final userRaw = map['user'];
    final user = userRaw is Map ? Map<String, dynamic>.from(userRaw) : null;
    final answersList = map['answers'] as List<dynamic>? ?? [];
    final answersById = <String, AnswerModel>{};
    for (final a in answersList) {
      if (a is! Map) continue;
      final ans = AnswerModel.fromJson(a);
      if (ans.questionId.isNotEmpty) answersById[ans.questionId] = ans;
    }

    return SubmissionModel(
      id: map['id'] ?? '',
      respondentName: user?['full_name'] ?? 'Anonim',
      respondentEmail: user?['email'] ?? '-',
      submittedAt: map['submitted_at'] != null
          ? DateTime.tryParse(map['submitted_at'])
          : null,
      isAutoSubmitted: map['is_auto_submitted'] ?? false,
      isCheated: map['is_cheated'] ?? false,
      answersById: answersById,
    );
  }
}

class AnswerModel {
  final String questionId;
  final String questionLabel;
  final String? answerText;
  final List<String>? answerOptions;
  final String? fileUrl;

  AnswerModel({
    required this.questionId,
    required this.questionLabel,
    this.answerText,
    this.answerOptions,
    this.fileUrl,
  });

  /// Teks jawaban untuk ditampilkan (HTML sudah dibersihkan).
  String get display {
    if (answerOptions != null && answerOptions!.isNotEmpty) {
      return answerOptions!.join(', ');
    }
    if (answerText != null && answerText!.isNotEmpty) return answerText!;
    if (fileUrl != null && fileUrl!.isNotEmpty) return fileUrl!;
    return '-';
  }

  factory AnswerModel.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json);
    final qRaw = map['question'];
    final question = qRaw is Map ? Map<String, dynamic>.from(qRaw) : null;
    final optionsRaw = map['answer_options'];
    return AnswerModel(
      questionId: map['question_id']?.toString() ?? '',
      questionLabel: _stripHtml(question?['label']?.toString() ?? 'Pertanyaan'),
      answerText: _stripHtml(map['answer_text']?.toString()),
      answerOptions: optionsRaw is List
          ? optionsRaw.map((e) => _stripHtml(e.toString())).toList()
          : null,
      fileUrl: map['file_url'] as String?,
    );
  }

  static String _stripHtml(String? html) {
    if (html == null || html.trim().isEmpty) return html ?? '';
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
