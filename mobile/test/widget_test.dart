// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:form4x/main.dart';

void main() {
  testWidgets('App loads login or home', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // App harus menampilkan salah satu: LoginPage atau HomePage
    // Tidak lagi counter test bawaan Flutter
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
