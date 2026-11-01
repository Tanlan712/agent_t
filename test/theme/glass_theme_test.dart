import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/shell/app_shell.dart';
import 'package:agent_t/shell/side_nav.dart';
import 'package:agent_t/theme/app_palette.dart';
import 'package:agent_t/theme/app_style.dart';
import 'package:agent_t/theme/app_theme.dart';
import 'package:agent_t/theme/theme_ids.dart';
import 'package:agent_t/widgets/hud/hud_card.dart';
import 'package:agent_t/widgets/theme/style_background.dart';

import '../app_harness.dart';
import '../shell/app_shell_test.dart' show setWidth;
import 'contrast.dart';

/// H 玻璃黏土：配色、背景山景、玻璃卡片與導覽。
void main() {
  tearDown(AppPalette.reset);

  test('預設淺色；每個主色都有兩色漸層，暴走當成紅', () {
    expect(const ThemeChoice(style: ThemeStyleId.glass).brightness,
        Brightness.light);
    for (final accent in AccentId.values) {
      final p = AppPalette.resolve(
          ThemeChoice(style: ThemeStyleId.glass, accent: accent));
      expect(p.accentGradient, hasLength(2));
      expect(p.decor, hasLength(3));
      expect(p.buttonFill, p.accentGradient!.first);
    }
    expect(
        AppPalette.resolve(const ThemeChoice(
                style: ThemeStyleId.glass, accent: AccentId.berserk))
            .accentGradient,
        AppPalette.resolve(const ThemeChoice(style: ThemeStyleId.glass))
            .accentGradient);
  });

  test('漸層兩端放白字對比 ≥ 4.5', () {
    for (final accent in AccentId.values) {
      for (final mode in [BrightnessMode.light, BrightnessMode.dark]) {
        final p = AppPalette.resolve(
            ThemeChoice(style: ThemeStyleId.glass, accent: accent, mode: mode));
        for (final c in p.accentGradient!) {
          expect(contrast(p.onButton, c), greaterThanOrEqualTo(4.5),
              reason: '$accent $mode $c');
        }
      }
    }
  });

  test('背景山景（天空、地平線、太陽光暈）上 text／muted 對比仍 ≥ 4.5', () {
    for (final accent in AccentId.values) {
      for (final mode in [BrightnessMode.light, BrightnessMode.dark]) {
        final p = AppPalette.resolve(
            ThemeChoice(style: ThemeStyleId.glass, accent: accent, mode: mode));
        final scene = p.decor!;
        final a = glassGlowOpacity(p.brightness);
        for (final bg in [
          p.background,
          scene[0],
          scene[1],
          // 太陽光暈最亮處疊在地平線色上。
          Color.alphaBlend(scene[2].withOpacity(a), scene[1]),
        ]) {
          expect(contrast(p.text, bg), greaterThanOrEqualTo(4.5),
              reason: 'text $accent $mode $bg');
          if (bg != Color.alphaBlend(scene[2].withOpacity(a), scene[1])) {
            expect(contrast(p.muted, bg), greaterThanOrEqualTo(4.5),
                reason: 'muted $accent $mode $bg');
          }
        }
      }
    }
  });

  test('ThemeData：膠囊按鈕、24px 卡片、透明底部導覽', () {
    final t = buildAppTheme(
        choice: const ThemeChoice(style: ThemeStyleId.glass),
        useGoogleFonts: false);
    expect(t.filledButtonTheme.style?.shape?.resolve({}), isA<StadiumBorder>());
    expect(t.navigationBarTheme.backgroundColor, Colors.transparent);
    final card = t.cardTheme.shape! as RoundedRectangleBorder;
    expect(card.borderRadius, const BorderRadius.all(Radius.circular(24)));
    expect(t.extension<AppStyle>()!.card, CardVariant.glass);
  });

  testWidgets('玻璃卡片：漸層底、亮邊、投影、24px 圓角', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(
            choice: const ThemeChoice(style: ThemeStyleId.glass),
            useGoogleFonts: false),
        home: const Scaffold(body: PanelCard(child: Text('x')))));
    final box = tester.widget<AnimatedContainer>(find.descendant(
        of: find.byType(PanelCard), matching: find.byType(AnimatedContainer)));
    final d = box.decoration! as BoxDecoration;
    expect(d.gradient, isA<LinearGradient>());
    expect(d.border, isNotNull);
    expect(d.boxShadow, isNotEmpty);
    expect(d.borderRadius, const BorderRadius.all(Radius.circular(24)));
  });

  testWidgets('桌面：頂部玻璃膠囊導覽，選中項目是漸層膠囊，沒有側欄與分隔線', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(style: ThemeStyleId.glass),
        home: const AppShell(
            currentRoute: '/players', title: '遇過的玩家', child: Text('內容'))));
    await tester.pumpAndSettle();
    expect(find.byType(SideNav), findsNothing);
    expect(find.byKey(const ValueKey('glass-top-nav')), findsOneWidget);
    expect(find.byKey(const ValueKey('bg-glass')), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNothing);
    final pill = tester
        .widget<DecoratedBox>(find.byKey(const ValueKey('nav-indicator')));
    expect((pill.decoration as BoxDecoration).gradient, isA<LinearGradient>());
  });

  testWidgets('手機：底部導覽是浮動玻璃膠囊', (tester) async {
    setWidth(tester, 390);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(style: ThemeStyleId.glass),
        home: const AppShell(
            currentRoute: '/', title: '我的商店', child: Text('內容'))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bottom-glass')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
