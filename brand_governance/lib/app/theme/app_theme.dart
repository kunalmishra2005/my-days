import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const deepIndigo = Color(0xFF2A1E5C);
  static const coral = Color(0xFFFF6B5B);
  static const softWhite = Color(0xFFF8F6FF);

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: deepIndigo,
      primary: deepIndigo,
      secondary: coral,
      surface: softWhite,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: softWhite,
    textTheme: Typography.material2021().black.apply(
      bodyColor: deepIndigo.withValues(alpha: 0.88),
      displayColor: deepIndigo,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: deepIndigo.withValues(alpha: 0.08)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: deepIndigo.withValues(alpha: 0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: deepIndigo.withValues(alpha: 0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: deepIndigo, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.white,
      selectedIconTheme: const IconThemeData(color: deepIndigo),
      unselectedIconTheme: IconThemeData(
        color: deepIndigo.withValues(alpha: 0.58),
      ),
      selectedLabelTextStyle: const TextStyle(
        color: deepIndigo,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: deepIndigo.withValues(alpha: 0.65),
      ),
      indicatorColor: deepIndigo.withValues(alpha: 0.09),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: deepIndigo.withValues(alpha: 0.1),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
