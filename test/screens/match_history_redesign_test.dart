import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/screens/match_history_page.dart';
import 'package:agent_t/theme/theme_ids.dart';
import 'package:agent_t/widgets/hud/hud.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';

/// 規格 2026-10-22-match-history-redesign-design.md。
void main() {
  Future<Harness> open(WidgetTester tester,
      {double width = 1440, ThemeChoice choice = const ThemeChoice()}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 2400);
    addTearDown(tester.view.reset);
    final h =
        await Harness.create(tester, riotHttp: riotClient(historyTotal: 3));
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    await tester
        .pumpWidget(h.wrap(choice: choice, home: const MatchHistoryPage()));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
    return h;
  }

  Finder inCard(String id, Finder f) =>
      find.descendant(of: find.byKey(ValueKey('match-card-$id')), matching: f);

  testWidgets('卡片顯示 ACS、ADR、爆頭率、表現分數、MVP、RR 與結果', (tester) async {
    await open(tester);
    expect(inCard('m1', find.text('勝利')), findsOneWidget);
    expect(inCard('m1', find.text('13 : 9')), findsOneWidget);
    expect(inCard('m1', find.text('20 / 12 / 4')), findsOneWidget);
    expect(inCard('m1', find.text('ACS')), findsOneWidget);
    expect(inCard('m1', find.text('191')), findsOneWidget);
    expect(inCard('m1', find.text('ADR')), findsOneWidget);
    expect(inCard('m1', find.text('爆頭率')), findsOneWidget);
    expect(inCard('m1', find.text('30%')), findsOneWidget);
    expect(inCard('m1', find.text('表現')), findsOneWidget);
    expect(inCard('m1', find.text('265')), findsOneWidget);
    expect(inCard('m1', find.text('1.67')), findsOneWidget);
    expect(inCard('m1', find.text('+18')), findsOneWidget);
    expect(inCard('m1', find.widgetWithText(StatusChip, '隊伍 MVP')),
        findsOneWidget);
    expect(inCard('m1', find.byKey(const ValueKey('match-card-bg'))),
        findsOneWidget);
  });

  testWidgets('依日期分組，標題有勝敗統計', (tester) async {
    await open(tester);
    final headers = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('day-header-'));
    expect(headers, findsWidgets);
    expect(
        find.descendant(of: headers.first, matching: find.textContaining('勝')),
        findsOneWidget);
  });

  testWidgets('頁首多了平均 K/D、爆頭率與近期戰績', (tester) async {
    await open(tester);
    expect(find.widgetWithText(KpiTile, '平均 K/D'), findsOneWidget);
    expect(find.widgetWithText(KpiTile, '爆頭率'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-form')), findsOneWidget);
    expect(find.byKey(const ValueKey('form-m1')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-top-agents')), findsOneWidget);
  });

  testWidgets('窄卡片分兩段：數據在特務頭像下方', (tester) async {
    await open(tester, width: 360);
    final agent = tester.getRect(find.byKey(const ValueKey('card-agent-m1')));
    final acs = tester.getRect(inCard('m1', find.text('ACS')));
    expect(acs.top, greaterThan(agent.bottom));
  });

  testWidgets('寬卡片一列排完：數據與特務頭像同一列', (tester) async {
    await open(tester, width: 1440);
    final agent = tester.getRect(find.byKey(const ValueKey('card-agent-m1')));
    final acs = tester.getRect(inCard('m1', find.text('ACS')));
    expect(acs.top, lessThan(agent.bottom));
    expect(acs.left, greaterThan(agent.right));
  });

  for (final style in ThemeStyleId.values) {
    for (final width in [360.0, 768.0, 1440.0]) {
      testWidgets('${style.name} @ ${width.toInt()} 不 overflow',
          (tester) async {
        await open(tester, width: width, choice: ThemeChoice(style: style));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('match-card-m1')), findsOneWidget);
      });
    }
  }
}
