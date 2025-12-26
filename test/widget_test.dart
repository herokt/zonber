import 'package:flutter_test/flutter_test.dart';

import 'package:zonber/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ZonberApp());
    await tester.pumpAndSettle();

    // Verify app title is displayed
    expect(find.text('ZONBER'), findsOneWidget);
  });
}
