import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:form4x/utils/quill_html.dart';
import 'package:form4x/widgets/rich_text_field.dart';
import 'package:form4x/widgets/rich_text_view.dart';

void main() {
  test('QuillHtml converts BlockEmbed.image to <img> tag and back', () {
    final doc = Document();
    doc.insert(0, 'Awal\n');
    doc.insert(5, BlockEmbed.image('https://example.com/foto.jpg'));
    doc.insert(6, '\nAkhir\n');

    final html = QuillHtml.documentToHtml(doc);
    expect(html.contains('<img src="https://example.com/foto.jpg"'), true);

    final docBack = QuillHtml.documentFromHtml(html);
    final deltaBack = docBack.toDelta().toJson();
    final hasImage = deltaBack.any(
      (op) =>
          op['insert'] is Map &&
          (op['insert'] as Map)['image'] == 'https://example.com/foto.jpg',
    );
    expect(hasImage, true);
  });

  testWidgets('RichTextField renders editor and image button properly', (
    WidgetTester tester,
  ) async {
    String currentHtml = '<p>Halo</p>';

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: const [Locale('id'), Locale('en')],
        home: Scaffold(
          body: SingleChildScrollView(
            child: RichTextField(
              initialHtml: currentHtml,
              onChanged: (html) {
                currentHtml = html;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(RichTextField), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('RichTextView renders HTML properly', (
    WidgetTester tester,
  ) async {
    const html = '<p>Sebelum</p><p>Sesudah</p>';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RichTextView(html: html)),
      ),
    );

    expect(find.byType(RichTextView), findsOneWidget);
  });
}
