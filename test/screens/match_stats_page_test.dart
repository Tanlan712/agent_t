import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:valorant_shop_tracker/screens/match_history_page.dart';
import 'package:valorant_shop_tracker/widgets/line_chart.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

/// 可以讓對戰紀錄請求暫時失敗的 client。
class _Gate extends http.BaseClient {
  final http.Client inner;
  bool failHistory = false;
  _Gate(this.inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (failHistory && request.url.path.contains('/match-history/')) {
      return http.StreamedResponse(Stream.value(const []), 500);
    }
    return inner.send(request);
  }
}

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
    // 頁首較高（近期戰績、常用特務）：拉高視窗，卡片與統計表才會建出來。
    tester.view.physicalSize = Size(tester.view.physicalSize.width, 2400);
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
    Finder drawn(String key) => find.descendant(
        of: find.byKey(ValueKey(key)), matching: find.byType(SimpleLineChart));
    // 3 場：ACS 與 RR 都畫得出線。
    expect(drawn('chart-acs'), findsOneWidget);
    expect(drawn('chart-rr'), findsOneWidget);
    expect(find.textContaining('平均 ACS'), findsWidgets);
    // 只看競技時只剩 1 場：不畫線，改顯示說明。
    await choose(tester, 'filter-mode', '競技');
    expect(drawn('chart-acs'), findsNothing);
    expect(drawn('chart-rr'), findsNothing);
    expect(find.textContaining('至少要 2 場'), findsWidgets);
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

  testWidgets('選了特務後重新載入失敗（選項裡暫時沒有這位特務）不會崩潰，篩選仍看得到', (tester) async {
    setWidth(tester, 1440);
    final gate = _Gate(riotClient(historyTotal: 3));
    final h = await Harness.create(tester, riotHttp: gate);
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    await open(tester, h);
    await choose(tester, 'filter-agent', '蓋克');
    gate.failHistory = true;
    await tester.runAsync(() => h.matchHistory.loadFirstPage());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // 下拉選單仍顯示目前的篩選，可以清除。
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('filter-agent')),
            matching: find.text('蓋克')),
        findsOneWidget);
    expect(find.text('清除篩選'), findsOneWidget);
  });
}
