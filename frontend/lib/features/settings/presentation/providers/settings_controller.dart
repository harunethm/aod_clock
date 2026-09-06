import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/persistence/secure_storage_provider.dart';
import '../../../../core/platform/aod_control_channel.dart';
import '../../data/datasources/settings_datasource.dart';
import '../../domain/entities/aod_settings.dart';

final settingsDatasourceProvider = Provider<SettingsDatasource>((ref) {
  return SettingsDatasource(ref.watch(secureStorageProvider));
});

/// Loads persisted settings once, then holds the in-memory source of truth.
/// Every mutation writes through to storage *and* to the native side (via
/// `AodControlChannel.setAodEnabled`) so the foreground service's screen-off
/// receiver reflects the same toggle the UI shows.
class SettingsController extends AsyncNotifier<AodSettings> {
  @override
  Future<AodSettings> build() async {
    final settings = await ref.read(settingsDatasourceProvider).read();
    // Sync the already-persisted brightness to native on every load, not
    // just on slider change — otherwise a value set before the
    // setBrightnessLevel platform-channel wiring existed stays stuck at
    // AodPrefs's native default until the user happens to touch the slider.
    await ref
        .read(aodControlChannelProvider)
        .setBrightnessLevel(settings.brightnessLevel);
    return settings;
  }

  Future<void> setAodEnabled(bool enabled) async {
    await ref.read(aodControlChannelProvider).setAodEnabled(enabled);
    await _update((s) => s.copyWith(aodEnabled: enabled));
  }

  Future<void> setUse12HourClock(bool value) =>
      _update((s) => s.copyWith(use12HourClock: value));

  Future<void> setPixelShiftEnabled(bool value) =>
      _update((s) => s.copyWith(pixelShiftEnabled: value));

  Future<void> setBrightnessLevel(double value) async {
    // Was previously missing entirely — this only ever updated Flutter's
    // own storage, so the value `AodOverlayActivity` actually reads
    // (`AodPrefs`, native SharedPreferences) never changed from its 0.12f
    // default. Found by the user noticing AOD stayed dim regardless of
    // this slider.
    await ref.read(aodControlChannelProvider).setBrightnessLevel(value);
    await _update((s) => s.copyWith(brightnessLevel: value));
  }

  Future<void> _update(AodSettings Function(AodSettings) transform) async {
    final current = state.value ?? AodSettings.initial;
    final next = transform(current);
    state = AsyncData(next);
    await ref.read(settingsDatasourceProvider).write(next);
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AodSettings>(
      SettingsController.new,
    );

/// Permission status is native/OS state, not app state — re-check on every
/// screen visit via `ref.invalidate`, don't cache it across app restarts.
final notificationListenerGrantedProvider = FutureProvider.autoDispose<bool>((
  ref,
) {
  return ref.watch(aodControlChannelProvider).isNotificationListenerGranted();
});

final batteryOptimizationExemptProvider = FutureProvider.autoDispose<bool>((
  ref,
) {
  return ref.watch(aodControlChannelProvider).isBatteryOptimizationExempt();
});

/// `USE_FULL_SCREEN_INTENT` is a normal permission and *is* auto-granted at
/// install (confirmed on a real Android 15 emulator, correcting an earlier
/// wrong assumption in this codebase's history) — this tile exists because
/// Android 14+ lets the user revoke it via Settings afterwards, not because
/// it starts denied.
final fullScreenIntentGrantedProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(aodControlChannelProvider).isFullScreenIntentGranted();
});

/// The actual root cause behind AOD never triggering, found by testing on
/// a real emulator instead of guessing further: on API 33+, *every*
/// notification this app posts — including the full-screen-intent trigger,
/// not just the visible foreground-service one — is silently dropped
/// unless this is granted. `adb shell cmd appops get ... POST_NOTIFICATION`
/// read "ignore" on a fresh install; no crash, no log, nothing launches.
final notificationsPermissionGrantedProvider = FutureProvider.autoDispose<bool>(
  (ref) {
    return ref
        .watch(aodControlChannelProvider)
        .isNotificationsPermissionGranted();
  },
);
