import 'package:flutter/material.dart';

class WeightLogTheme {
  static const _seed = Color(0xff0f766e);

  static ThemeData get light => _theme(
        ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.light,
        ),
      );

  static ThemeData get dark => _theme(
        ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );

  static ThemeData _theme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
