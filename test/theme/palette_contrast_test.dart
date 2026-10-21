import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/app_settings.dart';
import 'package:valorant_shop_tracker/theme/app_palette.dart';
import 'package:valorant_shop_tracker/theme/app_theme.dart';
import 'package:valorant_shop_tracker/theme/theme_ids.dart';

import 'contrast.dart';

/// 規格 §3.4：每個（風格 × 主色 × 明暗）組合的對比。
void main() {
  for (final style in ThemeStyleId.values) {
    for (final accent in AccentId.values) {
      for (final mode in [BrightnessMode.dark, BrightnessMode.light]) {
        final c = ThemeChoice(style: style, accent: accent, mode: mode);
        test('$style $accent $mode 對比', () {
          final p = AppPalette.resolve(c);
          final bgs = [p.background, p.surface, p.surfaceHigh];
          for (final fg in [
            p.text,
            p.muted,
            p.win,
            p.loss,
            p.warn,
            p.info,
            ...p.tier,
            ...p.party,
            if (p.frame != null) p.frame!,
          ]) {
            for (final bg in bgs) {
              expect(contrast(fg, bg), greaterThanOrEqualTo(4.5),
                  reason: '$fg on $bg');
            }
          }
          expect(contrast(p.primary, p.background), greaterThanOrEqualTo(4.5));
          expect(contrast(p.primary, p.surface), greaterThanOrEqualTo(4.5));
          expect(contrast(p.primary, p.surfaceHigh),
              greaterThanOrEqualTo(style.isEva ? 4.5 : 3.0));
          expect(contrast(p.onButton, p.buttonFill), greaterThanOrEqualTo(4.5));
          expect(p.brightness,
              mode == BrightnessMode.dark ? Brightness.dark : Brightness.light);
        });
      }
    }
  }

  test('預設是 A 淺色', () {
    expect(AppPalette.resolve(const ThemeChoice()).background,
        const Color(0xFFF5F5F3));
    expect(const ThemeChoice().brightness, Brightness.light);
  });

  test('auto 依風格預設明暗', () {
    expect(const ThemeChoice(style: ThemeStyleId.neon).brightness,
        Brightness.dark);
    expect(const ThemeChoice(style: ThemeStyleId.airy).brightness,
        Brightness.light);
  });

  test('F3 中性色同 F2', () {
    for (final mode in [BrightnessMode.dark, BrightnessMode.light]) {
      final f2 = AppPalette.resolve(
          ThemeChoice(style: ThemeStyleId.evaMonitor, mode: mode));
      final f3 = AppPalette.resolve(
          ThemeChoice(style: ThemeStyleId.evaFusion, mode: mode));
      expect(f3.background, f2.background);
      expect(f3.frame, f2.frame);
    }
  });

  test('fromSettings 遇到未知字串退回預設', () {
    final c = ThemeChoice.fromSettings(const AppSettings(
        themeStyle: 'bogus', themeAccent: 'x', themeBrightness: 'y'));
    expect(c.style, ThemeStyleId.editorial);
    expect(c.accent, AccentId.red);
    expect(c.mode, BrightnessMode.auto);
  });

  test('fromSettings 讀到合法值', () {
    final c = ThemeChoice.fromSettings(const AppSettings(
        themeStyle: 'evaFusion', themeAccent: 'green', themeBrightness: 'light'));
    expect(c.style, ThemeStyleId.evaFusion);
    expect(c.accent, AccentId.green);
    expect(c.mode, BrightnessMode.light);
  });

  test('reset 後 AppColors 讀預設配色', () {
    AppPalette.current = AppPalette.resolve(
        const ThemeChoice(style: ThemeStyleId.terminal));
    AppPalette.reset();
    expect(AppColors.primary, AppPalette.resolve(const ThemeChoice()).primary);
  });
}
