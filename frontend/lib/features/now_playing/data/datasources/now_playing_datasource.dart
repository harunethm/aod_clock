import 'dart:typed_data';

import '../../../../core/platform/now_playing_channel.dart';
import '../../domain/entities/now_playing_track.dart';

/// Turns the primitive `Map`s off `NowPlayingChannel` into a
/// `NowPlayingTrack`. This is the one file that would need editing if the
/// native event payload shape ever changes.
class NowPlayingDatasource {
  const NowPlayingDatasource(this._channel);

  final NowPlayingChannel _channel;

  Stream<NowPlayingTrack?> get trackStream => _channel.trackStream.map(_parse);

  Future<void> play() => _channel.play();
  Future<void> pause() => _channel.pause();
  Future<void> skipNext() => _channel.skipNext();
  Future<void> skipPrevious() => _channel.skipPrevious();

  static NowPlayingTrack? _parse(Map<Object?, Object?>? event) {
    if (event == null) return null;
    return NowPlayingTrack(
      title: event['title'] as String?,
      artist: event['artist'] as String?,
      albumArt: event['albumArt'] as Uint8List?,
      isPlaying: event['isPlaying'] as bool? ?? false,
      positionMs: event['positionMs'] as int? ?? 0,
      durationMs: event['durationMs'] as int? ?? 0,
    );
  }
}
