import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridges to `MediaNotificationListenerService`'s notification count
/// (see `NotificationCountBridge.kt`) — reuses the same "Notification
/// access" permission already needed for now-playing, no separate grant.
abstract class NotificationCountChannel {
  Stream<int> get countStream;
}

class MethodChannelNotificationCount implements NotificationCountChannel {
  const MethodChannelNotificationCount();

  static const _events = EventChannel(
    'com.scylla.tool.aodclock/notification_count/events',
  );

  @override
  Stream<int> get countStream =>
      _events.receiveBroadcastStream().map((e) => (e as int?) ?? 0);
}

final notificationCountChannelProvider = Provider<NotificationCountChannel>((
  ref,
) {
  return const MethodChannelNotificationCount();
});
