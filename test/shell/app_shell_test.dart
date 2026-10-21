import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:valorant_shop_tracker/app_routes.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';
import 'package:valorant_shop_tracker/shell/side_nav.dart';
import 'package:valorant_shop_tracker/theme/app_theme.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';

void setWidth(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
}

Widget shell() => const AppShell(
      currentRoute: '/wishlist',
      title: '願望清單',
      child: Text('內容'),
    );

void main() {
  testWidgets('400 寬：底部導覽 5 項、沒有 NavigationRail 與漢堡選單', (tester) async {
    setWidth(tester, 400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 5);
    for (final label in ['我的商店', '對戰紀錄', '即時對局', '願望清單', '更多']) {
      expect(
          find.descendant(
              of: find.byType(NavigationBar), matching: find.text(label)),
          findsOneWidget,
          reason: label);
    }
    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.byType(SideNav), findsNothing);
    expect(find.text('內容'), findsOneWidget);
  });

  testWidgets('400 寬：「更多」列出其餘頁面，點角色換頁', (tester) async {
    setWidth(tester, 400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(useAppRoutes: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsOneWidget);
    await tester.tap(find.text('角色'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '角色'), findsOneWidget);
  });

  testWidgets('400 寬與 1400 寬都有到期提醒列', (tester) async {
    for (final width in [400.0, 1400.0]) {
      setWidth(tester, width);
      var now = DateTime(2026, 10, 21, 12);
      final h = await Harness.create(tester, now: () => now);
      await tester.runAsync(() => h.riot.login(fakeRedirect));
      now = now.add(const Duration(minutes: 57));
      await tester.pumpWidget(h.wrap(home: shell()));
      await tester.pump();
      expect(find.byKey(const ValueKey('expiry-banner')), findsOneWidget,
          reason: '$width');
      await tester.pumpWidget(h.wrap(home: const SizedBox()));
    }
  });

  testWidgets('900 寬：窄導覽列，只有圖示加提示', (tester) async {
    setWidth(tester, 900);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    expect(tester.widget<SideNav>(find.byType(SideNav)).extended, isFalse);
    expect(
        find.descendant(
            of: find.byType(SideNav), matching: find.byType(Tooltip)),
        findsAtLeastNWidgets(12));
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('1100 寬：展開導覽列，分組標題與完整名稱', (tester) async {
    setWidth(tester, 1100);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    expect(tester.widget<SideNav>(find.byType(SideNav)).extended, isTrue);
    for (final t in ['主要', '資料庫', '其他', '玩家卡片', 'VALORANT 商店追蹤']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('願望清單'), findsWidgets);
  });

  testWidgets('選中項目有 3px 紅色指示條', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    final bar = find.descendant(
        of: find.byKey(const ValueKey('nav-/wishlist')),
        matching: find.byKey(const ValueKey('nav-indicator')));
    expect(bar, findsOneWidget);
    expect(tester.widget<Container>(bar).color, AppColors.primary);
    expect(tester.getSize(bar).width, 3);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('nav-/matches')),
            matching: find.byKey(const ValueKey('nav-indicator'))),
        findsNothing);
  });

  testWidgets('點側欄項目換頁', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester
        .pumpWidget(h.wrap(home: shell(), onGenerateRoute: onGenerateAppRoute));
    await tester.tap(find.byKey(const ValueKey('nav-/agents')));
    await tester.pumpAndSettle();
    expect(find.text('角色'), findsWidgets);
    expect(find.text('內容'), findsNothing);
  });

  testWidgets('Tab 聚焦側欄項目後 Enter 換頁', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester
        .pumpWidget(h.wrap(home: shell(), onGenerateRoute: onGenerateAppRoute));
    // 依序：我的商店、願望清單（目前頁）、對戰紀錄。
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('內容'), findsNothing);
  });

  testWidgets('1440 寬頁首標題 28px', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        home: const AppShell(
            currentRoute: '/wishlist',
            title: '願望清單',
            subtitle: '3 項',
            child: Text('內容'))));
    final title = find.descendant(
        of: find.byType(PageHeader), matching: find.text('願望清單'));
    expect(tester.widget<Text>(title).style?.fontSize, 28);
    expect(find.text('3 項'), findsOneWidget);
  });

  testWidgets('從 1400 縮到 400 不丟例外', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    tester.view.physicalSize = const Size(800, 900);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(400, 900);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('矮視窗（900×500、1400×500）導覽列不溢出', (tester) async {
    for (final width in [900.0, 1400.0]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 500);
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: shell()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$width');
    }
  });

  testWidgets('跨過 600 寬時內容的捲動位置保留', (tester) async {
    setWidth(tester, 900);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
      home: AppShell(
        currentRoute: '/wishlist',
        title: '願望清單',
        child: ListView(
          key: const ValueKey('page-list'),
          children: [for (var i = 0; i < 100; i++) Text('row $i')],
        ),
      ),
    ));
    final list = find.byKey(const ValueKey('page-list'));
    tester
        .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)))
        .position
        .jumpTo(400);
    await tester.pump();
    for (final width in [500.0, 1400.0, 800.0, 500.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      final pixels = tester
          .state<ScrollableState>(
              find.descendant(of: list, matching: find.byType(Scrollable)))
          .position
          .pixels;
      expect(pixels, 400, reason: '$width');
    }
  });

  testWidgets('導覽底部顯示 Riot 登入狀態', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    expect(find.text('登入 Riot'), findsOneWidget);
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    await tester.pumpAndSettle();
    expect(find.text('Tester#TW1'), findsOneWidget);
  });
}
