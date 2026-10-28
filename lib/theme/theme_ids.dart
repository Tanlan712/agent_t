import 'package:flutter/material.dart';

import '../models/app_settings.dart';

/// 9 種整體風格（G Material 3 於 2026-10-28 加入）（規格 2026-10-21-ui-themes-design.md §2、§4）。
enum ThemeStyleId {
  editorial,
  neon,
  airy,
  terminal,
  dreamy,
  evaAlert,
  evaMonitor,
  evaFusion,

  /// G：Google Material Design 3（色彩由主色當種子色產生，元件用 MD3 預設外觀）。
  material;

  bool get isEva => this == evaAlert || this == evaMonitor || this == evaFusion;

  /// 明暗選「跟隨風格」時用的明暗。
  Brightness get defaultBrightness => switch (this) {
        editorial || airy || dreamy || material => Brightness.light,
        _ => Brightness.dark,
      };
}

/// [berserk]（暴走）是隱藏主色：只在 EVA 系列、設定頁解鎖後（E9）可選。
enum AccentId { red, blue, green, violet, berserk }

enum BrightnessMode { auto, dark, light }

/// 使用者目前選的主題組合。
class ThemeChoice {
  final ThemeStyleId style;
  final AccentId accent;
  final BrightnessMode mode;

  const ThemeChoice({
    this.style = ThemeStyleId.editorial,
    this.accent = AccentId.red,
    this.mode = BrightnessMode.auto,
  });

  Brightness get brightness => switch (mode) {
        BrightnessMode.auto => style.defaultBrightness,
        BrightnessMode.dark => Brightness.dark,
        BrightnessMode.light => Brightness.light,
      };

  /// 用來在切換主題時重建整棵樹。
  String get key => '${style.name}-${accent.name}-${brightness.name}';

  /// 未知字串一律退回預設值。
  factory ThemeChoice.fromSettings(AppSettings s) {
    T pick<T extends Enum>(List<T> values, String name, T fallback) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    final style =
        pick(ThemeStyleId.values, s.themeStyle, ThemeStyleId.editorial);
    var accent = pick(AccentId.values, s.themeAccent, AccentId.red);
    if (accent == AccentId.berserk && !style.isEva) accent = AccentId.red;
    return ThemeChoice(
      style: style,
      accent: accent,
      mode: pick(BrightnessMode.values, s.themeBrightness, BrightnessMode.auto),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeChoice &&
      other.style == style &&
      other.accent == accent &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(style, accent, mode);

  @override
  String toString() => 'ThemeChoice($key)';
}
