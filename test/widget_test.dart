import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quizcup/app.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: QuizCupApp(),
      ),
    );

    // Verify the app builds
    expect(find.text('QuizCup'), findsOneWidget);
  });
}
