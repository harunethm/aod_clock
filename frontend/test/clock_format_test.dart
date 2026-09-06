import 'package:aod_clock/features/aod_display/presentation/utils/clock_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatClockTime', () {
    test('24h format pads single digits', () {
      expect(
        formatClockTime(DateTime(2026, 1, 1, 9, 5), use12HourClock: false),
        '09:05',
      );
    });

    test('12h format converts midnight to 12 AM', () {
      expect(
        formatClockTime(DateTime(2026, 1, 1, 0, 5), use12HourClock: true),
        '12:05 AM',
      );
    });

    test('12h format converts noon to 12 PM', () {
      expect(
        formatClockTime(DateTime(2026, 1, 1, 12, 0), use12HourClock: true),
        '12:00 PM',
      );
    });

    test('12h format converts afternoon hour', () {
      expect(
        formatClockTime(DateTime(2026, 1, 1, 22, 30), use12HourClock: true),
        '10:30 PM',
      );
    });
  });
}
