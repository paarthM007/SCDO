import 'package:flutter_test/flutter_test.dart';
import 'package:scdo_app/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const SCDOApp());
    expect(find.text('SCDO Simulator'), findsOneWidget);
  });
}
