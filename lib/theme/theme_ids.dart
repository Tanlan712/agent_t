import 'package:flutter/material.dart';

import '../models/app_settings.dart';

/// 8 種整體風格（規格 2026-10-21-ui-themes-design.md §2、§4）。
enum ThemeStyleId {
  editorial,
  neon,
  airy,
  terminal,
  dreamy,
  evaAlert,
  evaMonitor,
  evaFusion;

  bool get isEva => this == evaAlert || this == evaMonitor || this == evaFusion;

  /// 明暗選「跟隨風格」時用的明暗。
  Brightness get defaultBrightness => switch (this) {
        editorial || airy || dreamy => Brightness.light,
        _ => Brightness.dark,
      };
}

enum AccentId { red, blue, green, violet }

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

    return ThemeChoice(
      style: pick(ThemeStyleId.values, s.themeStyle, ThemeStyleId.editorial),
      accent: pick(AccentId.values, s.themeAccent, AccentId.red),
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
