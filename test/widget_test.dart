import 'package:flutter_test/flutter_test.dart';
import 'package:tib_ai_personal_styling/app.dart';

void main() {
  testWidgets('TiB app smoke test', (WidgetTester tester) async {
    expect(find.byType(TibApp), findsNothing);
  });
}
