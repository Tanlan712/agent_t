import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/theme/app_theme.dart';

// 各組合的配色數值與對比由 palette_contrast_test.dart 檢查。
void main() {
  test('buildAppTheme 使用目前配色', () {
    final theme = buildAppTheme(useGoogleFonts: false);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.primary);
  });

  group('AppColors 別名', () {
    test('語意色別名', () {
      expect(AppColors.win, AppColors.owned);
      expect(AppColors.loss, AppColors.error);
      expect(AppColors.warn, AppColors.wishlistGold);
    });

    test('AppText.tabular 使用等寬數字', () {
      expect(AppText.tabular(null).fontFeatures,
          contains(const FontFeature.tabularFigures()));
      expect(AppText.tabular(const TextStyle(fontSize: 13)).fontSize, 13);
    });

    test('不使用 google_fonts 時退回系統字體，焦點色為 info', () {
      final t = buildAppTheme(useGoogleFonts: false);
      expect(t.textTheme.titleLarge?.fontFamily, isNot(contains('Chakra')));
      expect(t.focusColor, AppColors.info.withOpacity(0.2));
    });
  });
}
