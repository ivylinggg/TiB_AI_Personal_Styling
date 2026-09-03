import 'package:flutter_test/flutter_test.dart';

import 'package:tib_ai_personal_styling/main.dart';

void main() {
  testWidgets('TiB app smoke test', (WidgetTester tester) async {
    expect(TibApp, isNotNull);
  });
}
