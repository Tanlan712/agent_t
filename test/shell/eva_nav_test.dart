import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';
import 'package:valorant_shop_tracker/shell/nav/eva_nav.dart';
import 'package:valorant_shop_tracker/shell/side_nav.dart';
import 'package:valorant_shop_tracker/theme/theme_ids.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';
import 'app_shell_test.dart' show setWidth;

const _eva = [
  ThemeStyleId.evaAlert,
  ThemeStyleId.evaMonitor,
  ThemeStyleId.evaFusion,
];

/// 規格 §4.1：EVA 系列的左側欄。
void main() {
  Future<Harness> pump(WidgetTester tester, ThemeStyleId style,
      {double width = 1440, bool routes = false}) async {
    setWidth(tester, width);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: ThemeChoice(style: style),
        useAppRoutes: routes,
        home: routes
            ? null
            : const AppShell(
                currentRoute: '/wishlist', title: '願望清單', child: Text('內容'))));
    await tester.pumpAndSettle();
    return h;
  }

  for (final s in _eva) {
    testWidgets('$s 用 EvaNav，點對戰紀錄換頁', (tester) async {
      await pump(tester, s, routes: true);
      expect(find.byType(EvaNav), findsOneWidget);
      expect(find.byType(SideNav), findsNothing);
      await tester.tap(find.byKey(const ValueKey('nav-/matches')));
      await tester.pumpAndSettle();
      expect(
          tester.widget<EvaNav>(find.byType(EvaNav)).currentRoute, '/matches');
    });
  }

  testWidgets('展開時每項有中文、英文與兩位數編號', (tester) async {
    await pump(tester, ThemeStyleId.evaAlert);
    final tile = find.byKey(const ValueKey('nav-/matches'));
    expect(
        find.descendant(of: tile, matching: find.text('對戰紀錄')), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('RECORD')),
        findsOneWidget);
    expect(
        find.descendant(of: tile, matching: find.text('03')), findsOneWidget);
    expect(find.byKey(const ValueKey('eva-brand')), findsOneWidget);
    expect(find.text('EMERGENCY ▼'), findsOneWidget);
  });

  testWidgets('未登入顯示 CONDITION: RED，登入後 GREEN', (tester) async {
    final h = await pump(tester, ThemeStyleId.evaMonitor);
    expect(find.text('CONDITION: RED'), findsOneWidget);
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    await tester.pumpAndSettle();
    expect(find.text('CONDITION: GREEN'), findsOneWidget);
  });

  testWidgets('F2 選中項目有斜紋方塊，F1 沒有', (tester) async {
    await pump(tester, ThemeStyleId.evaMonitor);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('nav-/wishlist')),
            matching: find.byKey(const ValueKey('eva-nav-stripe'))),
        findsOneWidget);
    await pump(tester, ThemeStyleId.evaAlert);
    expect(find.byKey(const ValueKey('eva-nav-stripe')), findsNothing);
  });

  testWidgets('900 寬收合：只有圖示＋提示', (tester) async {
    await pump(tester, ThemeStyleId.evaFusion, width: 900);
    final nav = tester.widget<EvaNav>(find.byType(EvaNav));
    expect(nav.extended, isFalse);
    expect(
        find.descendant(
            of: find.byType(EvaNav), matching: find.byType(Tooltip)),
        findsAtLeastNWidgets(12));
    expect(
        find.descendant(of: find.byType(EvaNav), matching: find.text('對戰紀錄')),
        findsNothing);
  });

  testWidgets('矮視窗不溢出', (tester) async {
    for (final s in _eva) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 480);
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(
          choice: ThemeChoice(style: s),
          home: const AppShell(
              currentRoute: '/', title: '我的商店', child: Text('x'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$s');
    }
  });
}
