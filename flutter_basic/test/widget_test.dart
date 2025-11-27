// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_basic/app.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    // Navigate to the Counter tab via the bottom navigation bar.
    await tester.tap(find.text('Counter'));
    await tester.pumpAndSettle();

  final counterValue = find.byKey(const ValueKey('counter-value'));
  final incrementButton = find.byKey(const ValueKey('counter-increment'));

  expect(counterValue, findsOneWidget);
  expect((tester.widget<Text>(counterValue)).data, '0');

    // Tap the เพิ่ม button to increment the counter.
  await tester.ensureVisible(incrementButton);
  await tester.tap(incrementButton);
    await tester.pump();

    await tester.pump();

    expect(counterValue, findsOneWidget);
    expect((tester.widget<Text>(counterValue)).data, '1');
  });
}
