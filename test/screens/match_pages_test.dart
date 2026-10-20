import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valorant_shop_tracker/models/match_models.dart';
import 'package:valorant_shop_tracker/providers/recent_form_loader.dart';
import 'package:valorant_shop_tracker/screens/match_detail_page.dart';
import 'package:valorant_shop_tracker/screens/match_history_page.dart';

import '../app_harness.dart';
import '../match_fixtures.dart' show myPuuid;
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  group('重試', retryTests);
  group('路由', routingTests);
  group('計分板加強版', scoreboardTests);
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
      // 最近 5 場也會顯示 ACS，所以只檢查 ACS 欄。
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('acs-puuid-1')),
              matching: find.text('191'),
              matchRoot: true),
          findsOneWidget);
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

void scoreboardTests() {
  Future<Harness> detailHarness(WidgetTester tester,
      {List<http.Request>? requests,
      Map<String, int> otherHistoryStatus = const {},
      bool unratedTiers = false,
      Set<String> otherMmrHidden = const {},
      Map<String, int> otherMmrStatus = const {}}) async {
    final h = await Harness.create(tester,
        riotHttp: riotClient(
            historyTotal: 3,
            requests: requests,
            otherHistoryStatus: otherHistoryStatus,
            unratedTiers: unratedTiers,
            otherMmrHidden: otherMmrHidden,
            otherMmrStatus: otherMmrStatus));
    await tester.runAsync(() async {
      await h.riot.login(fakeRedirect);
      await h.matchHistory.loadFirstPage();
    });
    return h;
  }

  Route<dynamic> recordRoute(RouteSettings s) => MaterialPageRoute<void>(
        settings: s,
        builder: (_) =>
            Text('route:${s.name} ${(s.arguments as PlayerRef?)?.puuid ?? ''}'),
      );

  /// HTTP 回應要靠真實事件迴圈推進：輪流讓出時間與 pump，直到背景載入結束。
  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }
  }

  Finder inCell(String key, String text) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.text(text),
      matchRoot: true);

  testWidgets('新欄位、表現分數、K/D 與 MVP 標籤', (tester) async {
    setWidth(tester, 2000);
    final h = await detailHarness(tester);
    await tester.pumpWidget(h.wrap(home: const MatchDetailPage(matchId: 'm1')));
    await tester.pumpAndSettle();
    for (final t in ['表現分數', 'K/D/A', 'K/D', 'ACS', '爆頭率', '最近 5 場']) {
      expect(find.text(t), findsNWidgets(2));
    }
    // 使用者要求：移除牌位／ADR／首殺／等級欄與特務名稱。
    for (final t in ['牌位', 'ADR', '首殺', '等級', '蓋克', '菲德']) {
      expect(find.text(t), findsNothing, reason: t);
    }
    // 牌位改成最前面的小圖示（滑鼠移上去顯示名稱），等級放在名稱後面。
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('rank-puuid-1')),
            matching: find
                .byWidgetPredicate((w) => w is Tooltip && w.message == '鑽石 2'),
            matchRoot: true),
        findsOneWidget);
    expect(inCell('level-puuid-1', 'Lv 100'), findsOneWidget);
    final name = tester.getTopRight(find.text('Alpha#TW1')).dx;
    final level =
        tester.getTopLeft(find.byKey(const ValueKey('level-puuid-1'))).dx;
    expect(level, greaterThan(name));
    expect(inCell('mvp-r1', '全場 MVP'), findsOneWidget);
    expect(inCell('mvp-puuid-1', '隊伍 MVP'), findsOneWidget);
    expect(find.byKey(const ValueKey('mvp-mate')), findsNothing);
    expect(inCell('rating-puuid-1', '265'), findsOneWidget);
    expect(inCell('rating-mate', '—'), findsOneWidget);
    expect(inCell('kd-puuid-1', '1.67'), findsOneWidget);
  });

  testWidgets('最近 5 場：載入中、完成、失敗', (tester) async {
    setWidth(tester, 2000);
    final h = await detailHarness(tester, otherHistoryStatus: {'r2': 403});
    await tester.pumpWidget(h.wrap(home: const MatchDetailPage(matchId: 'm1')));
    await tester.pump();
    await tester.pump();
    expect(inCell('form-r1', '…'), findsOneWidget);
    await drain(tester);
    expect(find.byKey(const ValueKey('form-r1-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('form-r1-4')), findsOneWidget);
    expect(inCell('form-r1', '平均 227'), findsOneWidget);
    expect(inCell('form-r2', '—'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('點其他玩家進入玩家頁，點自己切到對戰紀錄', (tester) async {
    setWidth(tester, 2000);
    final h = await detailHarness(tester);
    await tester.pumpWidget(h.wrap(
        home: const MatchDetailPage(matchId: 'm1'),
        onGenerateRoute: recordRoute));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bravo#TW1'));
    await tester.pumpAndSettle();
    expect(find.text('route:/players/detail mate'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha#TW1'));
    await tester.pumpAndSettle();
    expect(find.text('route:/matches '), findsOneWidget);
    expect(find.byType(MatchDetailPage), findsNothing);
  });

  testWidgets('離開詳情頁後不再開始新玩家的請求', (tester) async {
    setWidth(tester, 2000);
    final requests = <http.Request>[];
    final h = await detailHarness(tester, requests: requests);
    requests.clear();
    await tester.pumpWidget(h.wrap(home: const MatchDetailPage(matchId: 'm1')));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(h.wrap(home: const SizedBox()));
    await drain(tester);
    final histories = requests
        .where((r) => r.url.path.startsWith('/match-history/v1/history/'))
        .length;
    expect(histories, lessThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('A → B → 返回 A：A 的最近 5 場仍會載完', (tester) async {
    setWidth(tester, 2000);
    final h = await detailHarness(tester);
    await tester.pumpWidget(h.wrap(home: const MatchDetailPage(matchId: 'm1')));
    await tester.pump();
    await tester.pump();
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(
        builder: (_) => const MatchDetailPage(matchId: 'm2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.byType(MatchDetailPage), findsOneWidget);
    await drain(tester);
    for (final p in ['r1', 'r2', 'r3', 'r4', 'b3', 'b4', 'b5', 'mate']) {
      expect(h.recentForm.status(p, queue: 'competitive'), FormStatus.done,
          reason: p);
    }
  });

  testWidgets('寬螢幕時兩隊上下排列、欄位不被截斷、有隊伍標題', (tester) async {
    setWidth(tester, 1300);
    final h = await detailHarness(tester);
    await tester.pumpWidget(h.wrap(home: const MatchDetailPage(matchId: 'm1')));
    await tester.pumpAndSettle();
    final blue = tester.getTopLeft(find.byKey(const ValueKey('team-Blue')));
    final red = tester.getTopLeft(find.byKey(const ValueKey('team-Red')));
    expect(red.dy, greaterThan(blue.dy));
    expect(red.dx, blue.dx);
    for (final header in find.text('最近 5 場').evaluate()) {
      final right = tester.getTopRight(find.byWidget(header.widget)).dx;
      expect(right, lessThanOrEqualTo(1300));
    }
    expect(find.text('我方・勝利'), findsOneWidget);
    expect(find.text('敵方・落敗'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('這場沒有牌位時改顯示查到的這季牌位', (tester) async {
    setWidth(tester, 2000);
    final h = await detailHarness(tester, unratedTiers: true);
    await tester.pumpWidget(h.wrap(home: const MatchDetailPage(matchId: 'm1')));
    await tester.pump();
    Tooltip rank(String id) =>
        tester.widget<Tooltip>(find.byKey(ValueKey('rank-$id')));
    // 確認公開前不顯示任何牌位。
    expect(rank('r1').message, '確認牌位是否公開中');
    await drain(tester);
    expect(rank('r1').message, '超凡 1');
    expect(rank('mate').message, '超凡 1');
  });

  testWidgets('他人牌位：確認公開才顯示，隱藏或無法確認都不顯示，自己永遠顯示', (tester) async {
    setWidth(tester, 2000);
    final h = await detailHarness(tester,
        otherMmrHidden: {'r2'}, otherMmrStatus: {'r3': 403});
    await tester.pumpWidget(h.wrap(home: const MatchDetailPage(matchId: 'm1')));
    await tester.pump();
    String rank(String id) =>
        tester.widget<Tooltip>(find.byKey(ValueKey('rank-$id'))).message!;
    // 還沒查到 MMR：不先顯示比賽裡的牌位。
    expect(rank('r1'), '確認牌位是否公開中');
    expect(rank(myPuuid), '鑽石 2');
    await drain(tester);
    expect(rank('r1'), '白金 1');
    expect(rank('r2'), '玩家已隱藏牌位');
    expect(rank('r3'), '無法確認是否公開，不顯示');
    expect(rank(myPuuid), '鑽石 2');
    expect(find.byKey(const ValueKey('rank-hidden-r2')), findsOneWidget);
  });
}
