import '../utils/form_settings_meta.dart';

class FormTemplate {
  final String title;
  final String subtitle;
  final String? id;
  final String? bannerUrl;
  final List<dynamic>? questionsJson;
  final bool isSystem;

  // Form settings dari template
  final bool acceptResponses;
  final bool allowSeeResult;
  final int maxSubmissions;
  final bool requireFullscreen;
  final bool revealAnswers;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final bool useJoinToken;
  final DateTime? startDate;
  final DateTime? endDate;
  final dynamic theme;

  FormTemplate({
    required this.title,
    required this.subtitle,
    this.id,
    this.bannerUrl,
    this.questionsJson,
    this.isSystem = false,
    this.acceptResponses = true,
    this.allowSeeResult = false,
    this.maxSubmissions = 0,
    this.requireFullscreen = false,
    this.revealAnswers = false,
    this.shuffleQuestions = false,
    this.shuffleOptions = false,
    this.useJoinToken = false,
    this.startDate,
    this.endDate,
    this.theme,
  });

  /// Plain text untuk display list — strip HTML "<p>hhhh</p>" -> "hhhh"
  String get plainTitle => _stripHtml(title);
  String get plainSubtitle =>
      _stripHtml(FormSettingsMeta.stripMetaHtml(subtitle));

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

  factory FormTemplate.fromJson(Map<dynamic, dynamic> json) {
    // FIX: handle LinkedMap<dynamic,dynamic> dari jsonDecode/database
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json);
    final rawQuestions = map['questions'];
    List<dynamic>? qs;
    if (rawQuestions is List) {
      // Pastikan tiap question juga jadi Map<String,dynamic> agar q['type'] aman
      qs = rawQuestions
          .map(
            (e) => e is Map
                ? <String, dynamic>{
                    for (final en in e.entries) en.key.toString(): en.value,
                  }
                : e,
          )
          .toList();
    }

    // Ekstrak pengaturan formulir secara menyeluruh (root + embedded meta di description & questions)
    final settings = FormSettingsMeta.extractSettings(
      root: map,
      descriptionHtml: map['description']?.toString(),
      questions: qs,
    );

    // Parse datetime fields
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    int parseMaxSubmissions(dynamic value) {
      if (value is int) return value;
      return int.tryParse('$value') ?? 0;
    }

    return FormTemplate(
      id: map['id']?.toString(),
      title: (map['title']?.toString() ?? '').trim().isEmpty
          ? 'Tanpa Judul'
          : map['title'].toString(),
      subtitle: map['description']?.toString() ?? '',
      bannerUrl: map['banner_url']?.toString(),
      questionsJson: qs,
      isSystem: map['is_system'] == true,
      acceptResponses: settings['accept_responses'] != false,
      allowSeeResult: settings['allow_see_result'] == true,
      maxSubmissions: parseMaxSubmissions(settings['max_submissions']),
      requireFullscreen: settings['require_fullscreen'] == true,
      revealAnswers: settings['reveal_answers'] == true,
      shuffleQuestions: settings['shuffle_questions'] == true,
      shuffleOptions: settings['shuffle_options'] == true,
      useJoinToken: settings['use_join_token'] == true,
      startDate: parseDateTime(settings['start_date']),
      endDate: parseDateTime(settings['end_date']),
      theme: settings['theme'] ?? map['theme'],
    );
  }
}
