import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hifz_helper/main.dart';
import 'package:hifz_helper/features/dashboard/daily_countdown.dart';

void main() {
  group('daily countdown', () {
    test('counts down to the next local midnight', () {
      final beforeMidnight = DateTime(2026, 9, 27, 23, 59, 59);
      final atMidnight = DateTime(2026, 9, 28);

      expect(timeUntilNextLocalMidnight(beforeMidnight), '00:00:01');
      expect(timeUntilNextLocalMidnight(atMidnight), '24:00:00');
    });

    test('rounds partial seconds up and clamps negative durations', () {
      expect(formatCountdown(const Duration(milliseconds: 1)), '00:00:01');
      expect(formatCountdown(const Duration(milliseconds: -1)), '00:00:00');
    });
  });

  testWidgets('App smoke test loads Daily Dashboard on start', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HifzHelperApp()));

    // Verify title and daily routine banner are displayed
    expect(find.text('Hifz Helper'), findsOneWidget);
  });
}
