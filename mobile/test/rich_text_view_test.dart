import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form4x/widgets/rich_text_view.dart';

void main() {
  const pathologicalHtml =
      '<p><span style="font-weight: bold; font-style: italic; '
      'text-decoration: underline; text-decoration: line-through; '
      'color: #FF558B2F;">Empty Formhalosonny</span></p>';

  test('stripHtml menghilangkan markup HTML', () {
    expect(
      RichTextView.stripHtml(pathologicalHtml),
      'Empty Formhalosonny',
    );
  });

  testWidgets('RichTextView merender HTML tanpa membocorkan tag mentah',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichTextView(html: pathologicalHtml),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('<p>'), findsNothing);
    expect(find.text('</p>'), findsNothing);
    expect(find.textContaining('<span'), findsNothing);
    expect(find.textContaining('</span>'), findsNothing);
    expect(
      find.textContaining('Empty Formhalosonny', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('RichTextView tidak melempar untuk input kosong', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RichTextView(html: ''))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SizedBox), findsWidgets);
  });
}