// Basic Flutter widget test for EMG Mobile App

import 'package:flutter_test/flutter_test.dart';

import 'package:emg_mobile/main.dart';

void main() {
  testWidgets('EMG Monitor app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EMGMonitorApp());

    // Verify that the app title is displayed.
    expect(find.text('Sichiray EMG Monitor'), findsOneWidget);
  });
}
