class FormTemplate {
  final String title;
  final String subtitle;
  final String? id;
  final String? bannerUrl;
  final List<dynamic>? questionsJson;
  final bool isSystem;

  FormTemplate({
    required this.title,
    required this.subtitle,
    this.id,
    this.bannerUrl,
    this.questionsJson,
    this.isSystem = false,
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
    return FormTemplate(
      id: map['id']?.toString(),
      title: (map['title'] as String?)?.trim().isEmpty == true
          ? 'Tanpa Judul'
          : (map['title'] ?? 'Tanpa Judul'),
      subtitle: map['description'] ?? '',
      bannerUrl: map['banner_url']?.toString(),
      questionsJson: qs,
      isSystem: map['is_system'] ?? false,
    );
  }
}
