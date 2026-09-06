import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridges to the native `AodForegroundService`/`AodOverlayActivity` pair
/// (see `android/.../AodForegroundService.kt`). Every call here maps 1:1 to
/// a case in `MainActivity`'s method channel handler — that Kotlin switch is
/// the source of truth for the wire contract, documented in this project's
/// CLAUDE.md.
abstract class AodControlChannel {
  Future<void> setAodEnabled(bool enabled);
  Future<bool> isAodEnabled();
  Future<void> setBrightnessLevel(double level);
  Future<bool> isNotificationListenerGranted();
  Future<void> openNotificationListenerSettings();
  Future<bool> isBatteryOptimizationExempt();
  Future<void> requestBatteryOptimizationExemption();
  Future<bool> isFullScreenIntentGranted();
  Future<void> openFullScreenIntentSettings();
  Future<bool> isNotificationsPermissionGranted();
  Future<void> requestNotificationsPermission();
  Future<void> dismissAodOverlay();
}

class MethodChannelAodControl implements AodControlChannel {
  const MethodChannelAodControl();

  static const _channel = MethodChannel('com.scylla.tool.aodclock/aod_control');

  @override
  Future<void> setAodEnabled(bool enabled) =>
      _channel.invokeMethod('setAodEnabled', {'enabled': enabled});

  @override
  Future<bool> isAodEnabled() async =>
      (await _channel.invokeMethod<bool>('isAodEnabled')) ?? false;

  @override
  Future<void> setBrightnessLevel(double level) =>
      _channel.invokeMethod('setBrightnessLevel', {'level': level});

  @override
  Future<bool> isNotificationListenerGranted() async =>
      (await _channel.invokeMethod<bool>('isNotificationListenerGranted')) ??
      false;

  @override
  Future<void> openNotificationListenerSettings() =>
      _channel.invokeMethod('openNotificationListenerSettings');

  @override
  Future<bool> isBatteryOptimizationExempt() async =>
      (await _channel.invokeMethod<bool>('isBatteryOptimizationExempt')) ??
      false;

  @override
  Future<void> requestBatteryOptimizationExemption() =>
      _channel.invokeMethod('requestBatteryOptimizationExemption');

  @override
  Future<bool> isFullScreenIntentGranted() async =>
      (await _channel.invokeMethod<bool>('isFullScreenIntentGranted')) ?? false;

  @override
  Future<void> openFullScreenIntentSettings() =>
      _channel.invokeMethod('openFullScreenIntentSettings');

  @override
  Future<bool> isNotificationsPermissionGranted() async =>
      (await _channel.invokeMethod<bool>('isNotificationsPermissionGranted')) ??
      false;

  @override
  Future<void> requestNotificationsPermission() =>
      _channel.invokeMethod('requestNotificationsPermission');

  @override
  Future<void> dismissAodOverlay() =>
      _channel.invokeMethod('dismissAodOverlay');
}

final aodControlChannelProvider = Provider<AodControlChannel>((ref) {
  return const MethodChannelAodControl();
});
