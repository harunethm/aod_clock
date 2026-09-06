import '../domain/entities/now_playing_track.dart';

/// Fallback-only data for `AodDisplayScreen(isPreview: true)` (the Settings
/// screen's Preview button) — used *only* when there's no real track/
/// notification data, never overrides real data that happens to be active.
/// Matches the numbers from the reference design (`M83` — "Midnight City").
const mockPreviewTrack = NowPlayingTrack(
  title: 'Midnight City',
  artist: 'M83',
  albumArt: null,
  isPlaying: true,
  positionMs: 84000,
  durationMs: 241000,
);
const mockPreviewNotificationCount = 3;
