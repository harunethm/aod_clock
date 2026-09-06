import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/presentation/providers/settings_controller.dart';
import '../providers/minute_ticker_provider.dart';
import '../utils/clock_format.dart';

class ClockWidget extends ConsumerWidget {
  const ClockWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(minuteTickerProvider).value ?? DateTime.now();
    final use12h =
        ref.watch(settingsControllerProvider).value?.use12HourClock ?? false;

    // fontSize 140 was tuned against the reference design's proportions,
    // but real phones vary widely in logical width (measured: a ~360dp-wide
    // device — a common Android width — wrapped "13:39" onto two lines,
    // since a fixed-size Text has no notion of the screen it's actually on).
    // FittedBox scales the whole clock down as one block instead, so it
    // never wraps or overflows regardless of device width, and still shows
    // at full size on phones wide enough for it.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(formatClockTime(now, use12HourClock: use12h), style: _style),
    );
  }

  // Outfit ExtraLight, bundled locally (pubspec.yaml's fonts: section) —
  // not google_fonts' runtime-fetched variant, see this project's CLAUDE.md.
  static const _style = TextStyle(
    fontFamily: 'Outfit',
    color: Colors.white,
    fontSize: 140,
    fontWeight: FontWeight.w200,
  );
}
