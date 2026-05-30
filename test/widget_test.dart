import 'package:flutter_test/flutter_test.dart';
import 'package:minguri_app/main.dart';

void main() {
  testWidgets('Minguri app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MinguriApp());
    expect(find.text('minguri'), findsOneWidget);
  });
}