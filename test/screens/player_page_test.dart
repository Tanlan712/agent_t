import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/app_routes.dart';
import 'package:agent_t/models/match_models.dart';
import 'package:agent_t/screens/match_detail_page.dart';
import 'package:agent_t/screens/player_page.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  const foxtrot = PlayerRef(puuid: 'r1', riotId: 'Foxtrot#TW1');

  Future<Harness> harness(WidgetTester tester,
      {Map<String, int> otherHistoryStatus = const {}}) async {
    final h = await Harness.create(tester,
        riotHttp: riotClient(otherHistoryStatus: otherHistoryStatus));
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    return h;
  }

  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }
  }

  testWidgets('標題、牌位與 RR、各模式、每場 RR、他的 K/D/A 與隱私提示', (tester) async {
    setWidth(tester, 1400);
    final h = await harness(tester);
    await tester.pumpWidget(h.wrap(
        home: const PlayerPage(player: foxtrot),
        onGenerateRoute: onGenerateAppRoute));
    await drain(tester);
    expect(find.text('Foxtrot#TW1'), findsOneWidget);
    Finder inKey(String key, Finder f) =>
        find.descendant(of: find.byKey(ValueKey(key)), matching: f);
    // 牌位卡：他的牌位與 RR、最近幾場 RR、歷史最高與本幕戰績（使用者 2026-11-17 決定擴充）。
    expect(inKey('history-rank', find.text('40 RR')), findsOneWidget);
    expect(inKey('history-rank', find.text('最近 RR')), findsOneWidget);
    expect(inKey('history-rank', find.text('+20')), findsWidgets);
    expect(inKey('history-rank', find.text('-15')), findsWidgets);
    expect(find.byKey(const ValueKey('rank-fact-歷史最高')), findsOneWidget);
    expect(find.byKey(const ValueKey('rank-fact-競技總場數')), findsOneWidget);
    // KPI 與各模式。
    expect(find.byKey(const ValueKey('kpi-kd')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-modes')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-competitive')), findsOneWidget);
    expect(find.text('10 / 10 / 5'), findsWidgets);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('match-card-m1')),
            matching: find.text('227')),
        findsOneWidget);
    // 每場 RR：m1 是第 0 場（+20）。
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('match-card-m1')),
            matching: find.text('+20')),
        findsOneWidget);
    // 今日小結只屬於自己，玩家頁不顯示。
    expect(find.byKey(const ValueKey('today-summary')), findsNothing);
    // 一頁 20 場，頁尾提示要捲到底才會建立。
    await tester.scrollUntilVisible(find.text('請勿公開或分享他人資訊'), 600,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('請勿公開或分享他人資訊'), findsOneWidget);
  });

  testWidgets('統計分頁有模式表', (tester) async {
    setWidth(tester, 1400);
    final h = await harness(tester);
    await tester.pumpWidget(h.wrap(
        home: const PlayerPage(player: foxtrot),
        onGenerateRoute: onGenerateAppRoute));
    await drain(tester);
    await tester.tap(find.text('統計'));
    await tester.pump();
    expect(find.byKey(const ValueKey('stats-modes')), findsOneWidget);
    expect(find.byKey(const ValueKey('stats-agents')), findsOneWidget);
  });

  testWidgets('手機寬度不溢出', (tester) async {
    setWidth(tester, 390);
    final h = await harness(tester);
    await tester.pumpWidget(h.wrap(
        home: const PlayerPage(player: foxtrot),
        onGenerateRoute: onGenerateAppRoute));
    await drain(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('history-rank')), findsOneWidget);
  });

  testWidgets('點卡片進入該場詳情', (tester) async {
    setWidth(tester, 1400);
    final h = await harness(tester);
    await tester.pumpWidget(h.wrap(
        home: const PlayerPage(player: foxtrot),
        onGenerateRoute: onGenerateAppRoute));
    await drain(tester);
    await tester.tap(find.byKey(const ValueKey('match-card-m1')));
    await tester.pumpAndSettle();
    expect(find.byType(MatchDetailPage), findsOneWidget);
    expect(find.text('找不到這場對戰'), findsNothing);
    expect(find.byKey(const ValueKey('team-Red')), findsOneWidget);
  });

  testWidgets('第一頁失敗時顯示重試', (tester) async {
    setWidth(tester, 1400);
    final h = await harness(tester, otherHistoryStatus: {'r1': 500});
    await tester.pumpWidget(h.wrap(
        home: const PlayerPage(player: foxtrot),
        onGenerateRoute: onGenerateAppRoute));
    await drain(tester);
    expect(find.text('重試'), findsOneWidget);
  });

  testWidgets('路由 /players/detail 打開玩家頁', (tester) async {
    setWidth(tester, 1400);
    final h = await harness(tester);
    await tester.pumpWidget(h.wrap(
        home: Builder(
            builder: (c) => TextButton(
                onPressed: () => Navigator.pushNamed(c, '/players/detail',
                    arguments: foxtrot),
                child: const Text('go'))),
        onGenerateRoute: onGenerateAppRoute));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerPage), findsOneWidget);
    await drain(tester);
  });

  testWidgets('重新整理後沒有參數時顯示找不到玩家', (tester) async {
    setWidth(tester, 1400);
    final h = await harness(tester);
    await tester.pumpWidget(h.wrap(
        home: Builder(
            builder: (c) => TextButton(
                onPressed: () => Navigator.pushNamed(c, '/players/detail'),
                child: const Text('go'))),
        onGenerateRoute: onGenerateAppRoute));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('找不到這位玩家'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
