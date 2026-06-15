import 'package:flutter/material.dart';
import 'trace_colors.dart';
import 'trace_typography.dart';

ThemeData buildRetroTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: TraceColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: TraceColors.primary,
    secondary: TraceColors.secondary,
    surface: TraceColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: TraceColors.background,
    textTheme: TraceTypography.buildTextTheme(),
    cardTheme: CardThemeData(
      color: TraceColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TraceColors.primary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
  );
}
