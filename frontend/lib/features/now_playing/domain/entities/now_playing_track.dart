import 'dart:typed_data';

class NowPlayingTrack {
  const NowPlayingTrack({
    required this.title,
    required this.artist,
    required this.albumArt,
    required this.isPlaying,
    required this.positionMs,
    required this.durationMs,
  });

  final String? title;
  final String? artist;
  final Uint8List? albumArt;
  final bool isPlaying;
  final int positionMs;
  final int durationMs;
}
