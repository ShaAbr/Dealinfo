// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:dealinfo_app/main.dart';

void main() {
  testWidgets('App shows main menu screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DealInfoApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Main Menu'), findsOneWidget);
  });

  testWidgets('App builds without framework exception', (WidgetTester tester) async {
    await tester.pumpWidget(const DealInfoApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
