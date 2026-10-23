import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/models/app_settings.dart';
import 'package:agent_t/screens/settings_page.dart';
import 'package:agent_t/shell/app_shell.dart';
import 'package:agent_t/shell/nav_items.dart';
import 'package:agent_t/theme/theme_ids.dart';
import 'package:agent_t/widgets/nav_order_editor.dart';

import '../app_harness.dart';
import 'app_shell_test.dart' show setWidth;

List<String> routes(List<NavItem> items) => [for (final n in items) n.route];

void main() {
  group('orderedNavItems', () {
    test('沒有自訂時是預設順序', () {
      expect(routes(orderedNavItems(const [])), routes(navItems));
    });

    test('依自訂順序排列，但不跨組；未列出的接在組尾', () {
      final out = orderedNavItems(const ['/live', '/matches', '/weapons']);
      final shop = [
        for (final n in out)
          if (n.group == NavGroup.shop) n.route
      ];
      expect(shop.take(2), ['/live', '/matches']);
      expect(shop.toSet(), {
        for (final n in navItems)
          if (n.group == NavGroup.shop) n.route
      });
      final db = [
        for (final n in out)
          if (n.group == NavGroup.database) n.route
      ];
      expect(db.first, '/weapons');
      // 組的先後不變：主要 → 資料庫 → 其他。
      expect(out.indexWhere((n) => n.group == NavGroup.database),
          greaterThan(out.lastIndexWhere((n) => n.group == NavGroup.shop)));
      expect(out.last.route, '/settings');
    });

    test('未知的路由忽略', () {
      expect(routes(orderedNavItems(const ['/nope'])), routes(navItems));
    });
  });

  test('AppSettings 保存 navOrder', () {
    const s = AppSettings(navOrder: ['/live', '/']);
    expect(AppSettings.fromJson(s.toJson()).navOrder, ['/live', '/']);
    expect(AppSettings.fromJson(const {}).navOrder, isEmpty);
  });

  Widget shell() => const AppShell(
      currentRoute: '/players', title: '遇過的玩家', child: Text('內容'));

  testWidgets('各風格的導覽都依設定的順序顯示', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await h.settings.setNavOrder(const ['/live', '/']);
    // D 終端機（窄側欄）與 F3（EVA 側欄）是直排，A 編輯海報是頂部橫排。
    for (final (style, vertical) in [
      (ThemeStyleId.terminal, true),
      (ThemeStyleId.evaFusion, true),
      (ThemeStyleId.editorial, false),
    ]) {
      await tester
          .pumpWidget(h.wrap(choice: ThemeChoice(style: style), home: shell()));
      await tester.pumpAndSettle();
      final live = tester.getTopLeft(find.byKey(const ValueKey('nav-/live')));
      final home = tester.getTopLeft(find.byKey(const ValueKey('nav-/')));
      expect(
          vertical ? live.dy : live.dx, lessThan(vertical ? home.dy : home.dx),
          reason: style.name);
    }
  });

  Widget editor(Harness h) => h.wrap(
      home: Scaffold(body: ListView(children: const [NavOrderEditor()])));

  testWidgets('設定頁選單順序：上移後立即保存，恢復預設可還原', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(editor(h));
    final reset = find.byKey(const ValueKey('order-reset'));
    expect(tester.widget<TextButton>(reset).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('order-up-/live')));
    await tester.pumpAndSettle();
    final order = h.settings.settings.navOrder;
    expect(order.indexOf('/live'), lessThan(order.indexOf('/matches')));
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('order-/live'))).dy,
        lessThan(tester
            .getTopLeft(find.byKey(const ValueKey('order-/matches')))
            .dy));
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(h.settings.settings.navOrder, isEmpty);
  });

  testWidgets('設定頁選單順序：組內第一項不能上移、最後一項不能下移', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(editor(h));
    final up =
        tester.widget<IconButton>(find.byKey(const ValueKey('order-up-/')));
    expect(up.onPressed, isNull);
    final last = navItems.lastWhere((n) => n.group == NavGroup.shop).route;
    final down =
        tester.widget<IconButton>(find.byKey(ValueKey('order-down-$last')));
    expect(down.onPressed, isNull);
  });

  testWidgets('設定頁有選單順序', (tester) async {
    setWidth(tester, 1400);
    dotenv.testLoad(fileInput: '');
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const SettingsPage()));
    await tester.pumpAndSettle();
    expect(find.byType(NavOrderEditor), findsOneWidget);
  });

  testWidgets('手機「更多」也依自訂順序', (tester) async {
    setWidth(tester, 400);
    final h = await Harness.create(tester);
    await h.settings
        .setNavOrder(const ['/settings', '/playercards', '/agents']);
    await tester.pumpWidget(h.wrap(home: shell()));
    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('玩家卡片')).dy,
        lessThan(tester.getTopLeft(find.text('角色')).dy));
  });
}
