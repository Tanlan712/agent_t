import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/screens/match_history_page.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  Future<Harness> loggedIn(WidgetTester tester) async {
    final h = await Harness.create(tester,
        riotHttp: riotClient(historyTotal: 3, matchInfoOverrides: {
          'm2': {'queueID': 'unrated'},
          'm3': {'queueID': 'deathmatch'},
        }));
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    return h;
  }

  Future<void> open(WidgetTester tester, Harness h) async {
    await tester.pumpWidget(h.wrap(home: const MatchHistoryPage()));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
    }
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String key, String option) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  Finder card(String id) => find.byKey(ValueKey('match-card-$id'));

  testWidgets('篩選模式：只看競技、只看一般', (tester) async {
    setWidth(tester, 1440);
    final h = await loggedIn(tester);
    await open(tester, h);
    expect(card('m1'), findsOneWidget);
    expect(card('m2'), findsOneWidget);
    await choose(tester, 'filter-mode', '競技');
    expect(card('m1'), findsOneWidget);
    expect(card('m2'), findsNothing);
    expect(card('m3'), findsNothing);
    await choose(tester, 'filter-mode', '一般');
    expect(card('m2'), findsOneWidget);
    expect(card('m1'), findsNothing);
  });

  testWidgets('篩選勝負：沒有符合時顯示說明', (tester) async {
    setWidth(tester, 1440);
    final h = await loggedIn(tester);
    await open(tester, h);
    // 假資料裡自己那隊都贏。
    await choose(tester, 'filter-result', '敗');
    expect(find.text('沒有符合的場次'), findsOneWidget);
  });

  testWidgets('走勢圖：ACS 與 RR', (tester) async {
    setWidth(tester, 1440);
    final h = await loggedIn(tester);
    await open(tester, h);
    expect(find.byKey(const ValueKey('chart-acs')), findsOneWidget);
    expect(find.byKey(const ValueKey('chart-rr')), findsOneWidget);
    expect(find.textContaining('平均 ACS'), findsWidgets);
  });

  for (final width in [375.0, 1440.0]) {
    testWidgets('${width.toInt()} 寬：統計分頁列出特務與地圖', (tester) async {
      setWidth(tester, width);
      final h = await loggedIn(tester);
      await open(tester, h);
      await tester.tap(find.text('統計'));
      await tester.pumpAndSettle();
      final agents = find.byKey(const ValueKey('stats-agents'));
      final maps = find.byKey(const ValueKey('stats-maps'));
      expect(agents, findsOneWidget);
      expect(find.descendant(of: agents, matching: find.text('蓋克')),
          findsOneWidget);
      expect(
          find.descendant(of: agents, matching: find.text('3')), findsWidgets);
      await tester.ensureVisible(maps);
      expect(find.descendant(of: maps, matching: find.text('亞海懸城')),
          findsOneWidget);
      expect(find.textContaining('依已載入的最近 3 場'), findsOneWidget);
      // 統計也套用篩選。
      await tester.tap(find.text('對戰'));
      await tester.pumpAndSettle();
      await choose(tester, 'filter-mode', '競技');
      await tester.tap(find.text('統計'));
      await tester.pumpAndSettle();
      expect(find.textContaining('依已載入的最近 1 場'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
