// Smoke test: the app boots into the splash, shows its name, then hands off
// to the home screen with the Quran-wird heading. Proves the widget tree
// builds and the splash→home route works.

import 'package:flutter_test/flutter_test.dart';

import 'package:adhkar_app/main.dart';

void main() {
  testWidgets('boots into the splash, then reaches home', (tester) async {
    await tester.pumpWidget(const AdhkarApp());
    await tester.pump();

    // Splash is up, carrying the app name.
    expect(find.text('سمت'), findsOneWidget);

    // Let the splash's hold elapse and the route settle onto home.
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();

    expect(find.text('وردك من القرآن'), findsOneWidget);
  });
}
