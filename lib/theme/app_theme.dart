import 'package:flutter/material.dart';

/// VALORANT 風格深色主題的色彩 tokens。
abstract final class AppColors {
  static const background = Color(0xFF0F1923);
  static const surface = Color(0xFF1A2530);
  static const surfaceHigh = Color(0xFF243240);
  static const outline = Color(0xFF2F3D4B);

  /// 文字、圖示、選中標示用的品牌紅（在背景上對比 5.29）。
  static const primary = Color(0xFFFF4655);

  /// 按鈕底色：白字在 #FF4655 上只有 3.36，改用較深的紅（4.96）。
  static const buttonRed = Color(0xFFD7263D);
  static const onPrimary = Color(0xFFFFFFFF);
  static const text = Color(0xFFECE8E1);
  static const muted = Color(0xFF9AA6B2);
  static const error = Color(0xFFFF6B6B);
  static const wishlistGold = Color(0xFFFFC107);
  static const owned = Color(0xFF4ADE80);
}

const _radius = BorderRadius.all(Radius.circular(4));

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.primary,
    onSecondary: AppColors.onPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerHighest: AppColors.surfaceHigh,
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainer: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainerLowest: AppColors.background,
    primaryContainer: AppColors.buttonRed,
    onPrimaryContainer: AppColors.onPrimary,
    secondaryContainer: AppColors.surfaceHigh,
    onSecondaryContainer: AppColors.text,
    errorContainer: Color(0xFF5C1F24),
    onErrorContainer: AppColors.text,
    error: AppColors.error,
    outline: AppColors.outline,
    outlineVariant: AppColors.outline,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    dividerColor: AppColors.outline,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: const CardTheme(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: _radius,
        side: BorderSide(color: AppColors.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.buttonRed,
        foregroundColor: AppColors.onPrimary,
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.outline),
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      border: OutlineInputBorder(borderRadius: _radius, borderSide: BorderSide.none),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.surfaceHigh,
      selectedIconTheme: IconThemeData(color: AppColors.primary),
      unselectedIconTheme: IconThemeData(color: AppColors.muted),
      selectedLabelTextStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: AppColors.muted),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.surface),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: AppColors.text),
    ),
  );
}
