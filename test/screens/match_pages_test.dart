import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valorant_shop_tracker/screens/match_detail_page.dart';
import 'package:valorant_shop_tracker/screens/match_history_page.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  group('重試', retryTests);
  group('路由', routingTests);
  Future<Harness> loggedIn(WidgetTester tester,
      {int total = 3, Set<String> fail = const {}}) async {
    final h = await Harness.create(tester,
        riotHttp: riotClient(historyTotal: total, failMatchIds: fail));
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    return h;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  group('對戰紀錄頁', () {
    testWidgets('未登入時引導登入', (tester) async {
      setWidth(tester, 1400);
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: const MatchHistoryPage()));
      await tester.pumpAndSettle();
      expect(find.text('登入 Riot 以查看對戰紀錄'), findsOneWidget);
    });

    testWidgets('列表顯示地圖、模式、勝負、比分、K/D/A、RR 與牌位', (tester) async {
      setWidth(tester, 1400);
      final h = await loggedIn(tester);
      await tester.pumpWidget(h.wrap(home: const MatchHistoryPage()));
      await settle(tester);
      expect(find.text('亞海懸城'), findsWidgets);
      expect(find.text('競技'), findsWidgets);
      expect(find.text('勝'), findsWidgets);
      expect(find.text('13 : 9'), findsWidgets);
      expect(find.text('20 / 12 / 4'), findsWidgets);
      expect(find.text('+18'), findsWidgets);
      expect(find.text('鑽石 2'), findsOneWidget);
      expect(find.text('45 RR'), findsOneWidget);
      expect(find.text('名稱資料來自 Riot，請勿公開或分享他人資訊'), findsOneWidget);
      expect(find.text('載入更多'), findsNothing);
    });

    testWidgets('單場失敗與載入更多', (tester) async {
      setWidth(tester, 1400);
      final h = await loggedIn(tester, total: 25, fail: {'m2'});
      await tester.pumpWidget(h.wrap(home: const MatchHistoryPage()));
      await settle(tester);
      expect(find.text('無法載入這場'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('載入更多'), 300,
          scrollable: find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
      expect(find.text('載入更多'), findsOneWidget);
    });

    testWidgets('點卡片進入詳情', (tester) async {
      setWidth(tester, 1400);
      final h = await loggedIn(tester);
      await tester.pumpWidget(h.wrap(
        home: const MatchHistoryPage(),
        onGenerateRoute: (s) => s.name == '/matches/detail'
            ? MaterialPageRoute(
                builder: (_) => MatchDetailPage(matchId: s.arguments as String))
            : null,
      ));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('match-card-m1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player-row-me')), findsOneWidget);
    });
  });

  group('單場詳情頁', () {
    Future<Harness> withDetail(WidgetTester tester) async {
      final h = await loggedIn(tester);
      await tester.runAsync(h.matchHistory.loadFirstPage);
      return h;
    }

    testWidgets('兩隊各 5 列、Riot ID、未知玩家、不含觀戰者', (tester) async {
      setWidth(tester, 1400);
      final h = await withDetail(tester);
      await tester
          .pumpWidget(h.wrap(home: const MatchDetailPage(matchId: 'm1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('team-Blue')), findsOneWidget);
      expect(find.byKey(const ValueKey('team-Red')), findsOneWidget);
      expect(find.byKey(const Key('player-row-me')), findsOneWidget);
      expect(find.text('Alpha#TW1'), findsOneWidget);
      expect(find.text('Bravo#TW1'), findsOneWidget);
      expect(find.text('未知玩家'), findsOneWidget);
      expect(find.text('Watcher#TW1'), findsNothing);
      expect(find.text('ACS'), findsNWidgets(2));
      expect(find.text('爆頭率'), findsNWidgets(2));
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('191'), findsOneWidget);
    });

    testWidgets('同一組隊的玩家標記顏色相同', (tester) async {
      setWidth(tester, 1400);
      final h = await withDetail(tester);
      await tester
          .pumpWidget(h.wrap(home: const MatchDetailPage(matchId: 'm1')));
      await tester.pumpAndSettle();
      Color dot(String puuid) => (tester
              .widget<Container>(find.byKey(ValueKey('party-dot-$puuid')))
              .decoration as BoxDecoration)
          .color!;
      expect(dot('puuid-1'), dot('mate'));
      expect(find.byKey(const ValueKey('party-dot-b3')), findsNothing);
    });

    testWidgets('窄螢幕時兩隊上下排列', (tester) async {
      setWidth(tester, 400);
      final h = await withDetail(tester);
      await tester
          .pumpWidget(h.wrap(home: const MatchDetailPage(matchId: 'm1')));
      await tester.pumpAndSettle();
      final blue = tester.getTopLeft(find.byKey(const ValueKey('team-Blue')));
      final red = tester.getTopLeft(find.byKey(const ValueKey('team-Red')));
      expect(red.dy, greaterThan(blue.dy));
      expect(tester.takeException(), isNull);
    });

    testWidgets('找不到場次', (tester) async {
      setWidth(tester, 1400);
      final h = await Harness.create(tester);
      await tester
          .pumpWidget(h.wrap(home: const MatchDetailPage(matchId: 'zzz')));
      await tester.pumpAndSettle();
      expect(find.text('找不到這場對戰'), findsOneWidget);
    });
  });
}

void routingTests() {
  testWidgets('側邊導覽有「對戰紀錄」且可切換到該頁', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(useAppRoutes: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('對戰紀錄'));
    await tester.pumpAndSettle();
    expect(find.text('登入 Riot 以查看對戰紀錄'), findsOneWidget);
  });
}

void retryTests() {
  testWidgets('第一頁失敗時顯示重試，按下後重新載入', (tester) async {
    setWidth(tester, 1400);
    var historyCalls = 0;
    var fail = true;
    final inner = riotClient();
    final client = MockClient((req) async {
      if (req.url.path.contains('match-history')) {
        historyCalls++;
        if (fail) return http.Response('{}', 500);
      }
      final copy = http.Request(req.method, req.url)
        ..headers.addAll(req.headers)
        ..bodyBytes = req.bodyBytes;
      return inner.send(copy).then(http.Response.fromStream);
    });
    final h = await Harness.create(tester, riotHttp: client);
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    await tester.pumpWidget(h.wrap(home: const MatchHistoryPage()));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('重試'), findsOneWidget);
    final before = historyCalls;
    fail = false;
    await tester.tap(find.text('重試'));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(historyCalls, before + 1);
    expect(find.text('重試'), findsNothing);
    expect(find.text('13 : 9'), findsWidgets);
  });
}
