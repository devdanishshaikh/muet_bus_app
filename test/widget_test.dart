import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:muet_smart_bus_tracking_system/main.dart';

void main() {
  testWidgets('app starts with a Material 3 shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
