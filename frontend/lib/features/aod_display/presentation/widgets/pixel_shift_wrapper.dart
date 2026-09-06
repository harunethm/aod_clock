import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../utils/pixel_shift.dart';

/// Nudges [child] by a few px every [interval] within [maxMarginPx] of its
/// natural position — see `pixel_shift.dart` for the pure offset math this
/// wraps. Disabled entirely (renders [child] untouched) when [enabled] is
/// false, so the settings toggle can turn it off with no wrapper overhead.
class PixelShiftWrapper extends StatefulWidget {
  const PixelShiftWrapper({
    required this.child,
    required this.enabled,
    this.maxMarginPx = 10,
    this.interval = const Duration(seconds: 60),
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double maxMarginPx;
  final Duration interval;

  @override
  State<PixelShiftWrapper> createState() => _PixelShiftWrapperState();
}

class _PixelShiftWrapperState extends State<PixelShiftWrapper> {
  Offset _offset = Offset.zero;
  Timer? _timer;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _startTimer();
  }

  @override
  void didUpdateWidget(covariant PixelShiftWrapper old) {
    super.didUpdateWidget(old);
    if (widget.enabled && _timer == null) {
      _startTimer();
    } else if (!widget.enabled && _timer != null) {
      _timer?.cancel();
      _timer = null;
      setState(() => _offset = Offset.zero);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(widget.interval, (_) {
      setState(() {
        _offset = nextPixelShiftOffset(
          current: _offset,
          maxMarginPx: widget.maxMarginPx,
          rng: _rng,
        );
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Instant jump, not animated: an animated transition submits ~48 frames
    // over 800ms every 60s, which is enough to force the display out of a
    // low-power idle refresh rate for no visual benefit — a pixel shift is
    // supposed to be imperceptible, not a visible slide. See this project's
    // CLAUDE.md for the refresh-rate reasoning this pairs with.
    return Transform.translate(offset: _offset, child: widget.child);
  }
}
