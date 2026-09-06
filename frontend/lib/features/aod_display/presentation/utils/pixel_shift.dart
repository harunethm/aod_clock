import 'dart:math';
import 'dart:ui';

/// Pure and deterministic given a seeded [rng] — the actual burn-in
/// protection technique real AOD panels use: a small random walk clamped to
/// a safe margin so static content never sits on the same pixels for long.
Offset nextPixelShiftOffset({
  required Offset current,
  required double maxMarginPx,
  required Random rng,
  double stepPx = 2,
}) {
  final dx = (current.dx + (rng.nextDouble() * 2 - 1) * stepPx).clamp(
    -maxMarginPx,
    maxMarginPx,
  );
  final dy = (current.dy + (rng.nextDouble() * 2 - 1) * stepPx).clamp(
    -maxMarginPx,
    maxMarginPx,
  );
  return Offset(dx, dy);
}
