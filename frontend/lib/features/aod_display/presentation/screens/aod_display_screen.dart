import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/aod_control_channel.dart';
import '../../../now_playing/presentation/widgets/mini_music_player.dart';
import '../../../now_playing/presentation/widgets/notification_count_badge.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../widgets/clock_widget.dart';
import '../widgets/date_widget.dart';
import '../widgets/pixel_shift_wrapper.dart';

/// Reached two ways: (1) `AodOverlayActivity` launches straight into this
/// as its initial route (native sets it to `/aod`, see `app_router.dart`)
/// when the real screen would otherwise turn off, or (2) pushed on top of
/// the normal app stack from the Settings screen's "Preview" button, for
/// testing without waiting for a real screen-off. A tap dismisses either
/// way it was reached: pops back to Settings if there's a route to pop to
/// (preview), otherwise asks the native side to finish the overlay
/// activity, dropping back to the real (locked) lockscreen — finishing
/// that Activity would be wrong for the preview case, it isn't the one
/// showing.
///
/// Layout follows `MediaQuery`'s orientation, not a fixed shape: portrait
/// stacks clock-then-player vertically (a phone rotated into a dock/stand
/// is the realistic landscape case, not a permanently-landscape phone), so
/// this needs to react live if the device is rotated while showing.
class AodDisplayScreen extends ConsumerWidget {
  const AodDisplayScreen({this.isPreview = false, super.key});

  /// True when reached via the Settings screen's Preview button rather
  /// than a real screen-off. Passed straight down to `MiniMusicPlayer`/
  /// `NotificationCountBadge`, which use it only as a *fallback* when
  /// there's no real data — real playback/notifications always win, even
  /// in preview. (An earlier version overrode the providers outright via a
  /// nested `ProviderScope`, which hid real data during preview — fixed.)
  final bool isPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).value;
    final pixelShiftEnabled = settings?.pixelShiftEnabled ?? true;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            ref.read(aodControlChannelProvider).dismissAodOverlay();
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Center(
              child: PixelShiftWrapper(
                enabled: pixelShiftEnabled,
                child: isPortrait
                    ? _PortraitLayout(isPreview: isPreview)
                    : _LandscapeLayout(isPreview: isPreview),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Date + notification count share one row (badge right next to the date,
/// not floating separately above the player).
class _DateRow extends StatelessWidget {
  const _DateRow({required this.isPreview});

  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const DateWidget(),
        const SizedBox(width: 12),
        NotificationCountBadge(isPreview: isPreview),
      ],
    );
  }
}

/// Clock on top, date+notification-count then player below — centered,
/// stacked.
class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout({required this.isPreview});

  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Nested so the date lines up with the clock's own left edge
        // instead of being centered independently under it.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const ClockWidget(),
            const SizedBox(height: 8),
            _DateRow(isPreview: isPreview),
          ],
        ),
        const SizedBox(height: 32),
        MiniMusicPlayer(isPreview: isPreview),
      ],
    );
  }
}

/// Two equal halves, each centered within its own half — not two blocks
/// pinned to opposite edges with a gap between (what `spaceBetween` gave).
class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({required this.isPreview});

  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: Column(
              // Date lines up with the clock's own left edge, not
              // centered independently under it.
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const ClockWidget(),
                const SizedBox(height: 8),
                _DateRow(isPreview: isPreview),
              ],
            ),
          ),
        ),
        Expanded(
          child: Center(child: MiniMusicPlayer(isPreview: isPreview)),
        ),
      ],
    );
  }
}
