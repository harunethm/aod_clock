import 'package:flutter/material.dart';

/// Only a dark theme exists — this app has no light-mode use case, and the
/// AOD screen itself never reads the theme at all (it hardcodes pure black,
/// see `AodDisplayScreen`) since that's what actually saves OLED power.
class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: Colors.black,
  );
}
