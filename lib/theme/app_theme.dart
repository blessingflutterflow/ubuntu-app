import 'package:flutter/material.dart';

class UbuntuColors {
  static const canvas     = Color(0xFFFFFFFF);
  static const surface    = Color(0xFFF5F5F5);
  static const input      = Color(0xFFEFEFEF);
  static const divider    = Color(0xFFDBDBDB);
  static const ink        = Color(0xFF222222);
  static const muted      = Color(0xFF8E8E8E);
  static const primary    = Color(0xFF00C853);
  static const primaryDim = Color(0xFF00A846);
  static const accent     = Color(0xFFFFD60A);
  static const liked      = Color(0xFFED4956);
  static const badge      = Color(0xFFED4956);
}

const List<Color> storyGradientColors = [
  Color(0xFFFFA000),
  Color(0xFFFFD60A),
  Color(0xFF69F0AE),
  Color(0xFF00C853),
  Color(0xFFFFA000),
];

class UbuntuText {
  static const wordmark  = TextStyle(fontWeight: FontWeight.w700, fontSize: 24, letterSpacing: -0.5);
  static const username  = TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.28, letterSpacing: -0.15);
  static const body      = TextStyle(fontWeight: FontWeight.w400, fontSize: 14, height: 1.35, letterSpacing: -0.1);
  static const counter   = TextStyle(fontWeight: FontWeight.w700, fontSize: 13);
  static const timestamp = TextStyle(fontWeight: FontWeight.w400, fontSize: 11, height: 1.27);
  static const storyLabel = TextStyle(fontWeight: FontWeight.w400, fontSize: 12);
}

ThemeData ubuntuTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary:        UbuntuColors.primary,
      onPrimary:      Colors.white,
      surface:        UbuntuColors.canvas,
      onSurface:      UbuntuColors.ink,
      surfaceContainerHighest: UbuntuColors.input,
      outline:        UbuntuColors.divider,
      error:          UbuntuColors.liked,
    ),
    scaffoldBackgroundColor: UbuntuColors.canvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: UbuntuColors.canvas,
      foregroundColor: UbuntuColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: UbuntuColors.divider, thickness: 0.5, space: 0),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: UbuntuColors.canvas,
      selectedItemColor: UbuntuColors.ink,
      unselectedItemColor: UbuntuColors.muted,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyMedium: UbuntuText.body,
    ),
    fontFamily: null,
  );
}
