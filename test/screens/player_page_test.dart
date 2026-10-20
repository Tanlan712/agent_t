import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/app_routes.dart';
import 'package:valorant_shop_tracker/models/match_models.dart';
import 'package:valorant_shop_tracker/screens/match_detail_page.dart';
import 'package:valorant_shop_tracker/screens/player_page.dart';

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

  testWidgets('標題、平均 ACS、他的 K/D/A 與隱私提示', (tester) async {
    setWidth(tester, 1400);
    final h = await harness(tester);
    await tester.pumpWidget(h.wrap(
        home: const PlayerPage(player: foxtrot),
        onGenerateRoute: onGenerateAppRoute));
    await drain(tester);
    expect(find.text('Foxtrot#TW1'), findsOneWidget);
    expect(find.text('最近 5 場平均 ACS 227'), findsOneWidget);
    expect(find.text('10 / 10 / 5'), findsWidgets);
    expect(find.text('ACS 227'), findsWidgets);
    // 一頁 20 場，頁尾提示要捲到底才會建立。
    await tester.scrollUntilVisible(
        find.text('名稱資料來自 Riot，請勿公開或分享他人資訊'), 600,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('名稱資料來自 Riot，請勿公開或分享他人資訊'), findsOneWidget);
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
