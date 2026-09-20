import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:form4x/widgets/code_block.dart';
import 'package:form4x/widgets/inline_video.dart';

void main() {
  group('Paritas web: code highlight & video', () {
    testWidgets('CodeBlock me-render kode tanpa crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CodeBlock(
              code: 'void main() {\n  print("hi");\n}',
              language: 'dart',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(RichText), findsWidgets);
      expect(find.textContaining('print', findRichText: true),
          findsOneWidget);
    });

    testWidgets('CodeBlock bahasa tak dikenal → fallback polos',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CodeBlock(
              code: 'hello world',
              language: 'bahasa-aneh',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
          find.textContaining('hello world', findRichText: true),
          findsOneWidget);
    });

    test('isDirectVideo hanya untuk file video langsung', () {
      expect(
          InlineVideoPlayer.isDirectVideo('https://x.test/v.mp4'), isTrue);
      expect(
          InlineVideoPlayer.isDirectVideo(
              'https://x.test/v.mp4?token=abc'),
          isTrue);
      expect(
          InlineVideoPlayer.isDirectVideo(
              'https://www.youtube.com/watch?v=abc123'),
          isFalse);
      expect(InlineVideoPlayer.isDirectVideo('https://youtu.be/abc123'),
          isFalse);
      expect(
          InlineVideoPlayer.isDirectVideo(
              'https://drive.google.com/file/d/1/view'),
          isFalse);
    });
  });
}
