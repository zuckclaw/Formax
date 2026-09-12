// lib/models/activity_model.dart
// Model "Aktivitas Saya" — form yang pernah/sedang diisi user sebagai responden.
// Sumber: backend GET /submissions/me → List[MySubmissionOut]

class MyActivityModel {
  final String id; // submission id
  final String formId;
  final String formTitle;
  final String formSlug;
  final String? formBanner;
  final String? ownerName;
  final bool allowSeeResult;
  final bool revealAnswers;
  final DateTime startedAt;
  final DateTime? submittedAt; // null = masih dalam proses
  final bool isAutoSubmitted;
  final bool isCheated;
  final int answeredCount;
  final int totalQuestions;

  MyActivityModel({
    required this.id,
    required this.formId,
    required this.formTitle,
    required this.formSlug,
    this.formBanner,
    this.ownerName,
    this.allowSeeResult = false,
    this.revealAnswers = false,
    required this.startedAt,
    this.submittedAt,
    this.isAutoSubmitted = false,
    this.isCheated = false,
    this.answeredCount = 0,
    this.totalQuestions = 0,
  });

  bool get isCompleted => submittedAt != null;

  int get progressPercent => totalQuestions == 0
      ? 0
      : ((answeredCount / totalQuestions) * 100).round();

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

  factory MyActivityModel.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json);
    final formRaw = map['form'];
    final form = formRaw is Map
        ? <String, dynamic>{
            for (final e in formRaw.entries) e.key.toString(): e.value,
          }
        : const <String, dynamic>{};
    return MyActivityModel(
      id: map['id']?.toString() ?? '',
      formId: map['form_id']?.toString() ?? '',
      formTitle: _stripHtml(form['title']?.toString()),
      formSlug: form['slug']?.toString() ?? '',
      formBanner: form['banner_url']?.toString(),
      ownerName: form['owner_name']?.toString(),
      allowSeeResult: form['allow_see_result'] ?? false,
      revealAnswers: form['reveal_answers'] ?? false,
      startedAt: map['started_at'] != null
          ? (DateTime.tryParse(map['started_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      submittedAt: map['submitted_at'] != null
          ? DateTime.tryParse(map['submitted_at'].toString())
          : null,
      isAutoSubmitted: map['is_auto_submitted'] ?? false,
      isCheated: map['is_cheated'] ?? false,
      answeredCount: map['answered_count'] ?? 0,
      totalQuestions: map['total_questions'] ?? 0,
    );
  }
}

// Hasil submission milik responden — backend GET /submissions/{id}/result
class ActivityResultModel {
  final String formTitle;
  final int? scorePercent; // null = belum ada soal ber-kunci
  final int correctCount;
  final int totalGraded;
  final bool isCheated;
  final DateTime? submittedAt;
  final List<ActivityAnswerResult> answers;

  ActivityResultModel({
    required this.formTitle,
    this.scorePercent,
    this.correctCount = 0,
    this.totalGraded = 0,
    this.isCheated = false,
    this.submittedAt,
    this.answers = const [],
  });

  factory ActivityResultModel.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json);
    final answersList = map['answers'] as List<dynamic>? ?? [];
    return ActivityResultModel(
      formTitle: MyActivityModel._stripHtml(map['form_title']?.toString()),
      scorePercent: map['score_percent'] as int?,
      correctCount: map['correct_count'] ?? 0,
      totalGraded: map['total_graded'] ?? 0,
      isCheated: map['is_cheated'] ?? false,
      submittedAt: map['submitted_at'] != null
          ? DateTime.tryParse(map['submitted_at'].toString())
          : null,
      answers: answersList
          .whereType<Map>()
          .map((a) => ActivityAnswerResult.fromJson(a))
          .toList(),
    );
  }
}

class ActivityAnswerResult {
  final String label;
  final String? userAnswer;
  final bool? isCorrect;
  final String? correctAnswer;

  ActivityAnswerResult({
    required this.label,
    this.userAnswer,
    this.isCorrect,
    this.correctAnswer,
  });

  factory ActivityAnswerResult.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json);
    return ActivityAnswerResult(
      label: MyActivityModel._stripHtml(map['label']?.toString()),
      userAnswer: _clean(map['user_answer']?.toString()),
      isCorrect: map['is_correct'] as bool?,
      correctAnswer: _clean(map['correct_answer']?.toString()),
    );
  }

  static String _clean(String? html) => MyActivityModel._stripHtml(html);
}
