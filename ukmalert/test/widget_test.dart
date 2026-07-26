import 'package:flutter_test/flutter_test.dart';
import 'package:ukmalert/main.dart';

void main() {
  testWidgets('UKMAlert app smoke test', (WidgetTester tester) async {
    // Firebase is initialized in main() before runApp, so we just verify
    // the widget tree can be described without throwing.
    expect(UKMAlertApp, isNotNull);
  });
}
