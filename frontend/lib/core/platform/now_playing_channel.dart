import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridges to `MediaNotificationListenerService`. Kept primitive
/// (`Map<String, dynamic>?`, not a domain entity) so `core/` doesn't depend
/// on `features/now_playing` — the `now_playing` feature's datasource is
/// what turns this into a `NowPlayingTrack`.
///
/// Event payload keys: `title` (String?), `artist` (String?), `albumArt`
/// (Uint8List?, JPEG/PNG bytes), `isPlaying` (bool), `positionMs` (int),
/// `durationMs` (int). A `null` event means nothing is currently playing.
abstract class NowPlayingChannel {
  Stream<Map<Object?, Object?>?> get trackStream;
  Future<void> play();
  Future<void> pause();
  Future<void> skipNext();
  Future<void> skipPrevious();
}

class MethodChannelNowPlaying implements NowPlayingChannel {
  const MethodChannelNowPlaying();

  static const _events = EventChannel(
    'com.scylla.tool.aodclock/now_playing/events',
  );
  static const _control = MethodChannel(
    'com.scylla.tool.aodclock/now_playing/control',
  );

  @override
  Stream<Map<Object?, Object?>?> get trackStream =>
      _events.receiveBroadcastStream().map((e) => e as Map<Object?, Object?>?);

  @override
  Future<void> play() => _control.invokeMethod('play');

  @override
  Future<void> pause() => _control.invokeMethod('pause');

  @override
  Future<void> skipNext() => _control.invokeMethod('skipNext');

  @override
  Future<void> skipPrevious() => _control.invokeMethod('skipPrevious');
}

final nowPlayingChannelProvider = Provider<NowPlayingChannel>((ref) {
  return const MethodChannelNowPlaying();
});
