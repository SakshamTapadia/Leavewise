import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leavewise/app/app.dart';
import 'package:leavewise/app/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        todayProvider.overrideWithValue(DateTime.utc(2027, 1, 1)),
      ],
      child: const LeaveWiseApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first launch shows the welcome step', (tester) async {
    await pumpApp(tester);
    expect(find.text('Your holidays deserve better planning.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('finishing onboarding opens a dashboard built from the data',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Start planning'));
    await tester.pumpAndSettle();

    // Today is 1 Jan 2027, so the next holiday is Republic Day on 26 Jan.
    expect(find.text('REPUBLIC DAY'), findsOneWidget);
    expect(find.text('BEST UPCOMING BREAKS'), findsOneWidget);
    expect(find.text('In 25 days'), findsOneWidget);
  });
}
