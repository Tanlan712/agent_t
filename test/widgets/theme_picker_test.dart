import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/theme/app_palette.dart';
import 'package:agent_t/theme/app_theme.dart';
import 'package:agent_t/theme/theme_ids.dart';
import 'package:agent_t/widgets/theme/theme_picker.dart';

import '../app_harness.dart';
import '../shell/app_shell_test.dart' show setWidth;

/// 規格 §7：設定頁的主題選擇器。
void main() {
  Future<Harness> pump(WidgetTester tester) async {
    setWidth(tester, 1200);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        useSettingsTheme: true,
        home:
            const Scaffold(body: SingleChildScrollView(child: ThemePicker()))));
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('8 張風格縮圖', (tester) async {
    await pump(tester);
    for (final s in ThemeStyleId.values) {
      expect(find.byKey(ValueKey('theme-style-${s.name}')), findsOneWidget);
    }
  });

  testWidgets('點風格縮圖後存檔並套用', (tester) async {
    final h = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('theme-style-neon')));
    await tester.pumpAndSettle();
    expect(h.settings.settings.themeStyle, 'neon');
    expect(
        AppColors.background,
        AppPalette.resolve(const ThemeChoice(style: ThemeStyleId.neon))
            .background);
  });

  testWidgets('縮圖不改動目前配色', (tester) async {
    await pump(tester);
    expect(AppPalette.current.background,
        AppPalette.resolve(const ThemeChoice()).background);
  });

  testWidgets('主色與明暗', (tester) async {
    final h = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('theme-accent-green')));
    await tester.pumpAndSettle();
    expect(h.settings.settings.themeAccent, 'green');
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(h.settings.settings.themeBrightness, 'dark');
    expect(AppPalette.current.brightness, Brightness.dark);
  });

  testWidgets('動態背景開關只在 EVA 風格顯示', (tester) async {
    final h = await pump(tester);
    expect(find.byKey(const ValueKey('theme-motion')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('theme-style-evaAlert')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('theme-motion')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme-motion')));
    await tester.pumpAndSettle();
    expect(h.settings.settings.backgroundMotion, isFalse);
  });

  testWidgets('EVA 風格時主色顯示 EVA 名稱', (tester) async {
    await pump(tester);
    expect(find.text('特務紅'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme-style-evaMonitor')));
    await tester.pumpAndSettle();
    expect(find.text('警戒紅'), findsOneWidget);
    expect(find.text('初號機紫'), findsOneWidget);
  });

  testWidgets('375 寬不 overflow', (tester) async {
    setWidth(tester, 375);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        home:
            const Scaffold(body: SingleChildScrollView(child: ThemePicker()))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('375 寬一列兩張縮圖、明暗標籤不換行', (tester) async {
    setWidth(tester, 375);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        home: const Scaffold(
            body: SingleChildScrollView(
                padding: EdgeInsets.all(16), child: ThemePicker()))));
    await tester.pumpAndSettle();
    final a =
        tester.getTopLeft(find.byKey(const ValueKey('theme-style-editorial')));
    final b = tester.getTopLeft(find.byKey(const ValueKey('theme-style-neon')));
    expect(b.dy, a.dy);
    expect(tester.widget<Text>(find.text('跟隨風格')).softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EVA 風格：彩蛋與標題卡開關、重設劇集與彩蛋紀錄', (tester) async {
    final h = await pump(tester);
    expect(find.byKey(const ValueKey('theme-eva-eggs')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('theme-style-evaMonitor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-eva-eggs')));
    await tester.pumpAndSettle();
    expect(h.settings.settings.evaEnabled, isFalse);
    await tester.tap(find.byKey(const ValueKey('theme-eva-titlecards')));
    await tester.pumpAndSettle();
    expect(h.settings.settings.evaTitleCards, isFalse);

    await h.settings
        .updateEva((s) => s.copyWith(evaFoundEggs: ['E1'], evaEpisodeDays: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('theme-eva-reset')));
    await tester.tap(find.byKey(const ValueKey('theme-eva-reset')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(h.settings.settings.evaFoundEggs, ['E1']);
    await tester.tap(find.byKey(const ValueKey('theme-eva-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重設'));
    await tester.pumpAndSettle();
    expect(h.settings.settings.evaFoundEggs, isEmpty);
    expect(h.settings.settings.evaEpisodeDays, 0);
    expect(h.settings.settings.themeStyle, 'evaMonitor');
  });
}
