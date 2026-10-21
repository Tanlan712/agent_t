import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

/// 目前主題的色彩；讀 [AppPalette.current]（由 [buildAppTheme] 設定）。
/// 名稱沿用改版前，呼叫端不用改。
abstract final class AppColors {
  static Color get background => AppPalette.current.background;
  static Color get surface => AppPalette.current.surface;
  static Color get surfaceHigh => AppPalette.current.surfaceHigh;
  static Color get outline => AppPalette.current.outline;

  /// 文字、圖示、選中標示用的主色。
  static Color get primary => AppPalette.current.primary;

  /// 主要按鈕的底色與上面的文字色。
  static Color get buttonRed => AppPalette.current.buttonFill;
  static Color get onPrimary => AppPalette.current.onButton;
  static Color get text => AppPalette.current.text;
  static Color get muted => AppPalette.current.muted;
  static Color get error => AppPalette.current.loss;
  static Color get wishlistGold => AppPalette.current.warn;
  static Color get owned => AppPalette.current.win;

  /// 資訊、連結、進行中、鍵盤焦點。
  static Color get info => AppPalette.current.info;

  /// 語意別名（MASTER.md 第 1 節）：勝利／已擁有、落敗／錯誤、警示。
  static Color get win => AppPalette.current.win;
  static Color get loss => AppPalette.current.loss;
  static Color get warn => AppPalette.current.warn;

  /// 對戰計分板的組隊標記；同一組隊用同一個顏色。
  static List<Color> get partyColors => AppPalette.current.party;
}

const _radius = BorderRadius.all(Radius.circular(4));

/// 圓角（Bento 改版）。
abstract final class AppRadius {
  static const double card = 12;
}

/// 鍵盤焦點：2px info 外框（MASTER.md 第 6 節）；其餘狀態用 [normal]。
WidgetStateProperty<BorderSide?> _focusSide([BorderSide? normal]) =>
    WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.focused)
            ? BorderSide(color: AppColors.info, width: 2)
            : normal);

/// 共用文字樣式（MASTER.md 第 2 節）。
abstract final class AppText {
  /// 數字欄位等寬，讓 ACS、K/D、比分、價格對齊。
  static TextStyle tabular(TextStyle? base) => (base ?? const TextStyle())
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// KPI 大數字。
  static TextStyle kpi(BuildContext context) =>
      tabular(Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text));

  static TextStyle get label =>
      TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 0.4);
}

/// 標題用 Chakra Petch；內文與中文用系統字體（Noto Sans TC 約 14MB，使用者 2026-10-21 決定不下載）。
/// [useGoogleFonts] 為 false 時用系統字體（測試、或字體載入失敗時）。
TextTheme _textTheme(bool useGoogleFonts) {
  final base = ThemeData(brightness: Brightness.dark).textTheme;
  if (!useGoogleFonts) return base;
  final body = base;
  TextStyle? head(TextStyle? s) => GoogleFonts.chakraPetch(textStyle: s);
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
  final scheme = ColorScheme.dark(
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
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHigh,
      side: BorderSide(color: AppColors.outline),
      shape: const RoundedRectangleBorder(borderRadius: _radius),
      labelStyle: TextStyle(color: AppColors.text, fontSize: 12),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowHeight: 36,
      dataRowMinHeight: 36,
      headingTextStyle: AppText.label,
      dividerThickness: 0.5,
    ),
    tooltipTheme: TooltipThemeData(
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
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    // Bento：所有卡片 12px 圓角、細邊框。
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
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
      ).copyWith(side: _focusSide(BorderSide(color: AppColors.outline))),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary)
          .copyWith(side: _focusSide()),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      border: const OutlineInputBorder(
          borderRadius: _radius, borderSide: BorderSide.none),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.surfaceHigh,
      selectedIconTheme: IconThemeData(color: AppColors.primary),
      unselectedIconTheme: IconThemeData(color: AppColors.muted),
      selectedLabelTextStyle:
          TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: AppColors.muted),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: AppColors.surface),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: AppColors.text),
    ),
  );
}
