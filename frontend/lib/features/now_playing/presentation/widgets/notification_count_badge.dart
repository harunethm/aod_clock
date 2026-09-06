import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../preview_mock_data.dart';
import '../providers/now_playing_providers.dart';

/// Renders nothing at zero (and not in preview) — an AOD screen with a
/// stray "0" reads as broken, an absent one doesn't (same rule as
/// `MiniMusicPlayer`).
class NotificationCountBadge extends ConsumerWidget {
  const NotificationCountBadge({this.isPreview = false, super.key});

  /// Falls back to a mock count only when the real count is zero — never
  /// hides a real, nonzero count.
  final bool isPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realCount = ref.watch(notificationCountProvider).value ?? 0;
    final count = realCount > 0
        ? realCount
        : (isPreview ? mockPreviewNotificationCount : 0);
    if (count <= 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.notifications_none, size: 16, color: Colors.white54),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontFamily: 'Geist',
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
