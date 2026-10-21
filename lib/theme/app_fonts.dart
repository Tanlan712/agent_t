import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 各風格的特殊字體（規格 2026-10-21-ui-themes-design.md §5）。
/// google_fonts 只在第一次用到某個字體時才下載；[enabled] 為 false 時（測試）用系統字體。
abstract final class AppFonts {
  /// 由 `buildAppTheme(useGoogleFonts:)` 設定。
  static bool enabled = true;

  /// 壓縮粗體英數（Anton）：F 系列的大數字、REFUSED。
  static TextStyle condensed([TextStyle? s]) => enabled
      ? GoogleFonts.anton(textStyle: s)
      : (s ?? const TextStyle())
          .copyWith(fontFamily: 'sans-serif', fontWeight: FontWeight.w800);

  /// 等寬（JetBrains Mono）：D、F 的代碼行與倒數。
  static TextStyle mono([TextStyle? s]) => enabled
      ? GoogleFonts.jetBrainsMono(textStyle: s)
      : (s ?? const TextStyle()).copyWith(fontFamily: 'monospace');

  /// 襯線斜體數字（Cormorant Garamond）：C、E。
  static TextStyle serif([TextStyle? s]) => enabled
      ? GoogleFonts.cormorantGaramond(textStyle: s, fontStyle: FontStyle.italic)
      : (s ?? const TextStyle())
          .copyWith(fontFamily: 'serif', fontStyle: FontStyle.italic);

  /// EVA 明朝體（Noto Serif TC Black）：只在 EVA 系列使用。
  static TextStyle mincho([TextStyle? s]) => enabled
      ? GoogleFonts.notoSerifTc(textStyle: s, fontWeight: FontWeight.w900)
      : (s ?? const TextStyle())
          .copyWith(fontFamily: 'serif', fontWeight: FontWeight.w900);
}
