import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/shell/app_shell.dart';
import 'package:agent_t/shell/side_nav.dart';
import 'package:agent_t/theme/app_palette.dart';
import 'package:agent_t/theme/app_style.dart';
import 'package:agent_t/theme/app_theme.dart';
import 'package:agent_t/theme/theme_ids.dart';
import 'package:agent_t/widgets/hud/hud_card.dart';
import 'package:agent_t/widgets/hud/kpi_strip.dart';

import '../app_harness.dart';
import '../shell/app_shell_test.dart' show setWidth;
import 'contrast.dart';

/// J 控制台：暖灰畫布＋白色工作台、主色按鈕、淺灰面板、反黑 KPI、麵包屑標題。
void main() {
  tearDown(AppPalette.reset);

  const choice = ThemeChoice(style: ThemeStyleId.console);

  test('預設淺色；按鈕用主色，面板與畫布上的文字對比 ≥ 4.5', () {
    expect(choice.brightness, Brightness.light);
    for (final accent in AccentId.values) {
      for (final mode in [BrightnessMode.light, BrightnessMode.dark]) {
        final p = AppPalette.resolve(ThemeChoice(
            style: ThemeStyleId.console, accent: accent, mode: mode));
        expect(p.buttonFill, isNot(p.text));
        expect(contrast(p.onButton, p.buttonFill), greaterThanOrEqualTo(4.5));
        // 反黑卡：墨色底上放 surface 色的字。
        expect(contrast(p.surface, p.text), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('ThemeData：膠囊主色按鈕、16px 卡片、20px 對話框、白色底部導覽', () {
    final t = buildAppTheme(choice: choice, useGoogleFonts: false);
    final p = t.extension<AppPalette>()!;
    expect(t.filledButtonTheme.style?.shape?.resolve({}), isA<StadiumBorder>());
    expect(
        t.filledButtonTheme.style?.backgroundColor?.resolve({}), p.buttonFill);
    expect(t.navigationBarTheme.backgroundColor, p.surface);
    expect(t.appBarTheme.backgroundColor, p.surface);
    final dialog = t.dialogTheme.shape! as RoundedRectangleBorder;
    expect(dialog.borderRadius, const BorderRadius.all(Radius.circular(20)));
    final style = t.extension<AppStyle>()!;
    expect(style.card, CardVariant.console);
    expect(style.cardRadius, 16);
    expect(style.invertsFirstKpi, isTrue);
  });

  testWidgets('面板：淺灰底、細邊、沒有陰影', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(choice: choice, useGoogleFonts: false),
        home: const Scaffold(body: PanelCard(child: Text('x')))));
    final p = AppPalette.resolve(choice);
    final box = tester.widget<AnimatedContainer>(find.descendant(
        of: find.byType(PanelCard), matching: find.byType(AnimatedContainer)));
    final d = box.decoration! as BoxDecoration;
    expect(d.color, p.surfaceHigh);
    expect(d.border, isNotNull);
    expect(d.boxShadow, isNull);
  });

  testWidgets('KPI 列第一張反黑', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(choice: choice, useGoogleFonts: false),
        home: const Scaffold(
            body: KpiStrip(tiles: [
          KpiTile(label: 'A', value: '1'),
          KpiTile(label: 'B', value: '2'),
        ]))));
    expect(find.byKey(const ValueKey('kpi-inverted')), findsOneWidget);
  });

  testWidgets('桌面：透明分組側欄＋白色工作台＋麵包屑標題，沒有分隔線', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: choice,
        home: const AppShell(
            currentRoute: '/players', title: '遇過的玩家', child: Text('內容'))));
    await tester.pumpAndSettle();
    expect(find.byType(SideNav), findsOneWidget);
    expect(find.byKey(const ValueKey('console-side-nav')), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNothing);
    final sheet =
        tester.widget<DecoratedBox>(find.byKey(const ValueKey('shell-sheet')));
    final d = sheet.decoration as BoxDecoration;
    expect(d.color, AppPalette.resolve(choice).surface);
    expect(d.borderRadius, const BorderRadius.all(Radius.circular(24)));
    final crumb =
        tester.widget<Text>(find.byKey(const ValueKey('header-breadcrumb')));
    expect(crumb.data, startsWith('AGENT T'));
    expect(find.byKey(const ValueKey('nav-indicator')), findsOneWidget);
  });

  testWidgets('手機：工作台整片白、沒有圓角', (tester) async {
    setWidth(tester, 390);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: choice,
        home: const AppShell(
            currentRoute: '/', title: '我的商店', child: Text('內容'))));
    await tester.pumpAndSettle();
    final sheet =
        tester.widget<DecoratedBox>(find.byKey(const ValueKey('shell-sheet')));
    final d = sheet.decoration as BoxDecoration;
    expect(d.borderRadius, isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
