import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/shell/app_shell.dart';
import 'package:agent_t/shell/side_nav.dart';
import 'package:agent_t/theme/app_palette.dart';
import 'package:agent_t/theme/app_style.dart';
import 'package:agent_t/theme/app_theme.dart';
import 'package:agent_t/theme/theme_ids.dart';
import 'package:agent_t/widgets/hud/kpi_strip.dart';
import 'package:agent_t/widgets/theme/theme_reveal.dart';

import '../app_harness.dart';
import '../shell/app_shell_test.dart' show setWidth;
import 'contrast.dart';

/// I 極簡儀表板：墨色配色、膠囊導覽、反黑 KPI、圓形擴散深淺色切換。
void main() {
  tearDown(AppPalette.reset);

  const choice = ThemeChoice(style: ThemeStyleId.dashboard);

  test('預設淺色；按鈕是墨色（不是主色），對比 ≥ 4.5', () {
    expect(choice.brightness, Brightness.light);
    for (final accent in AccentId.values) {
      for (final mode in [BrightnessMode.light, BrightnessMode.dark]) {
        final p = AppPalette.resolve(ThemeChoice(
            style: ThemeStyleId.dashboard, accent: accent, mode: mode));
        expect(p.buttonFill, p.text);
        expect(p.onButton, p.surface);
        expect(contrast(p.onButton, p.buttonFill), greaterThanOrEqualTo(4.5));
        for (final bg in [p.background, p.surface, p.surfaceHigh]) {
          expect(contrast(p.text, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(p.muted, bg), greaterThanOrEqualTo(4.5),
              reason: '$accent $mode muted on $bg');
        }
      }
    }
  });

  test('反黑 KPI 卡上的勝負色（取另一個明暗）對比 ≥ 3', () {
    for (final mode in [BrightnessMode.light, BrightnessMode.dark]) {
      final p = AppPalette.resolve(
          ThemeChoice(style: ThemeStyleId.dashboard, mode: mode));
      final o = AppPalette.resolve(ThemeChoice(
          style: ThemeStyleId.dashboard,
          mode: mode == BrightnessMode.light
              ? BrightnessMode.dark
              : BrightnessMode.light));
      for (final c in [o.win, o.loss]) {
        expect(contrast(c, p.text), greaterThanOrEqualTo(3), reason: '$mode');
      }
    }
  });

  test('ThemeData：膠囊按鈕、20px 卡片、透明底部導覽＋墨色指示', () {
    final t = buildAppTheme(choice: choice, useGoogleFonts: false);
    final p = t.extension<AppPalette>()!;
    expect(t.filledButtonTheme.style?.shape?.resolve({}), isA<StadiumBorder>());
    expect(t.filledButtonTheme.style?.backgroundColor?.resolve({}), p.text);
    expect(t.navigationBarTheme.backgroundColor, Colors.transparent);
    expect(t.navigationBarTheme.indicatorColor, p.buttonFill);
    final style = t.extension<AppStyle>()!;
    expect(style.card, CardVariant.dashboard);
    expect(style.nav, NavLayout.topPills);
    expect(style.cardRadius, 20);
  });

  testWidgets('KPI 列第一張反黑，其他是白卡；變化放在膠囊標章', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(choice: choice, useGoogleFonts: false),
        home: const Scaffold(
            body: KpiStrip(tiles: [
          KpiTile(label: 'VP', value: '1,200', delta: '+5%', up: true),
          KpiTile(label: '勝率', value: '52%'),
        ]))));
    expect(find.byKey(const ValueKey('kpi-inverted')), findsOneWidget);
    expect(find.byKey(const ValueKey('kpi-delta-pill')), findsOneWidget);
    final inverted =
        tester.widget<DecoratedBox>(find.byKey(const ValueKey('kpi-inverted')));
    final p = AppPalette.resolve(choice);
    expect((inverted.decoration as BoxDecoration).color, p.text);
  });

  testWidgets('桌面：頂部膠囊導覽，沒有側欄，選中項目是墨色膠囊', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: choice,
        home: const AppShell(
            currentRoute: '/matches', title: '對戰紀錄', child: Text('內容'))));
    await tester.pumpAndSettle();
    expect(find.byType(SideNav), findsNothing);
    expect(find.byKey(const ValueKey('pill-nav')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme-reveal-toggle')), findsOneWidget);
    final pill = tester
        .widget<AnimatedContainer>(find.byKey(const ValueKey('nav-indicator')));
    expect((pill.decoration as BoxDecoration).color,
        AppPalette.resolve(choice).buttonFill);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('nav-indicator')),
            matching: find.text('對戰紀錄')),
        findsOneWidget);
  });

  testWidgets('資料庫頁面收在「更多」，選中時膠囊顯示該頁名稱', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: choice,
        home: const AppShell(
            currentRoute: '/maps', title: '地圖', child: Text('內容'))));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('nav-group-more')),
            matching: find.text('地圖')),
        findsOneWidget);
  });

  testWidgets('手機：白色浮動膠囊底部導覽，上方列有深淺色切換', (tester) async {
    setWidth(tester, 390);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: choice,
        home: const AppShell(
            currentRoute: '/', title: '我的商店', child: Text('內容'))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bottom-dashboard')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme-reveal-toggle')), findsOneWidget);
  });

  testWidgets('切換鈕：改成深色並存進設定（測試環境直接切換）', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    await h.settings.setTheme(style: ThemeStyleId.dashboard.name);
    await tester.pumpWidget(h.wrap(
        useSettingsTheme: true,
        home: const AppShell(
            currentRoute: '/', title: '我的商店', child: Text('內容'))));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeReveal), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme-reveal-toggle')));
    await tester.pumpAndSettle();
    expect(h.settings.settings.themeBrightness, BrightnessMode.dark.name);
    expect(
        Theme.of(tester.element(find.text('內容'))).brightness, Brightness.dark);
    expect(find.byKey(const ValueKey('theme-reveal-overlay')), findsNothing);
  });
}
