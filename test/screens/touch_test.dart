import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/app_routes.dart';
import 'package:agent_t/logic/suspicion.dart';
import 'package:agent_t/models/match_models.dart';
import 'package:agent_t/screens/live_page.dart';
import 'package:agent_t/screens/match_detail_page.dart';
import 'package:agent_t/screens/match_history_page.dart';
import 'package:agent_t/screens/player_page.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

/// 手機觸控：只放在提示裡的資訊要能用點的看到，寬表格在窄螢幕可橫向捲動。
void main() {
  Future<Harness> loggedIn(WidgetTester tester, {int coreStatus = 404}) async {
    final h = await Harness.create(tester,
        riotHttp: riotClient(coreStatus: coreStatus));
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

  Future<void> leave(WidgetTester tester, Harness h) =>
      tester.pumpWidget(h.wrap(home: const SizedBox()));

  testWidgets('360 寬：點疑似小號標籤開出原因對話框', (tester) async {
    // 拉高視窗讓標籤直接在畫面內，不必捲動。
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 2000);
    addTearDown(tester.view.reset);
    final h = await loggedIn(tester, coreStatus: 200);
    await tester.pumpWidget(h.wrap(
        home: const LivePage(
            rules: SuspicionRules(lowLevel: 60, smurfMinAcs: 200))));
    await drain(tester);
    expect(tester.takeException(), isNull);
    final tag = find.byKey(const ValueKey('sus-tap-r1'));
    await tester.tap(tag);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.textContaining('Lv 50')),
        findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.textContaining('推測')),
        findsOneWidget);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    await leave(tester, h);
  });

  testWidgets('即時對局的牌位、特務圖示點一下就顯示名稱', (tester) async {
    setWidth(tester, 360);
    final h = await loggedIn(tester, coreStatus: 200);
    await tester.pumpWidget(h.wrap(home: const LivePage()));
    await drain(tester);
    for (final key in ['live-rank-r1', 'live-agent-r1']) {
      expect(tester.widget<Tooltip>(find.byKey(ValueKey(key))).triggerMode,
          TooltipTriggerMode.tap,
          reason: key);
    }
    await leave(tester, h);
  });

  testWidgets('360 寬：對戰詳情不 overflow，計分板可橫向捲動，牌位點一下顯示名稱', (tester) async {
    setWidth(tester, 360);
    final h = await loggedIn(tester);
    await tester.runAsync(h.matchHistory.loadFirstPage);
    await tester.pumpWidget(h.wrap(home: const MatchDetailPage(matchId: 'm1')));
    await drain(tester);
    expect(tester.takeException(), isNull);
    final table = find.byType(DataTable).first;
    final scroll = find.ancestor(
        of: table,
        matching: find.byWidgetPredicate((w) =>
            w is SingleChildScrollView &&
            w.scrollDirection == Axis.horizontal));
    expect(scroll, findsOneWidget);
    final rank = find.byKey(const ValueKey('rank-r1'));
    expect(tester.widget<Tooltip>(rank).triggerMode, TooltipTriggerMode.tap);
    await leave(tester, h);
  });

  testWidgets('360 寬：玩家頁不 overflow', (tester) async {
    setWidth(tester, 360);
    final h = await loggedIn(tester);
    await tester.pumpWidget(h.wrap(
        home: const PlayerPage(
            player: PlayerRef(puuid: 'r1', riotId: 'Foxtrot#TW1')),
        onGenerateRoute: onGenerateAppRoute));
    await drain(tester);
    expect(tester.takeException(), isNull);
    await leave(tester, h);
  });

  testWidgets('360 寬：對戰紀錄不 overflow', (tester) async {
    // 卡片在 KPI 與圖表下方；拉高視窗讓卡片也建出來。
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 3000);
    addTearDown(tester.view.reset);
    final h = await loggedIn(tester);
    await tester.runAsync(h.matchHistory.loadFirstPage);
    await tester.pumpWidget(h.wrap(home: const MatchHistoryPage()));
    await drain(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('match-card-m1')), findsOneWidget);
    await leave(tester, h);
  });
}
