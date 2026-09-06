import 'dart:math';

import 'package:aod_clock/features/aod_display/presentation/utils/pixel_shift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextPixelShiftOffset', () {
    test('stays within the margin after many steps', () {
      var offset = Offset.zero;
      final rng = Random(42);
      for (var i = 0; i < 1000; i++) {
        offset = nextPixelShiftOffset(
          current: offset,
          maxMarginPx: 10,
          rng: rng,
        );
        expect(offset.dx, inInclusiveRange(-10, 10));
        expect(offset.dy, inInclusiveRange(-10, 10));
      }
    });

    test('is deterministic for a given seed', () {
      final a = nextPixelShiftOffset(
        current: Offset.zero,
        maxMarginPx: 10,
        rng: Random(7),
      );
      final b = nextPixelShiftOffset(
        current: Offset.zero,
        maxMarginPx: 10,
        rng: Random(7),
      );
      expect(a, b);
    });

    test('moves from the current position, not from zero', () {
      final rng = Random(1);
      final first = nextPixelShiftOffset(
        current: const Offset(5, 5),
        maxMarginPx: 10,
        rng: rng,
      );
      expect(first, isNot(Offset.zero));
    });
  });
}
