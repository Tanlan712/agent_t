import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/shell/app_shell.dart';
import 'package:agent_t/shell/side_nav.dart';
import 'package:agent_t/theme/app_palette.dart';
import 'package:agent_t/theme/app_style.dart';
import 'package:agent_t/theme/app_theme.dart';
import 'package:agent_t/theme/theme_ids.dart';
import 'package:agent_t/widgets/hud/hud_card.dart';

import '../app_harness.dart';
import '../shell/app_shell_test.dart' show setWidth;

/// G Material 3：MD3 色彩系統與元件外觀。
void main() {
  tearDown(AppPalette.reset);

  test('預設淺色；配色取自以主色為種子的 MD3 ColorScheme', () {
    const c = ThemeChoice(style: ThemeStyleId.material);
    expect(c.brightness, Brightness.light);
    final s = materialScheme(c);
    final p = AppPalette.resolve(c);
    expect(p.background, s.surface);
    expect(p.surface, s.surfaceContainer);
    expect(p.primary, s.primary);
    expect(p.onButton, s.onPrimary);
    expect(p.text, s.onSurface);
  });

  test('主色改變種子色；暴走當成紅', () {
    ColorScheme of(AccentId a) =>
        materialScheme(ThemeChoice(style: ThemeStyleId.material, accent: a));
    expect(of(AccentId.blue).primary, isNot(of(AccentId.red).primary));
    expect(of(AccentId.berserk).primary, of(AccentId.red).primary);
  });

  test('ThemeData 用完整 MD3 配色與預設元件形狀，不用 Chakra Petch', () {
    for (final mode in [BrightnessMode.light, BrightnessMode.dark]) {
      final c = ThemeChoice(style: ThemeStyleId.material, mode: mode);
      final t = buildAppTheme(choice: c);
      final s = materialScheme(c);
      expect(t.useMaterial3, isTrue);
      expect(t.colorScheme.secondaryContainer, s.secondaryContainer);
      expect(t.colorScheme.tertiary, s.tertiary);
      expect(t.scaffoldBackgroundColor, s.surface);
      // 按鈕沿用 MD3 預設膠囊形，不套其他風格的 4px 直角。
      expect(t.filledButtonTheme.style?.shape, isNull);
      expect(
          t.textTheme.titleLarge?.fontFamily ?? '', isNot(contains('Chakra')));
      expect(t.extension<AppStyle>()!.card, CardVariant.material);
    }
  });

  testWidgets('桌面：MD3 導覽抽屜，選中項目是 secondaryContainer 膠囊', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(style: ThemeStyleId.material),
        home: const AppShell(
            currentRoute: '/players', title: '遇過的玩家', child: Text('內容'))));
    await tester.pumpAndSettle();
    expect(find.byType(SideNav), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNothing);
    final pill =
        tester.widget<Material>(find.byKey(const ValueKey('nav-indicator')));
    final scheme =
        materialScheme(const ThemeChoice(style: ThemeStyleId.material));
    expect(pill.color, scheme.secondaryContainer);
    expect(pill.shape, isA<StadiumBorder>());
  });

  testWidgets('卡片無邊框、12px 圓角', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(
            choice: const ThemeChoice(style: ThemeStyleId.material),
            useGoogleFonts: false),
        home: const Scaffold(body: PanelCard(child: Text('x')))));
    final box = tester.widget<AnimatedContainer>(find.descendant(
        of: find.byType(PanelCard), matching: find.byType(AnimatedContainer)));
    final d = box.decoration! as BoxDecoration;
    expect(d.border, isNull);
    expect(d.borderRadius, const BorderRadius.all(Radius.circular(12)));
  });
}
