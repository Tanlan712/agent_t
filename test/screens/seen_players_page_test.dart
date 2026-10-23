import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/widgets/hud/hud.dart';
import 'package:agent_t/app_routes.dart';
import 'package:agent_t/logic/match_mapper.dart';
import 'package:agent_t/screens/player_page.dart';
import 'package:agent_t/screens/seen_players_page.dart';
import 'package:agent_t/shell/nav_items.dart';

import '../app_harness.dart';
import '../match_fixtures.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  Future<Harness> seeded(WidgetTester tester) async {
    final h = await Harness.create(tester);
    await tester.runAsync(() async {
      await h.riot.login(fakeRedirect);
      await h.seenPlayers
          .recordAll([mapMatchDetail(matchDetailsJson(), myPuuid)]);
    });
    return h;
  }

  Future<void> open(WidgetTester tester, Harness h) async {
    await tester.pumpWidget(h.wrap(
        home: const SeenPlayersPage(), onGenerateRoute: onGenerateAppRoute));
    await tester.pumpAndSettle();
  }

  test('側邊導覽有「遇過的玩家」', () {
    expect(navItems.any((n) => n.route == '/players' && n.label == '遇過的玩家'),
        isTrue);
  });

  testWidgets('列出遇過的玩家與隱私提示', (tester) async {
    setWidth(tester, 1400);
    final h = await seeded(tester);
    await open(tester, h);
    expect(find.text('Foxtrot#TW1'), findsOneWidget);
    expect(find.text('Bravo#TW1'), findsOneWidget);
    expect(find.text('Alpha#TW1'), findsNothing);
    expect(find.textContaining('請勿公開或分享他人資訊'), findsOneWidget);
  });

  testWidgets('Bento：1440 寬玩家卡片多欄排列，頁首顯示人數', (tester) async {
    setWidth(tester, 1440);
    final h = await seeded(tester);
    await open(tester, h);
    final tops = [
      for (final e in find.byType(PanelCard).evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dy,
    ];
    expect(tops.length, greaterThan(1));
    expect(tops.toSet().length, lessThan(tops.length));
    expect(find.byType(PanelCard), findsWidgets);
    expect(find.textContaining('位玩家'), findsOneWidget);
  });

  testWidgets('玩家卡片高度固定 88，不隨寬度變形', (tester) async {
    for (final width in [575.0, 1440.0]) {
      setWidth(tester, width);
      final h = await seeded(tester);
      await open(tester, h);
      final card = find
          .ancestor(
              of: find.text('Foxtrot#TW1'), matching: find.byType(PanelCard))
          .first;
      expect(tester.getSize(card).height, 88, reason: '$width');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('搜尋 Riot ID', (tester) async {
    setWidth(tester, 1400);
    final h = await seeded(tester);
    await open(tester, h);
    await tester.enterText(find.byType(TextField), 'fox');
    await tester.pumpAndSettle();
    expect(find.text('Foxtrot#TW1'), findsOneWidget);
    expect(find.text('Bravo#TW1'), findsNothing);
  });

  testWidgets('點玩家進入玩家頁', (tester) async {
    setWidth(tester, 1400);
    final h = await seeded(tester);
    await open(tester, h);
    await tester.tap(find.text('Foxtrot#TW1'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerPage), findsOneWidget);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  });

  testWidgets('刪除單筆與全部清除（需確認）', (tester) async {
    setWidth(tester, 1400);
    final h = await seeded(tester);
    await open(tester, h);
    await tester.tap(find.byKey(const ValueKey('seen-delete-r1')));
    await tester.pumpAndSettle();
    expect(find.text('Foxtrot#TW1'), findsNothing);
    expect(h.seenPlayers.players.length, 8);

    await tester.tap(find.text('全部清除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(h.seenPlayers.players.length, 8);

    await tester.tap(find.text('全部清除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清除'));
    await tester.pumpAndSettle();
    expect(h.seenPlayers.players, isEmpty);
    expect(find.text('還沒有遇過的玩家'), findsOneWidget);
  });

  testWidgets('搜尋不到時顯示 EmptyState', (tester) async {
    setWidth(tester, 1400);
    final h = await seeded(tester);
    await open(tester, h);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('找不到符合的玩家'), findsOneWidget);
  });
}
