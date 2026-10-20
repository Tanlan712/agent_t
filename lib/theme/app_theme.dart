import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  /// 資訊、連結、進行中、鍵盤焦點（對 surface 7.3）。
  static const info = Color(0xFF38BDF8);

  /// 語意別名（MASTER.md 第 1 節）：勝利／已擁有、落敗／錯誤、警示。
  static const win = owned;
  static const loss = error;
  static const warn = wishlistGold;

  /// 對戰計分板的組隊標記；同一組隊用同一個顏色。
  static const partyColors = [
    Color(0xFF60A5FA),
    Color(0xFFF472B6),
    Color(0xFFFBBF24),
    Color(0xFF34D399),
    Color(0xFFA78BFA),
  ];
}

const _radius = BorderRadius.all(Radius.circular(4));

/// 鍵盤焦點：2px info 外框（MASTER.md 第 6 節）；其餘狀態用 [normal]。
WidgetStateProperty<BorderSide?> _focusSide([BorderSide? normal]) =>
    WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.focused)
            ? const BorderSide(color: AppColors.info, width: 2)
            : normal);

/// 共用文字樣式（MASTER.md 第 2 節）。
abstract final class AppText {
  /// 數字欄位等寬，讓 ACS、K/D、比分、價格對齊。
  static TextStyle tabular(TextStyle? base) => (base ?? const TextStyle())
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// KPI 大數字。
  static TextStyle kpi(BuildContext context) =>
      tabular(Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.text));

  static const label =
      TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 0.4);
}

/// 標題用 Chakra Petch、內文用 Noto Sans TC（中文退回 Noto Sans TC）。
/// [useGoogleFonts] 為 false 時用系統字體（測試、或字體載入失敗時）。
TextTheme _textTheme(bool useGoogleFonts) {
  final base = ThemeData(brightness: Brightness.dark).textTheme;
  if (!useGoogleFonts) return base;
  final body = GoogleFonts.notoSansTcTextTheme(base);
  final cjk = GoogleFonts.notoSansTc().fontFamily;
  TextStyle? head(TextStyle? s) => GoogleFonts.chakraPetch(textStyle: s)
      .copyWith(fontFamilyFallback: [if (cjk != null) cjk]);
  return body.copyWith(
    displayLarge: head(body.displayLarge),
    displayMedium: head(body.displayMedium),
    displaySmall: head(body.displaySmall),
    headlineLarge: head(body.headlineLarge),
    headlineMedium: head(body.headlineMedium),
    headlineSmall: head(body.headlineSmall),
    titleLarge: head(body.titleLarge),
  );
}

ThemeData buildAppTheme({bool useGoogleFonts = true}) {
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
    textTheme: _textTheme(useGoogleFonts),
    // 半透明，讓焦點列上的文字仍清楚可讀（對比 ≥ 4.5）。
    focusColor: AppColors.info.withOpacity(0.2),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.surfaceHigh,
      side: BorderSide(color: AppColors.outline),
      shape: RoundedRectangleBorder(borderRadius: _radius),
      labelStyle: TextStyle(color: AppColors.text, fontSize: 12),
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowHeight: 36,
      dataRowMinHeight: 36,
      headingTextStyle: AppText.label,
      dividerThickness: 0.5,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: _radius,
          border: Border.fromBorderSide(BorderSide(color: AppColors.outline))),
      textStyle: TextStyle(color: AppColors.text, fontSize: 12),
      waitDuration: Duration(milliseconds: 300),
    ),
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    dividerColor: AppColors.outline,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    // 戰術 HUD：所有卡片右上角 8px 斜切（MASTER.md 第 3 節）。
    cardTheme: const CardTheme(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: BeveledRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(8)),
        side: BorderSide(color: AppColors.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.buttonRed,
        foregroundColor: AppColors.onPrimary,
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ).copyWith(side: _focusSide()),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ).copyWith(side: _focusSide(const BorderSide(color: AppColors.outline))),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary)
          .copyWith(side: _focusSide()),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      border: OutlineInputBorder(
          borderRadius: _radius, borderSide: BorderSide.none),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.surfaceHigh,
      selectedIconTheme: IconThemeData(color: AppColors.primary),
      unselectedIconTheme: IconThemeData(color: AppColors.muted),
      selectedLabelTextStyle:
          TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: AppColors.muted),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.surface),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: AppColors.text),
    ),
  );
}
