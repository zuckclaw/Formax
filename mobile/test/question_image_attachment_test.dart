import 'package:flutter_test/flutter_test.dart';
import 'package:form4x/models/question_model.dart';
import 'package:form4x/pages/form_maker/models/form_builder_state.dart';
import 'package:form4x/pages/fillformpage.dart';

void main() {
  group('Question Image Attachment Tests', () {
    test(
      'attachImageToActiveQuestion stacks the second image without touching the label',
      () {
        final state = FormBuilderState(
          pages: [
            FormPageModel(
              questions: [
                QuestionData(
                  type: QuestionType.multipleChoice,
                  label: 'Question 1',
                  imageUrl: 'http://example.com/image1.jpg',
                ),
              ],
            ),
          ],
        );

        final question = state.pages.first.questions.first;
        state.setActiveQuestion(question.id, state.pages.first.id);

        // Attach second image
        final success = state.attachImageToActiveQuestion(
          'http://example.com/image2.jpg',
        );

        expect(success, isTrue);
        // First image remains the primary image
        expect(question.imageUrl, equals('http://example.com/image1.jpg'));
        // Second image is stacked separately in extraImageUrls
        expect(
          question.extraImageUrls,
          equals(['http://example.com/image2.jpg']),
        );
        // Question text must NOT be polluted with <img> html
        expect(question.label, equals('Question 1'));

        // Third image stacks too
        state.attachImageToActiveQuestion('http://example.com/image3.jpg');
        expect(question.extraImageUrls, hasLength(2));
        expect(
          question.allImageUrls,
          equals([
            'http://example.com/image1.jpg',
            'http://example.com/image2.jpg',
            'http://example.com/image3.jpg',
          ]),
        );
      },
    );

    test(
      'addAttachedImage assigns the first image as primary, later ones stack',
      () {
        final q = QuestionData(type: QuestionType.shortAnswer, label: 'Soal');
        q.addAttachedImage('http://example.com/a.jpg');
        expect(q.imageUrl, equals('http://example.com/a.jpg'));
        expect(q.extraImageUrls, isEmpty);

        q.addAttachedImage('http://example.com/b.jpg');
        q.addAttachedImage('http://example.com/c.jpg');
        expect(
          q.allImageUrls,
          equals([
            'http://example.com/a.jpg',
            'http://example.com/b.jpg',
            'http://example.com/c.jpg',
          ]),
        );
      },
    );

    test('removeAttachedImageAt promotes the next extra image to primary', () {
      final q = QuestionData(
        type: QuestionType.multipleChoice,
        label: 'Soal',
        imageUrl: 'http://example.com/a.jpg',
        extraImageUrls: [
          'http://example.com/b.jpg',
          'http://example.com/c.jpg',
        ],
      );

      q.removeAttachedImageAt(0);
      expect(q.imageUrl, equals('http://example.com/b.jpg'));
      expect(q.extraImageUrls, equals(['http://example.com/c.jpg']));

      q.removeAttachedImageAt(1);
      expect(q.imageUrl, equals('http://example.com/b.jpg'));
      expect(q.extraImageUrls, isEmpty);
      expect(q.allImageUrls, equals(['http://example.com/b.jpg']));
    });

    test('buildApiPayload persists image_urls alongside image_url', () {
      final state = FormBuilderState(
        pages: [
          FormPageModel(
            questions: [
              QuestionData(
                type: QuestionType.multipleChoice,
                label: 'Question 1',
                imageUrl: 'http://example.com/image1.jpg',
                extraImageUrls: ['http://example.com/image2.jpg'],
              ),
            ],
          ),
        ],
      );

      final payload = state.buildApiPayload();
      expect(payload, hasLength(1));
      expect(
        payload.first['settings']['image_url'],
        equals('http://example.com/image1.jpg'),
      );
      expect(
        payload.first['settings']['image_urls'],
        equals(['http://example.com/image2.jpg']),
      );
    });

    test(
      'FillFormPage Question parses image_url and image_urls from settings correctly',
      () {
        final jsonMap = {
          'id': 'q1',
          'type': 'multiple_choice',
          'label': 'Test Question',
          'is_required': true,
          'settings': {
            'image_url': 'http://example.com/banner.jpg',
            'image_urls': [
              'http://example.com/extra2.jpg',
              'http://example.com/extra3.jpg',
            ],
          },
          'options': [],
        };

        final q = Question.fromJson(jsonMap);

        expect(q.id, equals('q1'));
        expect(q.imageUrl, equals('http://example.com/banner.jpg'));
        expect(
          q.allImageUrls,
          equals([
            'http://example.com/banner.jpg',
            'http://example.com/extra2.jpg',
            'http://example.com/extra3.jpg',
          ]),
        );
        expect(q.label, equals('Test Question'));
      },
    );
  });
}
