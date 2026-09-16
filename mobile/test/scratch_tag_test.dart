import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_html/flutter_html.dart';

void main() {
  testWidgets('Test TagExtension fallback when returning null or custom tag', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Html(
            data: '<div class="normal">Hello Div</div><video-embed data-video="https://youtube.com">Video</video-embed>',
            extensions: [
              TagExtension(
                tagsToExtend: {'video-embed'},
                builder: (ctx) {
                  return const Text('CUSTOM VIDEO');
                },
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('CUSTOM VIDEO'), findsOneWidget);
  });
}
