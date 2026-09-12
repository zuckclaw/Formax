import 'package:flutter/material.dart';
import '../../../models/question_model.dart';
import '../../../models/form_template.dart';

class FormPageModel {
  String id;
  String title;
  String description;
  List<QuestionData> questions;

  FormPageModel({
    String? id,
    this.title = '',
    this.description = '',
    List<QuestionData>? questions,
  }) : id = id ?? UniqueKey().toString(),
       questions = questions ?? [];

  FormPageModel clone() {
    return FormPageModel(
      id: UniqueKey().toString(),
      title: title,
      description: description,
      questions: questions.map((q) => q.clone()).toList(),
    );
  }
}

class FormBuilderState extends ChangeNotifier {
  String formTitle;
  String formDescription;
  String? bannerUrl; // URL banner form (opsional)
  List<FormPageModel> pages;

  // State for Editor
  String? activeQuestionId;
  String? activePageId;
  bool isSaving = false;

  FormBuilderState({
    this.formTitle = '',
    this.formDescription = '',
    this.bannerUrl,
    List<FormPageModel>? pages,
  }) : pages = pages ?? [FormPageModel()] {
    if (this.pages.isEmpty) {
      this.pages.add(FormPageModel());
    }
    // Always sync formTitle/formDescription with the first page
    if (formTitle.isNotEmpty) {
      this.pages[0].title = formTitle;
    }
    if (formDescription.isNotEmpty) {
      this.pages[0].description = formDescription;
    }
  }

  factory FormBuilderState.fromTemplate(FormTemplate template) {
    final state = FormBuilderState(
      formTitle: template.title,
      formDescription: template.subtitle,
      bannerUrl: template.bannerUrl,
      pages: [],
    );
    state.pages.clear(); // Clear the default page added by the constructor

    final questionsJson = template.questionsJson;
    if (questionsJson == null || questionsJson.isEmpty) {
      state.pages.add(
        FormPageModel(
          title: state.formTitle,
          description: state.formDescription,
          questions: [
            QuestionData(
              type: QuestionType.multipleChoice,
              options: [QuestionOptionData(label: 'Opsi 1')],
            ),
          ],
        ),
      );
      return state;
    }

    final normalizedQuestions =
        questionsJson
            .whereType<Map>()
            .map((q) => Map<String, dynamic>.from(q))
            .toList()
          ..sort(
            (a, b) => ((a['order_index'] as num?)?.toInt() ?? 0).compareTo(
              (b['order_index'] as num?)?.toInt() ?? 0,
            ),
          );

    FormPageModel currentPage = FormPageModel(
      title: state.formTitle,
      description: state.formDescription,
    );
    for (final q in normalizedQuestions) {
      final typeStr = q['type'] as String? ?? 'text';
      if (typeStr == 'page_break') {
        state.pages.add(currentPage);
        currentPage = FormPageModel(title: q['label'] ?? 'Bagian Baru');
        continue;
      }

      final QuestionType type = QuestionTypeExtension.fromApiValue(typeStr);

      final optionsList = (q['options'] as List<dynamic>?) ?? [];
      final normalizedOptions =
          optionsList
              .whereType<Map>()
              .map((opt) => Map<String, dynamic>.from(opt))
              .toList()
            ..sort(
              (a, b) => ((a['order_index'] as num?)?.toInt() ?? 0).compareTo(
                (b['order_index'] as num?)?.toInt() ?? 0,
              ),
            );
      final options = normalizedOptions.map((opt) {
        return QuestionOptionData(
          label: opt['label']?.toString() ?? 'Opsi',
          isOther: opt['is_other'] as bool? ?? false,
          isCorrect: opt['is_correct'] as bool? ?? false,
        );
      }).toList();

      // Extract settings if present — FIX: handle LinkedMap<dynamic,dynamic>
      final settingsRaw = q['settings'];
      final settings = settingsRaw is Map
          ? <String, dynamic>{
              for (final e in settingsRaw.entries) e.key.toString(): e.value,
            }
          : <String, dynamic>{};
      final imageUrl = settings['image_url'] as String?;
      final extraImageUrls =
          (settings['image_urls'] as List<dynamic>?)
              ?.whereType<String>()
              .where((u) => u.isNotEmpty)
              .toList() ??
          <String>[];
      final rowLabels =
          (settings['row_labels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      final scaleMin = (settings['scale_min'] as num?)?.toInt() ?? 1;
      final scaleMax = (settings['scale_max'] as num?)?.toInt() ?? 5;
      final minLabel = settings['min_label'] as String? ?? '';
      final maxLabel = settings['max_label'] as String? ?? '';
      final ratingCount = (settings['rating_count'] as num?)?.toInt() ?? 5;
      final ratingIcon = settings['rating_icon'] as String? ?? 'star';
      final allowedFileTypes =
          (settings['allowed_file_types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      final maxFileSizeMB =
          (settings['max_file_size_mb'] as num?)?.toInt() ?? 10;
      final maxFileCount = (settings['max_file_count'] as num?)?.toInt() ?? 1;
      final points = (settings['points'] as num?)?.toInt() ?? 1;

      currentPage.questions.add(
        QuestionData(
          type: type,
          label: q['label']?.toString() ?? 'Pertanyaan',
          description:
              q['placeholder']?.toString() ??
              q['description']?.toString() ??
              '',
          isRequired: q['is_required'] as bool? ?? false,
          options: options,
          imageUrl: imageUrl,
          extraImageUrls: extraImageUrls,
          rowLabels: rowLabels,
          scaleMin: scaleMin,
          scaleMax: scaleMax,
          minLabel: minLabel,
          maxLabel: maxLabel,
          ratingCount: ratingCount,
          ratingIcon: ratingIcon,
          allowedFileTypes: allowedFileTypes,
          maxFileSizeMB: maxFileSizeMB,
          maxFileCount: maxFileCount,
          points: points,
        ),
      );
    }

    state.pages.add(currentPage);

    // Ensure at least one question
    if (state.pages.first.questions.isEmpty) {
      state.pages.first.questions.add(
        QuestionData(
          type: QuestionType.multipleChoice,
          options: [QuestionOptionData(label: 'Opsi 1')],
        ),
      );
    }

    return state;
  }

  // Muat draft form dari backend (GET /forms/{id}) — memakai loader yang sama
  // dengan template karena bentuk questions JSON-nya identik.
  factory FormBuilderState.fromForm(Map<String, dynamic> formJson) {
    final questionsRaw = formJson['questions'];
    final state = FormBuilderState.fromTemplate(
      FormTemplate(
        id: formJson['id']?.toString(),
        title: (formJson['title'] as String?) ?? '',
        subtitle: (formJson['description'] as String?) ?? '',
        bannerUrl: formJson['banner_url']?.toString(),
        questionsJson: questionsRaw is List ? questionsRaw : null,
      ),
    );
    return state;
  }

  // === Actions ===

  void updateFormTitle(String newTitle) {
    formTitle = newTitle;
    notifyListeners();
  }

  void updateFormDescription(String newDesc) {
    formDescription = newDesc;
    notifyListeners();
  }

  void setActiveQuestion(String? questionId, String? pageId) {
    activeQuestionId = questionId;
    activePageId = pageId;
    notifyListeners();
  }

  /// Pertanyaan yang sedang dipilih/diaktifkan (field yang sedang diedit).
  QuestionData? get activeQuestion {
    if (activeQuestionId == null || activePageId == null) return null;
    for (final page in pages) {
      if (page.id != activePageId) continue;
      for (final q in page.questions) {
        if (q.id == activeQuestionId) return q;
      }
    }
    return null;
  }

  /// Tempel gambar ke pertanyaan yang sedang aktif (perilaku seperti Google Form).
  /// Gambar pertama menjadi gambar utama; gambar berikutnya menumpuk di bawahnya
  /// (tidak pernah mengubah teks pertanyaan).
  /// Mengembalikan true jika berhasil ditempel ke pertanyaan aktif.
  bool attachImageToActiveQuestion(String imageUrl) {
    final q = activeQuestion;
    if (q == null) return false;
    q.addAttachedImage(imageUrl);
    notifyListeners();
    return true;
  }

  /// Hapus gambar yang ditempel pada sebuah pertanyaan.
  void removeImageFromQuestion(String questionId, String pageId) {
    for (final page in pages) {
      if (page.id != pageId) continue;
      for (final q in page.questions) {
        if (q.id == questionId) {
          q.imageUrl = null;
          q.extraImageUrls.clear();
          break;
        }
      }
    }
    notifyListeners();
  }

  void addQuestion(String pageId, QuestionType type, {String? imageUrl}) {
    final pageIndex = pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    final newQuestion = QuestionData(
      type: type,
      options: type.hasOptions ? [QuestionOptionData(label: 'Opsi 1')] : [],
      imageUrl: imageUrl,
    );

    // Insert after active question if possible
    int insertIndex = pages[pageIndex].questions.length;
    if (activeQuestionId != null) {
      final qIndex = pages[pageIndex].questions.indexWhere(
        (q) => q.id == activeQuestionId,
      );
      if (qIndex != -1) {
        insertIndex = qIndex + 1;
      }
    }

    pages[pageIndex].questions.insert(insertIndex, newQuestion);
    activeQuestionId = newQuestion.id;
    activePageId = pageId;
    notifyListeners();
  }

  void duplicateQuestion(String pageId, String questionId) {
    final pageIndex = pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    final qIndex = pages[pageIndex].questions.indexWhere(
      (q) => q.id == questionId,
    );
    if (qIndex == -1) return;

    final cloned = pages[pageIndex].questions[qIndex].clone();
    pages[pageIndex].questions.insert(qIndex + 1, cloned);
    activeQuestionId = cloned.id;
    notifyListeners();
  }

  void deleteQuestion(String pageId, String questionId) {
    final pageIndex = pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    pages[pageIndex].questions.removeWhere((q) => q.id == questionId);

    // Ensure at least one question exists in the page, else add a default one
    if (pages[pageIndex].questions.isEmpty) {
      pages[pageIndex].questions.add(
        QuestionData(
          type: QuestionType.multipleChoice,
          options: [QuestionOptionData(label: 'Opsi 1')],
        ),
      );
    }

    activeQuestionId = null;
    notifyListeners();
  }

  void addPage() {
    FormPageModel newPage = FormPageModel(title: 'Bagian Baru', questions: []);

    if (activePageId != null) {
      final activeIndex = pages.indexWhere((p) => p.id == activePageId);
      if (activeIndex != -1) {
        final currentPage = pages[activeIndex];

        // Split questions if there is an active question
        if (activeQuestionId != null) {
          final qIndex = currentPage.questions.indexWhere(
            (q) => q.id == activeQuestionId,
          );
          if (qIndex != -1) {
            // Move questions after qIndex to new page
            final questionsToMove = currentPage.questions.sublist(qIndex + 1);
            newPage.questions.addAll(questionsToMove);
            currentPage.questions.removeRange(
              qIndex + 1,
              currentPage.questions.length,
            );
          }
        }

        // Ensure new page has at least one question if it's empty after split
        if (newPage.questions.isEmpty) {
          newPage.questions.add(
            QuestionData(
              type: QuestionType.multipleChoice,
              options: [QuestionOptionData(label: 'Opsi 1')],
            ),
          );
        }

        pages.insert(activeIndex + 1, newPage);
      } else {
        pages.add(newPage);
      }
    } else {
      newPage.questions.add(
        QuestionData(
          type: QuestionType.multipleChoice,
          options: [QuestionOptionData(label: 'Opsi 1')],
        ),
      );
      pages.add(newPage);
    }

    activePageId = newPage.id;
    activeQuestionId = null;
    notifyListeners();
  }

  void deletePage(String pageId) {
    if (pages.length <= 1) return; // Cannot delete last page
    pages.removeWhere((p) => p.id == pageId);
    activePageId = null;
    activeQuestionId = null;
    notifyListeners();
  }

  void reorderQuestions(String pageId, int oldIndex, int newIndex) {
    final pageIndex = pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = pages[pageIndex].questions.removeAt(oldIndex);
    pages[pageIndex].questions.insert(newIndex, item);
    notifyListeners();
  }

  void triggerUpdate() {
    notifyListeners();
  }

  // Set semua soal yang bisa dijawab menjadi wajib diisi (bulk). Data structural
  // (halaman/teks/gambar/pemisah) tidak ikut ditandai wajib.
  void setAllQuestionsRequired(bool value) {
    for (final page in pages) {
      for (final q in page.questions) {
        if (q.type == QuestionType.pageBreak ||
            q.type == QuestionType.text ||
            q.type == QuestionType.image) {
          continue;
        }
        q.isRequired = value;
      }
    }
    notifyListeners();
  }

  // --- API Payload Builder ---
  // Solusi aman untuk schema DB saat ini: jangan kirim tipe page_break ke backend,
  // karena PostgreSQL enum questiontype belum mendukung nilai tersebut.
  // Halaman/section tetap dipelihara di UI lokal, tapi tidak disimpan ke DB agar
  // template/form bisa tersimpan tanpa error enum.
  List<Map<String, dynamic>> buildApiPayload() {
    final List<Map<String, dynamic>> result = [];
    int orderIndex = 0;
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final page = pages[pageIndex];
      if (pageIndex > 0) {
        result.add({
          'type': QuestionType.pageBreak.apiValue,
          'label': page.title,
          'placeholder': page.description,
          'is_required': false,
          'order_index': orderIndex++,
          'settings': {},
          'options': <Map<String, dynamic>>[],
        });
      }
      for (final q in page.questions) {
        final opts = q.options.asMap().entries.map((e) {
          return {
            'label': e.value.label,
            'value': e.value.label,
            'order_index': e.key,
            'is_correct': e.value.isCorrect,
            'is_other': e.value.isOther,
          };
        }).toList();

        // Build settings for question-specific config
        final settings = <String, dynamic>{};
        if (q.imageUrl != null && q.imageUrl!.isNotEmpty) {
          settings['image_url'] = q.imageUrl;
        }
        if (q.extraImageUrls.isNotEmpty) {
          settings['image_urls'] = q.extraImageUrls;
        }
        if (q.scaleMin != 1) {
          settings['scale_min'] = q.scaleMin;
        }
        if (q.scaleMax != 5) {
          settings['scale_max'] = q.scaleMax;
        }
        if (q.minLabel.isNotEmpty) {
          settings['min_label'] = q.minLabel;
        }
        if (q.maxLabel.isNotEmpty) {
          settings['max_label'] = q.maxLabel;
        }
        if (q.ratingCount != 5) {
          settings['rating_count'] = q.ratingCount;
        }
        if (q.ratingIcon != 'star') {
          settings['rating_icon'] = q.ratingIcon;
        }
        if (q.allowedFileTypes.isNotEmpty) {
          settings['allowed_file_types'] = q.allowedFileTypes;
        }
        if (q.maxFileSizeMB != 10) {
          settings['max_file_size_mb'] = q.maxFileSizeMB;
        }
        if (q.maxFileCount != 1) {
          settings['max_file_count'] = q.maxFileCount;
        }
        if (q.rowLabels.isNotEmpty) {
          settings['row_labels'] = q.rowLabels;
        }
        settings['points'] = q.points;

        result.add({
          'type': q.type.apiValue,
          'label': q.label,
          'placeholder': q.description,
          'is_required': q.isRequired,
          'order_index': orderIndex++,
          'settings': settings.isNotEmpty ? settings : {},
          'options': opts,
        });
      }
    }
    return result;
  }
}
