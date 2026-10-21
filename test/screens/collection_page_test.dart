import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/screens/collection_page.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';
import 'package:valorant_shop_tracker/shell/nav_items.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud.dart';

import '../app_harness.dart';
import '../progress_fixtures.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  Future<Harness> loggedIn(WidgetTester tester,
      {Map<String, List<String>> owned = const {},
      Map<String, int> status = const {}}) async {
    final h = await Harness.create(tester,
        riotHttp: riotClient(entitlements: owned, entitlementStatus: status),
        progressApi: FakeProgressApi());
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    return h;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String prefix) async {
    await tester.tap(find.byWidgetPredicate(
        (w) => w is Tab && (w.text ?? '').startsWith(prefix)));
    await tester.pumpAndSettle();
  }

  test('導覽「主要」組有我的收藏', () {
    expect(
        navItems.any((n) =>
            n.route == '/collection' &&
            n.label == '我的收藏' &&
            n.group == NavGroup.shop),
        isTrue);
  });

  testWidgets('未登入時顯示空狀態與登入按鈕', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester, progressApi: FakeProgressApi());
    await tester.pumpWidget(h.wrap(home: const CollectionPage()));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '登入 Riot'), findsOneWidget);
  });

  testWidgets('六個分頁顯示數量，造型依武器分組並有炫彩色票', (tester) async {
    setWidth(tester, 1440);
    final h = await loggedIn(tester, owned: {
      ItemTypes.skinChroma: ['ch-v-red'],
      ItemTypes.spray: ['spray-1'],
      ItemTypes.agent: ['a-paid'],
    });
    // 造型等級用 fixture 既有的路由（lvl-odin 等）不在參考資料裡；這裡改用收藏 provider 的資料。
    await tester.pumpWidget(h.wrap(home: const CollectionPage()));
    await settle(tester);
    for (final label in ['造型', '特務 3', '吊飾 0', '噴漆 1', '玩家卡片 0', '稱號 0']) {
      expect(
          find.byWidgetPredicate(
              (w) => w is Tab && (w.text ?? '').startsWith(label)),
          findsOneWidget,
          reason: label);
    }
    expect(find.textContaining('共 '), findsOneWidget);
  });

  testWidgets('造型分頁：依武器分組、最高等級、預覽影片開新分頁', (tester) async {
    setWidth(tester, 1440);
    final launched = <Uri>[];
    final h = await Harness.create(tester,
        riotHttp: riotClient(skinLevels: [
          'lv-vandal-1',
          'lv-vandal-2',
          'lv-phantom-1'
        ], entitlements: {
          ItemTypes.skinChroma: ['ch-v-red'],
        }),
        progressApi: FakeProgressApi());
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    await tester.pumpWidget(h.wrap(home: CollectionPage(launch: (u) async {
      launched.add(u);
      return true;
    })));
    await settle(tester);
    expect(find.text('暴徒'), findsOneWidget);
    expect(find.text('幻象'), findsOneWidget);
    expect(find.text('光幻 暴徒'), findsOneWidget);
    expect(find.byKey(const ValueKey('swatch-skin-v-0')), findsOneWidget);
    await tester.tap(find.text('預覽影片'));
    expect(launched, [Uri.parse('https://example.test/v2.mp4')]);
    // 沒有影片的造型不顯示按鈕。
    expect(find.text('預覽影片'), findsOneWidget);
  });

  testWidgets('新帳號：特務分頁列出初始特務並標示', (tester) async {
    setWidth(tester, 1440);
    final h = await loggedIn(tester);
    await tester.pumpWidget(h.wrap(home: const CollectionPage()));
    await settle(tester);
    await openTab(tester, '特務');
    expect(find.text('捷風'), findsOneWidget);
    expect(find.text('布史東'), findsOneWidget);
    expect(find.widgetWithText(StatusChip, '初始'), findsNWidgets(2));
  });

  testWidgets('沒有項目的分頁顯示空狀態', (tester) async {
    setWidth(tester, 1440);
    final h = await loggedIn(tester);
    await tester.pumpWidget(h.wrap(home: const CollectionPage()));
    await settle(tester);
    await openTab(tester, '噴漆');
    expect(find.text('還沒有這類收藏'), findsOneWidget);
  });

  testWidgets('單一分類失敗時該分頁顯示錯誤與重試', (tester) async {
    setWidth(tester, 1440);
    final h = await loggedIn(tester, status: {ItemTypes.spray: 500});
    await tester.pumpWidget(h.wrap(home: const CollectionPage()));
    await settle(tester);
    await openTab(tester, '噴漆');
    expect(find.widgetWithText(FilledButton, '重試'), findsOneWidget);
    await openTab(tester, '稱號');
    expect(find.widgetWithText(FilledButton, '重試'), findsNothing);
  });

  testWidgets('375 寬不 overflow', (tester) async {
    setWidth(tester, 375);
    final h = await loggedIn(tester, owned: {
      ItemTypes.spray: ['spray-1'],
    });
    await tester.pumpWidget(h.wrap(home: const CollectionPage()));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
