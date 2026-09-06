import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits the current time aligned to minute boundaries — the whole point of
/// AOD battery savings is *not* redrawing every second. First emission is
/// immediate so the clock isn't blank while waiting for the first boundary.
final minuteTickerProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  while (true) {
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    await Future<void>.delayed(nextMinute.difference(now));
    yield DateTime.now();
  }
});
