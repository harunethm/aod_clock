/// Extracted from `ClockWidget` so the formatting logic is unit-testable
/// without pumping a widget.
String formatClockTime(DateTime time, {required bool use12HourClock}) {
  final minute = time.minute.toString().padLeft(2, '0');
  if (!use12HourClock) {
    return '${time.hour.toString().padLeft(2, '0')}:$minute';
  }
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final suffix = time.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $suffix';
}
