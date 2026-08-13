import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kyndora/screens/auth_screen.dart';

void main() {
  testWidgets('AuthScreen UI Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Password'), findsOneWidget);

    expect(find.byType(ElevatedButton), findsAtLeastNWidgets(1));
  });
}
