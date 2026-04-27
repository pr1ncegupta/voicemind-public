import 'package:flutter_test/flutter_test.dart';
import 'package:voicemind_flutter/src/app.dart';


void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceMindApp());
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(VoiceMindApp), findsOneWidget);
  });
}
