import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/app_settings.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';
import 'package:valorant_shop_tracker/shell/nav_items.dart';

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
      currentRoute: '/wishlist', title: '願望清單', child: Text('內容'));

  double y(WidgetTester tester, String route) =>
      tester.getTopLeft(find.byKey(ValueKey('nav-$route'))).dy;

  testWidgets('側欄依設定的順序顯示', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await h.settings.setNavOrder(const ['/live', '/']);
    await tester.pumpWidget(h.wrap(home: shell()));
    expect(y(tester, '/live'), lessThan(y(tester, '/')));
  });

  testWidgets('編輯選單：上移後立即生效並保存，恢復預設可還原', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    await tester.tap(find.byKey(const ValueKey('nav-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-up-/matches')));
    await tester.pumpAndSettle();
    expect(h.settings.settings.navOrder.indexOf('/matches'),
        lessThan(h.settings.settings.navOrder.indexOf('/wishlist')));
    await tester.tap(find.byKey(const ValueKey('nav-edit-done')));
    await tester.pumpAndSettle();
    expect(y(tester, '/matches'), lessThan(y(tester, '/wishlist')));

    await tester.tap(find.byKey(const ValueKey('nav-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-edit-reset')));
    await tester.pumpAndSettle();
    expect(h.settings.settings.navOrder, isEmpty);
  });

  testWidgets('組內第一項不能上移、最後一項不能下移', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    await tester.tap(find.byKey(const ValueKey('nav-edit')));
    await tester.pumpAndSettle();
    final up =
        tester.widget<IconButton>(find.byKey(const ValueKey('nav-up-/')));
    expect(up.onPressed, isNull);
    final last = navItems.lastWhere((n) => n.group == NavGroup.shop).route;
    final down =
        tester.widget<IconButton>(find.byKey(ValueKey('nav-down-$last')));
    expect(down.onPressed, isNull);
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
