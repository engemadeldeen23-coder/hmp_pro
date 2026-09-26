import 'package:flutter_test/flutter_test.dart';
import 'package:hmp_pro/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const HmpProApp());
    expect(find.text('HMP PRO'), findsOneWidget);
  });
}