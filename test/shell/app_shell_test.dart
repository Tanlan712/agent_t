import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';

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
    expect(find.byType(NavigationRail), findsNothing);
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

  testWidgets('900 寬：窄導覽列', (tester) async {
    setWidth(tester, 900);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('1100 寬：展開導覽列，看得到完整名稱', (tester) async {
    setWidth(tester, 1100);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.text('玩家卡片'), findsOneWidget);
    expect(find.text('VALORANT 商店追蹤'), findsOneWidget);
    expect(find.text('願望清單'), findsWidgets);
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
