import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/progress_reference.dart';
import 'package:valorant_shop_tracker/screens/collection_page.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';
import 'package:valorant_shop_tracker/shell/nav_items.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud.dart';

import '../account_fixtures.dart';
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

  Future<Harness> withSkins(WidgetTester tester) async {
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
    return h;
  }

  testWidgets('造型分頁列出所有槍枝與擁有數量（含 0 款）', (tester) async {
    setWidth(tester, 1440);
    final h = await withSkins(tester);
    await tester.pumpWidget(h.wrap(home: const CollectionPage()));
    await settle(tester);
    Finder card(String id, String text) => find.descendant(
        of: find.byKey(ValueKey('weapon-$id')), matching: find.text(text));
    expect(card('w-vandal', '暴徒'), findsOneWidget);
    expect(card('w-vandal', '擁有 1 款'), findsOneWidget);
    expect(card('w-phantom', '擁有 1 款'), findsOneWidget);
    expect(card('w-sheriff', '擁有 0 款'), findsOneWidget);
    // 造型名稱要點進槍枝才看得到。
    expect(find.text('光幻 暴徒'), findsNothing);
  });

  testWidgets('點進槍枝：只列該槍擁有的造型，最高等級、色票、預覽影片', (tester) async {
    setWidth(tester, 1440);
    final launched = <Uri>[];
    final h = await withSkins(tester);
    await tester.pumpWidget(h.wrap(home: CollectionPage(launch: (u) async {
      launched.add(u);
      return true;
    })));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('weapon-w-vandal')));
    await tester.pumpAndSettle();
    expect(find.text('光幻 暴徒'), findsOneWidget);
    expect(find.text('光幻 幻象'), findsNothing);
    expect(find.byKey(const ValueKey('swatch-skin-v-0')), findsOneWidget);
    await tester.tap(find.text('預覽影片'));
    expect(launched, [Uri.parse('https://example.test/v2.mp4')]);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('weapon-w-sheriff')));
    await tester.pumpAndSettle();
    expect(find.text('還沒有這把槍的造型'), findsOneWidget);
  });

  testWidgets('特務分頁顯示特務等級；沒有紀錄的顯示尚未開始', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester,
        riotHttp: riotClient(
            entitlements: {
              ItemTypes.agent: ['a-paid'],
            },
            contracts: contractsJson(contracts: [
              {
                'ContractDefinitionID': 'ac-paid',
                'ProgressionLevelReached': 2,
                'ProgressionTowardsNextLevel': 300,
              },
            ])),
        progressApi: FakeProgressApi());
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    await tester.pumpWidget(h.wrap(home: const CollectionPage()));
    await settle(tester);
    await openTab(tester, '特務');
    Finder agent(String id, Finder f) =>
        find.descendant(of: find.byKey(ValueKey('agent-$id')), matching: f);
    expect(agent('a-paid', find.text('等級 2 / 3')), findsOneWidget);
    expect(agent('a-base1', find.text('尚未開始')), findsOneWidget);
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

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('已登入、豐富資料：${width.toInt()} 寬不 overflow', (tester) async {
      setWidth(tester, width);
      final base = testProgressRef();
      final rich = ProgressReference(
        skinLevels: {
          ...base.skinLevels,
          'lv-long': const RefSkinLevel(
              skinUuid: 'skin-long',
              skinName: '這是一個名稱非常非常長的限定版造型名稱 暴徒',
              weaponName: '暴徒',
              weaponUuid: 'w-vandal',
              levelIndex: 3,
              videoUrl: 'https://example.test/long.mp4'),
        },
        chromas: {
          for (var i = 0; i < 5; i++)
            'ch-long-$i':
                RefChroma(skinUuid: 'skin-long', swatchUrl: 'sw$i.png'),
        },
        weapons: base.weapons,
        agents: base.agents,
        buddyLevels: base.buddyLevels,
        sprays: base.sprays,
        cards: base.cards,
        titles: base.titles,
      );
      final h = await Harness.create(tester,
          riotHttp: riotClient(skinLevels: [
            'lv-long',
            'lv-vandal-2',
            'lv-phantom-1'
          ], entitlements: {
            ItemTypes.skinChroma: [for (var i = 0; i < 5; i++) 'ch-long-$i'],
            ItemTypes.spray: ['spray-1'],
            ItemTypes.title: ['title-1'],
          }),
          progressApi: FakeProgressApi(rich));
      await tester.runAsync(() => h.riot.login(fakeRedirect));
      await tester.pumpWidget(h.wrap(home: const CollectionPage()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('weapon-w-vandal')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('預覽影片'), findsWidgets);
    });
  }

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
