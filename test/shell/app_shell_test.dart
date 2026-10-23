import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:agent_t/app_routes.dart';
import 'package:agent_t/shell/app_shell.dart';
import 'package:agent_t/widgets/hud/page_header.dart';
import 'package:agent_t/shell/side_nav.dart';
import 'package:agent_t/theme/app_theme.dart';
import 'package:agent_t/widgets/hud/hud.dart';

import 'package:agent_t/theme/theme_ids.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';

void setWidth(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
}

Widget shell() => const AppShell(
      currentRoute: '/players',
      title: '遇過的玩家',
      child: Text('內容'),
    );

/// 側欄的行為在 D 終端機（窄側欄）下測試；展開模式直接測 SideNav。
const terminal = ThemeChoice(style: ThemeStyleId.terminal);

Widget sideNavHost({required bool extended, Widget? footer}) => MaterialApp(
      home: Scaffold(
        body: Row(children: [
          SideNav(
            currentRoute: '/players',
            extended: extended,
            brand: appName,
            onSelect: (_) {},
            footer: footer,
          ),
        ]),
      ),
    );

/// 頁首標題（PageHeader 的標題 Text 帶有 header-title key）。
String? headerTitle(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('header-title'))).data;

void main() {
  testWidgets('400 寬：底部導覽 5 項、沒有 NavigationRail 與漢堡選單', (tester) async {
    setWidth(tester, 400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 5);
    for (final label in ['我的商店', '對戰紀錄', '即時對局', '我的收藏', '更多']) {
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
    expect(headerTitle(tester), '角色');
  });

  testWidgets('400 寬：手機版也有網頁版的頁首（標題、英文標與動作）', (tester) async {
    setWidth(tester, 400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        home: const AppShell(
            currentRoute: '/players',
            title: '遇過的玩家',
            subtitle: '3 款',
            actions: [Icon(Icons.add, key: ValueKey('page-action'))],
            child: Text('內容'))));
    await tester.pumpAndSettle();
    expect(find.byType(PageHeader), findsOneWidget);
    expect(headerTitle(tester), '遇過的玩家');
    expect(find.text('3 款'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(PageHeader),
            matching: find.byKey(const ValueKey('page-action'))),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('400 寬：返回鍵回到首頁，不是上一層', (tester) async {
    setWidth(tester, 400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(useAppRoutes: true));
    await tester.pumpAndSettle();
    // 先到對戰紀錄，再從「更多」到角色：上一層是對戰紀錄。
    await tester.tap(find.text('對戰紀錄'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('角色'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shell-home')));
    await tester.pumpAndSettle();
    expect(headerTitle(tester), '我的商店');
    // 首頁沒有返回鍵。
    expect(find.byKey(const ValueKey('shell-home')), findsNothing);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('400 寬：上方列的 Riot 狀態圖示與返回鍵垂直置中對齊', (tester) async {
    setWidth(tester, 400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    await tester.pumpAndSettle();
    final buttons = find.descendant(
        of: find.byType(AppBar), matching: find.byType(IconButton));
    final home = tester.getCenter(find.byKey(const ValueKey('shell-home')));
    final riot = tester.getCenter(buttons.last);
    expect(riot.dy, closeTo(home.dy, 1));
  });

  testWidgets('首頁即使疊在其他頁面上也沒有返回鍵', (tester) async {
    setWidth(tester, 400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const AppShell(
                            currentRoute: '/',
                            title: '我的商店',
                            child: Text('首頁')))),
                child: const Text('go')))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('首頁'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byKey(const ValueKey('shell-home')), findsNothing);
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
    await tester.pumpWidget(h.wrap(choice: terminal, home: shell()));
    expect(tester.widget<SideNav>(find.byType(SideNav)).extended, isFalse);
    expect(
        find.descendant(
            of: find.byType(SideNav), matching: find.byType(Tooltip)),
        findsAtLeastNWidgets(12));
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('SideNav 展開：分組標題與完整名稱', (tester) async {
    setWidth(tester, 1100);
    await tester.pumpWidget(sideNavHost(extended: true));
    for (final t in ['主要', '資料庫', '其他', '玩家卡片', 'Agent T', '遇過的玩家']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('選中項目有 3px 紅色指示條', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(choice: terminal, home: shell()));
    final bar = find.descendant(
        of: find.byKey(const ValueKey('nav-/players')),
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
    await tester.pumpWidget(h.wrap(
        choice: terminal, home: shell(), onGenerateRoute: onGenerateAppRoute));
    await tester.tap(find.byKey(const ValueKey('nav-/agents')));
    await tester.pumpAndSettle();
    expect(find.text('角色'), findsWidgets);
    expect(find.text('內容'), findsNothing);
  });

  testWidgets('Tab 聚焦側欄項目後 Enter 換頁', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: terminal, home: shell(), onGenerateRoute: onGenerateAppRoute));
    // 依序：我的商店、對戰紀錄、即時對局。
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('內容'), findsNothing);
  });

  testWidgets('減少動態時側欄項目沒有淡入與水波', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: terminal,
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(1400, 900), disableAnimations: true),
            child: shell())));
    final ink = tester.widget<InkWell>(find.descendant(
        of: find.byKey(const ValueKey('nav-/matches')),
        matching: find.byType(InkWell)));
    expect(ink.hoverDuration, Duration.zero);
    expect(ink.splashFactory, NoSplash.splashFactory);
  });

  testWidgets('側欄項目是按鈕語意；footer 在透明 Material 上', (tester) async {
    setWidth(tester, 1400);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(sideNavHost(
        extended: true,
        footer: const ListTile(key: ValueKey('nav-riot'), title: Text('登入'))));
    final node = tester.getSemantics(find.descendant(
        of: find.byKey(const ValueKey('nav-/matches')),
        matching: find.text('對戰紀錄')));
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    final riot = find.byKey(const ValueKey('nav-riot'));
    final material = find.ancestor(of: riot, matching: find.byType(Material));
    final sideNav = find.byType(SideNav);
    // footer 與 SideNav 之間要有一層 Material（ink 才畫在側欄底色之上）。
    expect(
        find.descendant(of: sideNav, matching: material.first), findsOneWidget);
    handle.dispose();
  });

  testWidgets('1440 寬頁首標題字級依風格', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(style: ThemeStyleId.neon),
        home: const AppShell(
            currentRoute: '/players',
            title: '遇過的玩家',
            subtitle: '3 項',
            child: Text('內容'))));
    final title = find.descendant(
        of: find.byType(PageHeader), matching: find.text('遇過的玩家'));
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

  Widget longPage() => AppShell(
        currentRoute: '/players',
        title: '遇過的玩家',
        child: ListView(
          key: const ValueKey('page-list'),
          children: [for (var i = 0; i < 100; i++) Text('row $i')],
        ),
      );

  testWidgets('400 寬：往上捲時頁首跟著內容捲走，捲回頂端時回來', (tester) async {
    setWidth(tester, 400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: longPage()));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('header-title'));
    final y0 = tester.getTopLeft(title).dy;
    await tester.drag(find.text('row 3'), const Offset(0, -400));
    await tester.pumpAndSettle();
    // 捲出畫面的頁首會被回收（找不到），或至少往上移了。
    expect(title.evaluate().isEmpty || tester.getTopLeft(title).dy < y0 - 100,
        isTrue);
    await tester.drag(
        find.byKey(const ValueKey('page-list')), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dy, closeTo(y0, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('1400 寬：頁首固定，不跟著內容捲動', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(choice: terminal, home: longPage()));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('header-title'));
    final y0 = tester.getTopLeft(title).dy;
    await tester.drag(find.text('row 3'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dy, y0);
  });

  testWidgets('跨過 600 寬時內容的捲動位置保留', (tester) async {
    setWidth(tester, 900);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
      home: AppShell(
        currentRoute: '/players',
        title: '遇過的玩家',
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
