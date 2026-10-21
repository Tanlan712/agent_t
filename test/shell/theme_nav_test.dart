import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';
import 'package:valorant_shop_tracker/shell/nav/top_nav.dart';
import 'package:valorant_shop_tracker/shell/side_nav.dart';
import 'package:valorant_shop_tracker/theme/theme_ids.dart';

import '../app_harness.dart';
import 'app_shell_test.dart' show setWidth;

Widget shell() => const AppShell(
      currentRoute: '/wishlist',
      title: '願望清單',
      child: Text('內容'),
    );

/// 規格 §4.1：各風格的導覽（A～E）。
void main() {
  Future<Harness> pump(WidgetTester tester, ThemeStyleId style,
      {double width = 1440, bool routes = false}) async {
    setWidth(tester, width);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: ThemeChoice(style: style),
        home: routes ? null : shell(),
        useAppRoutes: routes));
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('A 編輯海報：頂部列＋/// 開全螢幕選單，可導到武器', (tester) async {
    await pump(tester, ThemeStyleId.editorial, routes: true);
    expect(find.byType(TopNav), findsOneWidget);
    expect(find.byType(SideNav), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav-menu-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fullscreen-menu')), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('fullscreen-menu')),
        matching: find.text('武器')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fullscreen-menu')), findsNothing);
    expect(find.text('武器'), findsWidgets);
  });

  testWidgets('A 全螢幕選單按 Esc 關閉', (tester) async {
    await pump(tester, ThemeStyleId.editorial);
    await tester.tap(find.byKey(const ValueKey('nav-menu-button')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fullscreen-menu')), findsNothing);
  });

  testWidgets('B 數位霓虹：置中分頁，目前頁有底線', (tester) async {
    await pump(tester, ThemeStyleId.neon);
    final underline = find.byKey(const ValueKey('nav-underline'));
    expect(underline, findsOneWidget);
    expect(
        find.ancestor(
            of: underline,
            matching: find.byKey(const ValueKey('nav-/wishlist'))),
        findsOneWidget);
  });

  testWidgets('C 優雅留白：每個分組一個下拉選單', (tester) async {
    await pump(tester, ThemeStyleId.airy, routes: true);
    await tester.tap(find.byKey(const ValueKey('nav-group-database')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('地圖').last);
    await tester.pumpAndSettle();
    expect(find.text('地圖'), findsWidgets);
  });

  testWidgets('D 終端機：窄側欄（收合）', (tester) async {
    await pump(tester, ThemeStyleId.terminal);
    expect(tester.widget<SideNav>(find.byType(SideNav)).extended, isFalse);
    expect(find.byType(TopNav), findsNothing);
  });

  testWidgets('E 夢幻漸層：漢堡開側邊抽屜', (tester) async {
    await pump(tester, ThemeStyleId.dreamy);
    await tester.tap(find.byKey(const ValueKey('nav-hamburger')));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(
        find.descendant(of: find.byType(Drawer), matching: find.text('玩家卡片')),
        findsOneWidget);
  });

  testWidgets('768 寬：頂部列只顯示圖示＋提示', (tester) async {
    for (final s in [
      ThemeStyleId.editorial,
      ThemeStyleId.neon,
      ThemeStyleId.airy,
      ThemeStyleId.dreamy,
    ]) {
      await pump(tester, s, width: 768);
      expect(
          find.descendant(of: find.byType(TopNav), matching: find.text('對戰紀錄')),
          findsNothing,
          reason: '$s');
      expect(
          find.descendant(
              of: find.byType(TopNav), matching: find.byType(Tooltip)),
          findsWidgets,
          reason: '$s');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('375 寬：所有風格都用底部導覽', (tester) async {
    for (final s in ThemeStyleId.values) {
      await pump(tester, s, width: 375);
      expect(find.byType(NavigationBar), findsOneWidget, reason: '$s');
      expect(find.byType(TopNav), findsNothing);
    }
  });

  testWidgets('E 的底部導覽是浮動膠囊', (tester) async {
    await pump(tester, ThemeStyleId.dreamy, width: 375);
    expect(find.byKey(const ValueKey('bottom-pill')), findsOneWidget);
  });

  testWidgets('C 的內容最大寬度 1080', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(style: ThemeStyleId.airy),
        home: const AppShell(
            currentRoute: '/',
            title: '我的商店',
            child: SizedBox(
                key: ValueKey('wide'), width: double.infinity, height: 10))));
    await tester.pumpAndSettle();
    // 1080 減去左右內距各 32。
    expect(tester.getSize(find.byKey(const ValueKey('wide'))).width, 1016);
  });

  testWidgets('頂部列寬螢幕時顯示 Riot 狀態文字', (tester) async {
    await pump(tester, ThemeStyleId.editorial);
    expect(find.text('登入 Riot'), findsOneWidget);
  });

  testWidgets('頂部列項目可以用 Tab 聚焦後 Enter 換頁', (tester) async {
    await pump(tester, ThemeStyleId.neon, routes: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('願望清單是空的，按 ＋ 加入造型'), findsOneWidget);
  });
}
