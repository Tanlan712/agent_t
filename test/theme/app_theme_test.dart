import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/theme/app_palette.dart';
import 'package:valorant_shop_tracker/theme/app_style.dart';
import 'package:valorant_shop_tracker/theme/app_theme.dart';
import 'package:valorant_shop_tracker/theme/theme_ids.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud_card.dart';

import '../app_harness.dart';

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

  group('主題組合', () {
    tearDown(AppPalette.reset);

    test('預設主題是 A 淺色', () {
      final t = buildAppTheme(useGoogleFonts: false);
      expect(t.brightness, Brightness.light);
      expect(t.colorScheme.brightness, Brightness.light);
      expect(t.extension<AppStyle>()!.id, ThemeStyleId.editorial);
      expect(t.extension<AppPalette>()!.background, const Color(0xFFF5F5F3));
    });

    test('每個組合都有兩個 extension，且 AppColors 跟著切換', () {
      for (final style in ThemeStyleId.values) {
        for (final accent in AccentId.values) {
          for (final mode in BrightnessMode.values) {
            final c = ThemeChoice(style: style, accent: accent, mode: mode);
            final t = buildAppTheme(choice: c, useGoogleFonts: false);
            expect(t.extension<AppStyle>()!.id, style);
            expect(t.extension<AppPalette>()!.surface, AppColors.surface);
            expect(t.brightness, c.brightness);
          }
        }
      }
    });

    test('setCurrent: false 不改動 AppPalette.current', () {
      final before = AppPalette.current;
      buildAppTheme(
          choice: const ThemeChoice(style: ThemeStyleId.terminal),
          useGoogleFonts: false,
          setCurrent: false);
      expect(AppPalette.current, same(before));
    });

    test('AppStyle 的值（規格 §4.1）', () {
      expect(AppStyle.of(ThemeStyleId.editorial).nav, NavLayout.topMinimalMenu);
      expect(AppStyle.of(ThemeStyleId.editorial).headerTitleSize, 40);
      expect(AppStyle.of(ThemeStyleId.airy).contentMaxWidth, 1080);
      expect(AppStyle.of(ThemeStyleId.terminal).tileWidthFactor, 0.85);
      expect(AppStyle.of(ThemeStyleId.dreamy).snapToHalves, isTrue);
      expect(AppStyle.of(ThemeStyleId.neon).cardRadius, 10);
      expect(AppStyle.of(ThemeStyleId.evaMonitor).card, CardVariant.evaBracket);
      expect(AppStyle.of(ThemeStyleId.evaFusion).kpi, KpiVariant.evaNumerals);
    });

    testWidgets('停在頁面時切換主題，卡片改用新配色', (tester) async {
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(
          useSettingsTheme: true,
          home: const Scaffold(body: PanelCard(child: Text('x')))));
      await h.settings.setTheme(style: 'terminal', brightness: 'dark');
      await tester.pumpAndSettle();
      final box = tester.widget<AnimatedContainer>(find.descendant(
          of: find.byType(PanelCard),
          matching: find.byType(AnimatedContainer)));
      final expected = AppPalette.resolve(const ThemeChoice(
              style: ThemeStyleId.terminal, mode: BrightnessMode.dark))
          .surface;
      expect((box.decoration as BoxDecoration).color, expected);
    });

    testWidgets('切換主題時保留頁面堆疊', (tester) async {
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(
          useSettingsTheme: true,
          home: Builder(
              builder: (c) => TextButton(
                  onPressed: () => Navigator.push(
                      c,
                      MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(body: Text('第二頁')))),
                  child: const Text('開啟')))));
      await tester.tap(find.text('開啟'));
      await tester.pumpAndSettle();
      await h.settings.setTheme(style: 'neon');
      await tester.pumpAndSettle();
      expect(find.text('第二頁'), findsOneWidget);
      expect(
          AppColors.surface,
          AppPalette.resolve(const ThemeChoice(style: ThemeStyleId.neon))
              .surface);
    });
  });
}
