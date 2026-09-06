import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/now_playing_track.dart';
import '../preview_mock_data.dart';
import '../providers/now_playing_providers.dart';

/// Album art on the left, title/artist + progress bar + transport controls
/// on the right — matches the reference design (art, bold title, gray
/// artist, a thin progress line with a dot thumb and m:ss labels either
/// end, previous/play-pause/next below). Renders nothing when there's no
/// active session (and not in preview) — an AOD screen with a stale/empty
/// player looks broken, an absent one doesn't.
class MiniMusicPlayer extends ConsumerWidget {
  const MiniMusicPlayer({this.isPreview = false, super.key});

  /// Falls back to mock data only when there's no real track — never
  /// overrides real playback data, even in preview.
  final bool isPreview;

  // Measured against the reference design, not guessed — art was ~35% of
  // screen height there; 84/190 were roughly half that proportion. Info
  // column is a *max* width now (Flexible below), not a fixed one — a
  // fixed SizedBox here overflowed on real phones narrower than the
  // emulator this was tuned against (art + gap + 230 exceeded the
  // available portrait width on the user's actual Samsung device).
  static const _artSize = 130.0;
  static const _maxInfoWidth = 230.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realTrack = ref.watch(nowPlayingTrackProvider).value;
    final hasRealTrack =
        realTrack != null &&
        (realTrack.title != null || realTrack.artist != null);
    final track = hasRealTrack
        ? realTrack
        : (isPreview ? mockPreviewTrack : null);
    if (track == null) return const SizedBox.shrink();

    final datasource = ref.read(nowPlayingDatasourceProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: track.albumArt != null
              ? Image.memory(
                  track.albumArt!,
                  width: _artSize,
                  height: _artSize,
                  fit: BoxFit.cover,
                )
              : _AlbumArtPlaceholder(size: _artSize),
        ),
        const SizedBox(width: 18),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxInfoWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  track.artist ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    color: Colors.white54,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                _ProgressBar(track: track),
                const SizedBox(height: 6),
                _Controls(track: track, datasource: datasource),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown in place of real album art — no such asset exists for either real
/// tracks without embedded art or the mock preview track (the reference
/// design's stylized "Midnight City" artwork isn't something to fabricate).
/// A neutral placeholder is honest about that gap rather than silently
/// leaving an empty space shaped differently from the real layout.
class _AlbumArtPlaceholder extends StatelessWidget {
  const _AlbumArtPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.music_note, color: Colors.white24, size: size * 0.4),
    );
  }
}

/// Native only pushes a new position on real `MediaController` events
/// (play/pause/seek/track change) — never on a per-second cadence, so the
/// displayed time would sit frozen between those events without this.
/// Ticks locally once a second while playing, interpolating from the last
/// known (position, wall-clock-time) pair rather than asking native for
/// anything more often — pairs with `AodOverlayActivity`'s frame-rate hint,
/// which is what actually lets the display redraw at ~1fps instead of
/// idling, see this project's CLAUDE.md.
class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.track});

  final NowPlayingTrack track;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  Timer? _timer;
  late int _basePositionMs;
  late DateTime _baseTime;

  @override
  void initState() {
    super.initState();
    _resetBase();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _ProgressBar old) {
    super.didUpdateWidget(old);
    final isNewServerState =
        old.track.positionMs != widget.track.positionMs ||
        old.track.isPlaying != widget.track.isPlaying ||
        old.track.title != widget.track.title;
    if (isNewServerState) _resetBase();
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resetBase() {
    _basePositionMs = widget.track.positionMs;
    _baseTime = DateTime.now();
  }

  void _syncTimer() {
    final shouldTick = widget.track.isPlaying;
    if (shouldTick && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!shouldTick && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  int get _displayedPositionMs {
    if (!widget.track.isPlaying) return widget.track.positionMs;
    final elapsedMs = DateTime.now().difference(_baseTime).inMilliseconds;
    return (_basePositionMs + elapsedMs).clamp(0, widget.track.durationMs);
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final positionMs = _displayedPositionMs;
    final fraction = track.durationMs > 0
        ? (positionMs / track.durationMs).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 12,
              width: width,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(height: 2, width: width, color: Colors.white24),
                  Container(
                    height: 2,
                    width: width * fraction,
                    color: Colors.white,
                  ),
                  Positioned(
                    left: (width * fraction - 4).clamp(0.0, width - 8),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatMs(positionMs), style: _timeStyle),
            Text(_formatMs(track.durationMs), style: _timeStyle),
          ],
        ),
      ],
    );
  }

  static const _timeStyle = TextStyle(
    fontFamily: 'Geist',
    color: Colors.white38,
    fontSize: 12,
  );

  static String _formatMs(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.track, required this.datasource});

  final NowPlayingTrack track;
  final dynamic datasource;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TransportButton(
          icon: Icons.skip_previous,
          iconSize: 24,
          buttonSize: 36,
          onPressed: datasource.skipPrevious,
        ),
        const SizedBox(width: 14),
        _TransportButton(
          icon: track.isPlaying ? Icons.pause : Icons.play_arrow,
          iconSize: 26,
          buttonSize: 52,
          filled: true,
          onPressed: track.isPlaying ? datasource.pause : datasource.play,
        ),
        const SizedBox(width: 14),
        _TransportButton(
          icon: Icons.skip_next,
          iconSize: 24,
          buttonSize: 36,
          onPressed: datasource.skipNext,
        ),
      ],
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.iconSize,
    required this.buttonSize,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final double iconSize;
  final double buttonSize;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        alignment: Alignment.center,
        decoration: filled
            ? BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1C1C1E),
                border: Border.all(color: Colors.white38),
              )
            : null,
        child: Icon(icon, size: iconSize, color: Colors.white),
      ),
    );
  }
}
