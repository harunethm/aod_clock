import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/notification_count_channel.dart';
import '../../../../core/platform/now_playing_channel.dart';
import '../../data/datasources/now_playing_datasource.dart';
import '../../domain/entities/now_playing_track.dart';

final nowPlayingDatasourceProvider = Provider<NowPlayingDatasource>((ref) {
  return NowPlayingDatasource(ref.watch(nowPlayingChannelProvider));
});

final nowPlayingTrackProvider = StreamProvider<NowPlayingTrack?>((ref) {
  return ref.watch(nowPlayingDatasourceProvider).trackStream;
});

/// Sourced from the same `NotificationListenerService` as now-playing —
/// rides on the same "Notification access" permission, no separate grant.
final notificationCountProvider = StreamProvider<int>((ref) {
  return ref.watch(notificationCountChannelProvider).countStream;
});
