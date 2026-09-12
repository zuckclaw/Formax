import 'package:flutter_test/flutter_test.dart';
import 'package:form4x/models/question_model.dart';
import 'package:form4x/pages/form_maker/models/form_builder_state.dart';

void main() {
  test('buildApiPayload preserves page breaks between sections', () {
    final state = FormBuilderState(
      pages: [
        FormPageModel(
          title: 'Halaman 1',
          questions: [
            QuestionData(type: QuestionType.shortAnswer, label: 'Nama'),
          ],
        ),
        FormPageModel(
          title: 'Bagian Baru',
          questions: [
            QuestionData(
              type: QuestionType.multipleChoice,
              label: 'Jenis kelamin',
            ),
          ],
        ),
      ],
    );

    final payload = state.buildApiPayload();

    expect(payload.any((item) => item['type'] == 'page_break'), isTrue);
    expect(payload.length, 3);
    expect(payload[0]['type'], 'text');
    expect(payload[1]['type'], 'page_break');
    expect(payload[2]['type'], 'single_choice');
  });

  test('fromForm restores published question order and settings', () {
    final state = FormBuilderState.fromForm({
      'id': 'form-1',
      'title': 'Form lama',
      'description': '',
      'questions': [
        {
          'type': 'single_choice',
          'label': 'Pertanyaan kedua',
          'order_index': 1,
          'is_required': true,
          'settings': {'points': 3, 'scale_max': 7},
          'options': [
            {'label': 'B', 'order_index': 1},
            {'label': 'A', 'order_index': 0},
          ],
        },
        {
          'type': 'text',
          'label': 'Pertanyaan pertama',
          'order_index': 0,
          'options': [],
        },
      ],
    });

    expect(state.pages.single.questions[0].label, 'Pertanyaan pertama');
    final choice = state.pages.single.questions[1];
    expect(choice.label, 'Pertanyaan kedua');
    expect(choice.options.map((option) => option.label), ['A', 'B']);
    expect(choice.points, 3);
    expect(choice.scaleMax, 7);
  });
}
