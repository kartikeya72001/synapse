import 'package:flutter_test/flutter_test.dart';
import 'package:synapse/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SynapseApp());
    expect(find.text('Synapse'), findsOneWidget);
  });
}
