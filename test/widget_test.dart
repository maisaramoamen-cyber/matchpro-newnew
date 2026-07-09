import 'package:flutter_test/flutter_test.dart';
import 'package:match_pro/main.dart';

void main() {
  testWidgets('MatchPro smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MatchProApp());
    expect(find.byType(MatchProApp), findsOneWidget);
  });
}
