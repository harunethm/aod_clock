import '../../../../core/persistence/secure_storage_provider.dart';
import '../../../../core/persistence/storage_keys.dart';
import '../../domain/entities/aod_settings.dart';

/// No repository interface layer here (unlike `identity`/`auth`, which have
/// one to swap real/fake network implementations) — this reads/writes local
/// storage only, one implementation ever, an interface would have nothing
/// to abstract over.
class SettingsDatasource {
  const SettingsDatasource(this._storage);

  final SecureStorage _storage;

  Future<AodSettings> read() async {
    final enabled = await _storage.read(kAodEnabledKey);
    final use12h = await _storage.read(kUse12HourClockKey);
    final pixelShift = await _storage.read(kPixelShiftEnabledKey);
    final brightness = await _storage.read(kBrightnessLevelKey);

    return AodSettings(
      aodEnabled: enabled == 'true',
      use12HourClock: use12h == 'true',
      pixelShiftEnabled: pixelShift == null ? true : pixelShift == 'true',
      brightnessLevel: double.tryParse(brightness ?? '') ?? 0.12,
    );
  }

  Future<void> write(AodSettings settings) async {
    await _storage.write(kAodEnabledKey, settings.aodEnabled.toString());
    await _storage.write(
      kUse12HourClockKey,
      settings.use12HourClock.toString(),
    );
    await _storage.write(
      kPixelShiftEnabledKey,
      settings.pixelShiftEnabled.toString(),
    );
    await _storage.write(
      kBrightnessLevelKey,
      settings.brightnessLevel.toString(),
    );
  }

  Future<bool> readOnboardingComplete() async =>
      (await _storage.read(kOnboardingCompleteKey)) == 'true';

  Future<void> writeOnboardingComplete() =>
      _storage.write(kOnboardingCompleteKey, 'true');
}
