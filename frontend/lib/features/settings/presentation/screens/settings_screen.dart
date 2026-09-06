import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common_widgets/permission_status_tile.dart';
import '../../../../core/platform/aod_control_channel.dart';
import '../providers/settings_controller.dart';

/// Doubles as this app's home screen — there's nothing else to show.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final notifGranted = ref.watch(notificationListenerGrantedProvider);
    final batteryExempt = ref.watch(batteryOptimizationExemptProvider);
    final fullScreenIntentGranted = ref.watch(fullScreenIntentGrantedProvider);
    final notificationsPermissionGranted = ref.watch(
      notificationsPermissionGrantedProvider,
    );
    final controller = ref.read(settingsControllerProvider.notifier);
    final aodControl = ref.read(aodControlChannelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AOD Clock')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load settings: $e')),
        data: (settings) => ListView(
          children: [
            SwitchListTile(
              title: const Text('Enable always-on display'),
              subtitle: const Text(
                'Shows clock, date and now-playing instead of turning the '
                'screen off. Uses meaningfully more battery than real '
                'hardware AOD — see the permissions below.',
              ),
              value: settings.aodEnabled,
              onChanged: controller.setAodEnabled,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () => context.push('/aod', extra: true),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Preview AOD screen'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'Preview shows it now, on demand. When actually enabled, it '
                'only appears automatically the next time the screen would '
                'turn off (power button or timeout) — there\'s nothing else '
                'to press.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Required permissions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            PermissionStatusTile(
              title: 'Show notifications',
              subtitle:
                  'The one to check first if AOD isn\'t triggering. Without '
                  'this Android silently drops every notification this app '
                  'posts, including the one that launches AOD over the '
                  'lockscreen — no error, it just never appears.',
              granted: notificationsPermissionGranted.value,
              onGrant: () async {
                await aodControl.requestNotificationsPermission();
                ref.invalidate(notificationsPermissionGrantedProvider);
              },
            ),
            PermissionStatusTile(
              title: 'Full-screen launch',
              subtitle:
                  'Lets AOD appear over the lockscreen instead of as a '
                  'normal notification (Android 14+, revocable in Settings '
                  'after being granted at install).',
              granted: fullScreenIntentGranted.value,
              onGrant: () async {
                await aodControl.openFullScreenIntentSettings();
                ref.invalidate(fullScreenIntentGrantedProvider);
              },
            ),
            PermissionStatusTile(
              title: 'Notification access',
              subtitle: 'Needed to show what\'s currently playing.',
              granted: notifGranted.value,
              onGrant: () async {
                await aodControl.openNotificationListenerSettings();
                ref.invalidate(notificationListenerGrantedProvider);
              },
            ),
            PermissionStatusTile(
              title: 'Ignore battery optimizations',
              subtitle:
                  'Without this Android may kill the AOD service in the '
                  'background.',
              granted: batteryExempt.value,
              onGrant: () async {
                await aodControl.requestBatteryOptimizationExemption();
                ref.invalidate(batteryOptimizationExemptProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Samsung auto-start'),
              subtitle: const Text(
                'Samsung hides this behind its own battery settings with no '
                'app-launchable intent — open Settings > Apps > AOD Clock > '
                'Battery > Allow background activity, manually.',
              ),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('12-hour clock'),
              value: settings.use12HourClock,
              onChanged: controller.setUse12HourClock,
            ),
            SwitchListTile(
              title: const Text('Pixel-shift burn-in protection'),
              subtitle: const Text('Nudges the display slightly every minute.'),
              value: settings.pixelShiftEnabled,
              onChanged: controller.setPixelShiftEnabled,
            ),
            ListTile(
              title: const Text('Brightness'),
              subtitle: Slider(
                value: settings.brightnessLevel,
                min: 0.02,
                max: 0.4,
                onChanged: controller.setBrightnessLevel,
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => _checkAllPermissions(context, ref),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Check all permissions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Re-reads all three permission checks in one pass instead of relying on
  /// the user to expand each tile individually, and reports the combined
  /// result — this is the "why isn't AOD triggering" starting point.
  Future<void> _checkAllPermissions(BuildContext context, WidgetRef ref) async {
    ref.invalidate(notificationsPermissionGrantedProvider);
    ref.invalidate(fullScreenIntentGrantedProvider);
    ref.invalidate(notificationListenerGrantedProvider);
    ref.invalidate(batteryOptimizationExemptProvider);

    final results = await Future.wait([
      ref.read(notificationsPermissionGrantedProvider.future),
      ref.read(fullScreenIntentGrantedProvider.future),
      ref.read(notificationListenerGrantedProvider.future),
      ref.read(batteryOptimizationExemptProvider.future),
    ]);
    final allGranted = results.every((granted) => granted);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allGranted
              ? 'All required permissions are granted.'
              : 'Missing permissions — check the red items above.',
        ),
      ),
    );
  }
}
