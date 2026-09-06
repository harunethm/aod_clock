import 'package:aod_clock/core/persistence/secure_storage_provider.dart';
import 'package:aod_clock/features/settings/data/datasources/settings_datasource.dart';
import 'package:aod_clock/features/settings/domain/entities/aod_settings.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecureStorage implements SecureStorage {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  test('write then read round-trips every field', () async {
    final datasource = SettingsDatasource(_FakeSecureStorage());
    const settings = AodSettings(
      aodEnabled: true,
      use12HourClock: true,
      pixelShiftEnabled: false,
      brightnessLevel: 0.25,
    );

    await datasource.write(settings);
    final read = await datasource.read();

    expect(read.aodEnabled, true);
    expect(read.use12HourClock, true);
    expect(read.pixelShiftEnabled, false);
    expect(read.brightnessLevel, 0.25);
  });

  test(
    'read with nothing stored returns AodSettings.initial-equivalent defaults',
    () async {
      final datasource = SettingsDatasource(_FakeSecureStorage());
      final read = await datasource.read();

      expect(read.aodEnabled, false);
      expect(read.use12HourClock, false);
      expect(read.pixelShiftEnabled, true);
      expect(read.brightnessLevel, 0.12);
    },
  );

  test(
    'onboarding flag defaults to incomplete and persists once set',
    () async {
      final datasource = SettingsDatasource(_FakeSecureStorage());
      expect(await datasource.readOnboardingComplete(), false);

      await datasource.writeOnboardingComplete();
      expect(await datasource.readOnboardingComplete(), true);
    },
  );
}
