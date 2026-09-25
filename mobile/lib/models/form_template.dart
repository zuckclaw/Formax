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
    this.startDate,
    this.endDate,
    this.theme,
  });

  /// Plain text untuk display list — strip HTML "<p>hhhh</p>" -> "hhhh"
  String get plainTitle => _stripHtml(title);
  String get plainSubtitle => _stripHtml(subtitle);

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
    
    // Parse datetime fields
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
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
      acceptResponses: map['accept_responses'] != false,
      allowSeeResult: map['allow_see_result'] == true,
      maxSubmissions: (map['max_submissions'] is int)
          ? map['max_submissions'] as int
          : int.tryParse('${map['max_submissions']}') ?? 0,
      requireFullscreen: map['require_fullscreen'] == true,
      revealAnswers: map['reveal_answers'] == true,
      shuffleQuestions: map['shuffle_questions'] == true,
      shuffleOptions: map['shuffle_options'] == true,
      startDate: parseDateTime(map['start_date']),
      endDate: parseDateTime(map['end_date']),
      theme: map['theme'],
    );
  }
}
