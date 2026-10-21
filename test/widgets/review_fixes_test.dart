import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/theme/app_theme.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud.dart';
import 'package:valorant_shop_tracker/widgets/skin_card.dart';

import '../catalog_helpers.dart';
import 'package:valorant_shop_tracker/theme/app_palette.dart';
import 'package:valorant_shop_tracker/theme/theme_ids.dart';

import '../theme/contrast.dart';

/// 最終審查（2026-10-21）指出的問題。
void main() {
  final theme = buildAppTheme(useGoogleFonts: false);

  testWidgets('內文用系統字體，不下載 Noto Sans TC（約 14MB）', (tester) async {
    final t = buildAppTheme();
    for (final s in [t.textTheme.bodyMedium, t.textTheme.labelLarge]) {
      expect(s?.fontFamily ?? '', isNot(contains('Noto')));
    }
    expect(t.textTheme.titleLarge?.fontFamilyFallback ?? const <String>[],
        isNot(contains(predicate<String>((f) => f.contains('Noto')))));
  });

  test('焦點高亮半透明，文字在高亮上仍清楚可讀', () {
    final bg = Color.alphaBlend(theme.focusColor, AppColors.surface);
    expect(contrast(AppColors.text, bg), greaterThanOrEqualTo(4.5));
  });

  test('按鈕取得焦點時有 2px info 外框', () {
    const focused = {WidgetState.focused};
    for (final style in [
      theme.filledButtonTheme.style!,
      theme.outlinedButtonTheme.style!,
      theme.textButtonTheme.style!,
    ]) {
      final side = style.side!.resolve(focused)!;
      expect(side.color, AppColors.info);
      expect(side.width, 2);
    }
  });

  testWidgets('StatusChip 文字至少 12px，所有主題下對 surface／surfaceHigh 對比 ≥ 4.5',
      (tester) async {
    addTearDown(AppPalette.reset);
    for (final style in ThemeStyleId.values) {
      for (final mode in [BrightnessMode.dark, BrightnessMode.light]) {
        final p = AppPalette.resolve(ThemeChoice(style: style, mode: mode));
        AppPalette.current = p;
        for (final color in [
          p.win,
          p.loss,
          p.warn,
          p.info,
          ...p.tier,
          ...p.party
        ]) {
          await tester.pumpWidget(MaterialApp(
              home: Scaffold(body: StatusChip(label: '隊伍 MVP', color: color))));
          final text = tester.widget<Text>(find.text('隊伍 MVP'));
          expect(text.style!.fontSize, greaterThanOrEqualTo(12));
          for (final base in [p.surface, p.surfaceHigh]) {
            final bg = Color.alphaBlend(color.withOpacity(0.15), base);
            expect(contrast(text.style!.color!, bg), greaterThanOrEqualTo(4.5),
                reason: '$style $mode $color on $base');
          }
        }
      }
    }
  });

  testWidgets('SkinCard 的漸層畫在 Ink 上，點擊回饋不被蓋住', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
            body: SizedBox(
                width: 240,
                height: 320,
                child: SkinCard(skin: odin, onTap: () {})))));
    expect(
        find.descendant(of: find.byType(SkinCard), matching: find.byType(Ink)),
        findsOneWidget);
    final inkWell = find.byType(InkWell);
    expect(find.ancestor(of: inkWell, matching: find.byType(DecoratedBox)),
        findsNothing,
        reason: '不透明的 DecoratedBox 會蓋住 InkWell 的水波與焦點');
  });

  for (final width in [719.0, 520.0, 343.0]) {
    testWidgets('KpiStrip 在 ${width.toInt()} 寬每個 tile 至少 150px',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
              body: SizedBox(
                  width: width,
                  child: KpiStrip(tiles: [
                    for (var i = 0; i < 5; i++)
                      const KpiTile(label: 'L', value: '22 小時 59 分'),
                  ])))));
      for (var i = 0; i < 5; i++) {
        expect(tester.getSize(find.byType(KpiTile).at(i)).width,
            greaterThanOrEqualTo(150));
      }
    });
  }
}
