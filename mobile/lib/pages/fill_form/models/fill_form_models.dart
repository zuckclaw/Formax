// Model data khusus halaman pengisian form (FillFormPage).
// Diekstrak verbatim dari `lib/pages/fillformpage.dart` (Tahap 1 kerapian)
// tanpa perubahan logika — hanya pindah lokasi agar file halaman ramping.

class QuestionOption {
  final String id;
  final String label;
  final String? value;
  final int orderIndex;
  final bool isCorrect;
  final bool isOther;

  QuestionOption({
    required this.id,
    required this.label,
    this.value,
    this.orderIndex = 0,
    this.isCorrect = false,
    this.isOther = false,
  });

  factory QuestionOption.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json);
    return QuestionOption(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      value: map['value']?.toString(),
      orderIndex: (map['order_index'] is int) ? map['order_index'] as int : int.tryParse('${map['order_index']}') ?? 0,
      isCorrect: map['is_correct'] == true,
      isOther: map['is_other'] == true,
    );
  }
}

class Question {
  final String id;
  final String
  type; // text, single_choice, checkbox, dropdown, date, file_upload
  final String label;
  final String? placeholder;
  final bool isRequired;
  final int orderIndex;
  final Map<String, dynamic> settings;
  final List<QuestionOption> options;

  Question({
    required this.id,
    required this.type,
    required this.label,
    this.placeholder,
    this.isRequired = false,
    this.orderIndex = 0,
    this.settings = const {},
    this.options = const [],
  });

  factory Question.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json);
    final settingsRaw = map['settings'];
    final settings = settingsRaw is Map
        ? Map<String, dynamic>.from(settingsRaw)
        : <String, dynamic>{};
    final optionsRaw = map['options'];
    final options = optionsRaw is List
        ? optionsRaw.whereType<Map>().map((o) => QuestionOption.fromJson(o)).toList()
        : <QuestionOption>[];

    return Question(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      label: map['label']?.toString() ?? '',
      placeholder: map['placeholder']?.toString(),
      isRequired: map['is_required'] == true,
      orderIndex: (map['order_index'] is int) ? map['order_index'] as int : int.tryParse('${map['order_index']}') ?? 0,
      settings: settings,
      options: options,
    );
  }

  String? get imageUrl => settings['image_url'] as String?;

  /// Semua URL gambar yang ditempel ke pertanyaan (urut: utama lalu tambahan),
  /// tanpa duplikat dan tanpa nilai kosong.
  List<String> get allImageUrls {
    final list = <String>[];
    final primary = settings['image_url'];
    if (primary is String && primary.isNotEmpty) list.add(primary);
    final extras = settings['image_urls'];
    if (extras is List) {
      for (final e in extras) {
        if (e is String && e.isNotEmpty && !list.contains(e)) list.add(e);
      }
    }
    return list;
  }
}

class FormData {
  final String id;
  final String title;
  final String? description;
  final String? bannerUrl;
  final String slug;
  final String? joinToken;
  final bool requireJoinToken;
  final bool requireFullscreen;
  final bool acceptResponses;
  final String? startDate;
  final String? endDate;
  // ID pemilik form (dari FormOut.owner_id) — dipakai untuk mode pratinjau
  // pemilik: pembuka yang adalah owner tidak di-join sebagai responden
  // sehingga tidak tercatat di Aktivitas Saya (parity perilaku web).
  final String? ownerId;
  final List<Question> questions;

  FormData({
    required this.id,
    required this.title,
    this.description,
    this.bannerUrl,
    required this.slug,
    this.joinToken,
    this.requireJoinToken = false,
    this.requireFullscreen = false,
    this.acceptResponses = true,
    this.startDate,
    this.endDate,
    this.ownerId,
    this.questions = const [],
  });

  factory FormData.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json);
    return FormData(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      bannerUrl: map['banner_url']?.toString(),
      slug: map['slug']?.toString() ?? '',
      // Backend PublicFormOut TIDAK kirim join_token (hanya flag require_join_token).
      // Tetap baca join_token bila ada (compat form lama), utama pakai flag bool.
      joinToken: map['join_token']?.toString(),
      requireJoinToken: map['require_join_token'] == true,
      requireFullscreen: map['require_fullscreen'] == true,
      acceptResponses: map['accept_responses'] == true || map['accept_responses'] == null,
      startDate: map['start_date']?.toString(),
      endDate: map['end_date']?.toString(),
      ownerId: map['owner_id']?.toString(),
      questions:
          (map['questions'] as List?)
              ?.whereType<Map>()
              .map((q) => Question.fromJson(q))
              .toList() ??
          [],
    );
  }
}
