import 'package:flutter_test/flutter_test.dart';

import 'package:koai/main.dart';
import 'package:flutter/material.dart';
import 'package:koai/screens/manual_screen.dart';

void main() {
  testWidgets('KOAI home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const KoaiApp());

    expect(find.text('KOAI'), findsOneWidget);
    expect(find.text('Start KOAI'), findsOneWidget);
    expect(find.text('Auto-tap correct answer'), findsOneWidget);
    expect(find.text('Manual question mode'), findsOneWidget);
  });

  testWidgets('Manual mode screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ManualScreen()));

    expect(find.text('Ask KOAI'), findsOneWidget);
    expect(find.text('Option A'), findsOneWidget);
    expect(find.text('Option D'), findsOneWidget);
  });
}
