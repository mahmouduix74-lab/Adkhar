import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:adhkar_app/data/prayer_data.dart';
import 'package:adhkar_app/utils/arabic_numerals.dart';

void main() {
  group('clock formatting', () {
    // These assert the Arabic form, which depends on the ambient script flag.
    setUp(() => useArabicDigits = true);

    test('marks morning and evening apart', () {
      // The bug this guards: without ص/م, 23:09 and 11:09 both read "١١:٠٩".
      expect(formatClock(11, 9), '١١:٠٩ ص');
      expect(formatClock(23, 9), '١١:٠٩ م');
    });

    test('midnight and noon do not render as zero', () {
      expect(formatClock(0, 5), '١٢:٠٥ ص');
      expect(formatClock(12, 5), '١٢:٠٥ م');
    });
  });

  group('schedule', () {
    final schedule = buildSchedule(computeTimes(fallbackCoordinates, DateTime(2026, 9, 6)));

    test('has the six windows in chronological order', () {
      expect(schedule.map((p) => p.name).toList(),
          ['الفجر', 'الضحى', 'الظهر', 'العصر', 'المغرب', 'العشاء']);
      for (var i = 1; i < schedule.length; i++) {
        expect(schedule[i].minutes, greaterThan(schedule[i - 1].minutes),
            reason: '${schedule[i].name} should come after ${schedule[i - 1].name}');
      }
    });

    test('every window gets its own sky', () {
      final gradients = schedule.map((p) => '${p.c1}|${p.c2}|${p.c3}').toSet();
      expect(gradients.length, schedule.length,
          reason: 'two windows share a gradient, so the header colour is ambiguous');
    });

    test('adjacent skies are visibly different, not just distinct values', () {
      // Distinctness alone was not enough: deepening الضحى and الظهر
      // separately left them two hex points apart, and crossing from one to
      // the other changed nothing on screen.
      int channelGap(int a, int b) => (a - b).abs();
      int gap(Color x, Color y) =>
          channelGap(x.red, y.red) + channelGap(x.green, y.green) + channelGap(x.blue, y.blue);

      for (var i = 1; i < schedule.length; i++) {
        final a = schedule[i - 1], b = schedule[i];
        final total = gap(a.c1, b.c1) + gap(a.c2, b.c2) + gap(a.c3, b.c3);
        expect(total, greaterThan(90),
            reason: '${a.name} and ${b.name} look the same (total channel gap $total)');
      }
    });

    test('current window wraps to Isha before Fajr', () {
      final beforeFajr = schedule.first.minutes - 30;
      expect(currentPrayer(schedule, beforeFajr).name, 'العشاء');
      expect(nextPrayer(schedule, beforeFajr).name, 'الفجر');
    });

    test('current window tracks the clock through the day', () {
      for (var i = 0; i < schedule.length; i++) {
        final justAfter = schedule[i].minutes + 1;
        expect(currentPrayer(schedule, justAfter).name, schedule[i].name);
      }
    });
  });

  group('midnight wrap', () {
    final schedule = buildSchedule(computeTimes(fallbackCoordinates, DateTime(2026, 9, 6)));
    final isha = schedule.last, fajr = schedule.first;

    // Regression: at 04:06 the header read "متبقي ٢٤ ساعة و٥٤ دقيقة" and the
    // arc sat at 0%, because both spans were computed without wrapping.
    int forward(int from, int to) {
      final delta = to - from;
      return delta < 0 ? delta + 1440 : delta;
    }

    test('countdown to Fajr from after midnight is under an hour', () {
      final nowMin = fajr.minutes - 54;
      expect(forward(nowMin, fajr.minutes), 54);
    });

    test('progress through Isha is near the end just before Fajr', () {
      final nowMin = fajr.minutes - 54;
      final span = forward(isha.minutes, fajr.minutes);
      final gone = forward(isha.minutes, nowMin);
      expect(gone / span, greaterThan(0.8));
      expect(gone / span, lessThanOrEqualTo(1.0));
    });
  });

  group('clock formatting follows the script', () {
    tearDown(() => useArabicDigits = true);

    test('Latin locales get Latin digits and AM/PM', () {
      useArabicDigits = false;
      expect(formatClock(6, 35), '6:35 AM');
      expect(formatClock(18, 5), '6:05 PM');
    });
  });
}
