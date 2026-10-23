import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/shell/app_shell.dart';
import 'package:agent_t/theme/app_fonts.dart';
import 'package:agent_t/theme/app_palette.dart';
import 'package:agent_t/theme/theme_ids.dart';
import 'package:agent_t/widgets/theme/style_background.dart';

import '../app_harness.dart';
import '../shell/app_shell_test.dart' show setWidth;
import '../theme/contrast.dart';

/// 規格 §4.2：A～E 的背景；§5：字體。
void main() {
  Future<void> pumpShell(WidgetTester tester, ThemeStyleId style,
      {bool reduceMotion = false}) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: ThemeChoice(style: style),
        home: MediaQuery(
          data: MediaQueryData(
              size: const Size(1440, 900), disableAnimations: reduceMotion),
          child: const AppShell(
              currentRoute: '/', title: '我的商店', child: Text('內容')),
        )));
  }

  for (final (style, key) in [
    (ThemeStyleId.neon, 'bg-neon'),
    (ThemeStyleId.terminal, 'bg-terminal'),
    (ThemeStyleId.dreamy, 'bg-dreamy'),
  ]) {
    testWidgets('$style 有背景 $key', (tester) async {
      await pumpShell(tester, style);
      expect(find.byKey(ValueKey(key)), findsOneWidget);
      expect(find.byType(StyleBackground), findsOneWidget);
    });
  }

  testWidgets('A、C 沒有裝飾背景', (tester) async {
    for (final s in [ThemeStyleId.editorial, ThemeStyleId.airy]) {
      await pumpShell(tester, s);
      for (final k in ['bg-neon', 'bg-terminal', 'bg-dreamy']) {
        expect(find.byKey(ValueKey(k)), findsNothing, reason: '$s');
      }
    }
  });

  testWidgets('背景外層有 RepaintBoundary', (tester) async {
    await pumpShell(tester, ThemeStyleId.neon);
    expect(
        find.ancestor(
            of: find.byKey(const ValueKey('bg-neon')),
            matching: find.byType(RepaintBoundary)),
        findsWidgets);
  });

  testWidgets('D 減少動態效果時游標不閃（pumpAndSettle 可以結束）', (tester) async {
    await pumpShell(tester, ThemeStyleId.terminal, reduceMotion: true);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  test('E 漸層背景上的文字對比 ≥ 4.5', () {
    for (final mode in [BrightnessMode.dark, BrightnessMode.light]) {
      final p = AppPalette.resolve(
          ThemeChoice(style: ThemeStyleId.dreamy, mode: mode));
      final a = dreamyDecorOpacity(p.brightness);
      for (final d in p.decor!) {
        final bg = Color.alphaBlend(d.withOpacity(a), p.background);
        expect(contrast(p.text, bg), greaterThanOrEqualTo(4.5), reason: '$d');
        expect(contrast(p.muted, bg), greaterThanOrEqualTo(4.5), reason: '$d');
      }
    }
  });

  test('AppFonts 停用 google_fonts 時退回系統字體', () {
    AppFonts.enabled = false;
    expect(AppFonts.mono().fontFamily, 'monospace');
    expect(AppFonts.serif().fontFamily, 'serif');
    expect(AppFonts.serif().fontStyle, FontStyle.italic);
    expect(AppFonts.mincho().fontWeight, FontWeight.w900);
    expect(AppFonts.condensed(const TextStyle(fontSize: 30)).fontSize, 30);
  });
}
