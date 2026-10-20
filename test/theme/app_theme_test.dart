import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/tier.dart';
import 'package:valorant_shop_tracker/theme/app_theme.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.red / 255) +
    0.7152 * _channel(c.green / 255) +
    0.0722 * _channel(c.blue / 255);

/// WCAG 2.1 對比度。
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  test('tokens 數值', () {
    expect(AppColors.background, const Color(0xFF0F1923));
    expect(AppColors.primary, const Color(0xFFFF4655));
    expect(AppColors.buttonRed, const Color(0xFFD7263D));
    expect(AppColors.surface, const Color(0xFF1A2530));
  });

  test('buildAppTheme 為深色', () {
    final theme = buildAppTheme(useGoogleFonts: false);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.primary);
  });

  test('對比度 ≥ 4.5', () {
    for (final tier in Tier.values) {
      expect(contrast(tier.color, AppColors.surface), greaterThanOrEqualTo(4.5),
          reason: tier.devName);
    }
    expect(
        contrast(AppColors.text, AppColors.surface), greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.muted, AppColors.surface),
        greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.onPrimary, AppColors.buttonRed),
        greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.primary, AppColors.background),
        greaterThanOrEqualTo(4.5));
  });

  group('戰術 HUD tokens', () {
    test('語意色與別名', () {
      expect(AppColors.info, const Color(0xFF38BDF8));
      expect(AppColors.win, AppColors.owned);
      expect(AppColors.loss, AppColors.error);
      expect(AppColors.warn, AppColors.wishlistGold);
      for (final c in [
        AppColors.info,
        AppColors.win,
        AppColors.loss,
        AppColors.warn,
      ]) {
        expect(contrast(c, AppColors.surface), greaterThanOrEqualTo(4.5));
      }
    });

    test('AppText.tabular 使用等寬數字', () {
      expect(AppText.tabular(null).fontFeatures,
          contains(const FontFeature.tabularFigures()));
      expect(AppText.tabular(const TextStyle(fontSize: 13)).fontSize, 13);
    });

    test('不使用 google_fonts 時退回系統字體，焦點色為 info', () {
      final t = buildAppTheme(useGoogleFonts: false);
      expect(t.textTheme.titleLarge?.fontFamily, isNot(contains('Chakra')));
      expect(t.focusColor, AppColors.info);
    });
  });
}
