/// Hand-written, not `@JsonSerializable` — four scalar fields don't earn
/// codegen. Persisted as individual SecureStorage keys (see
/// `storage_keys.dart`), not one JSON blob, so a corrupt/missing single key
/// can't take the rest down with it.
class AodSettings {
  const AodSettings({
    required this.aodEnabled,
    required this.use12HourClock,
    required this.pixelShiftEnabled,
    required this.brightnessLevel,
  });

  /// Defaults for a fresh install: AOD off until the user opts in and grants
  /// the manual permissions it needs, 24h clock, pixel-shift on (it's free
  /// burn-in protection), dim brightness.
  static const initial = AodSettings(
    aodEnabled: false,
    use12HourClock: false,
    pixelShiftEnabled: true,
    brightnessLevel: 0.12,
  );

  final bool aodEnabled;
  final bool use12HourClock;
  final bool pixelShiftEnabled;
  final double brightnessLevel;

  AodSettings copyWith({
    bool? aodEnabled,
    bool? use12HourClock,
    bool? pixelShiftEnabled,
    double? brightnessLevel,
  }) {
    return AodSettings(
      aodEnabled: aodEnabled ?? this.aodEnabled,
      use12HourClock: use12HourClock ?? this.use12HourClock,
      pixelShiftEnabled: pixelShiftEnabled ?? this.pixelShiftEnabled,
      brightnessLevel: brightnessLevel ?? this.brightnessLevel,
    );
  }
}
