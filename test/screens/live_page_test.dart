import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/match_models.dart';
import 'package:valorant_shop_tracker/screens/live_page.dart';
import 'package:valorant_shop_tracker/shell/nav_items.dart';

import '../app_harness.dart';
import '../live_fixtures.dart';
import '../match_fixtures.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  Future<Harness> harness(WidgetTester tester,
      {int partyStatus = 200,
      Set<String> otherMmrHidden = const {},
      Map<String, dynamic>? party}) async {
    final h = await Harness.create(tester,
        riotHttp: riotClient(
            partyStatus: partyStatus,
            otherMmrHidden: otherMmrHidden,
            party: party));
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    return h;
  }

  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }
  }

  Route<dynamic> recordRoute(RouteSettings s) => MaterialPageRoute<void>(
        settings: s,
        builder: (_) =>
            Text('route:${s.name} ${(s.arguments as PlayerRef?)?.puuid ?? ''}'),
      );

  /// 離開頁面，讓 10 秒的計時器被取消。
  Future<void> leave(WidgetTester tester, Harness h) async {
    await tester.pumpWidget(h.wrap(home: const SizedBox()));
  }

  Finder inKey(String key, String text) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.text(text),
      matchRoot: true);

  test('側邊導覽有「即時對局」', () {
    expect(
        navItems.any((n) => n.route == '/live' && n.label == '即時對局'), isTrue);
  });

  testWidgets('隊伍狀態列與成員卡片', (tester) async {
    setWidth(tester, 1400);
    final h = await harness(tester);
    await tester.pumpWidget(h.wrap(home: const LivePage()));
    await drain(tester);
    expect(find.text('隊伍・大廳'), findsOneWidget);
    expect(find.textContaining('一般'), findsWidgets);
    expect(find.textContaining('不公開'), findsOneWidget);
    expect(inKey('live-name-$myPuuid', 'Tester#TW1'), findsOneWidget);
    expect(inKey('live-name-mate', 'N-mate#TW1'), findsOneWidget);
    expect(find.byKey(const ValueKey('live-owner-$myPuuid')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-owner-mate')), findsNothing);
    expect(find.text('未準備'), findsOneWidget);
    expect(find.textContaining('請勿公開或分享他人資訊'), findsOneWidget);
    await leave(tester, h);
  });

  testWidgets('隱藏名稱、隱藏等級、隱藏牌位都不顯示', (tester) async {
    setWidth(tester, 1400);
    final h = await harness(tester, otherMmrHidden: {'mate'});
    await tester.pumpWidget(h.wrap(home: const LivePage()));
    await drain(tester);
    expect(inKey('live-name-ghost', '已隱藏名稱'), findsOneWidget);
    expect(find.byKey(const ValueKey('live-level-shy')), findsNothing);
    expect(inKey('live-level-mate', 'Lv 100'), findsOneWidget);
    String rank(String id) =>
        tester.widget<Tooltip>(find.byKey(ValueKey('live-rank-$id'))).message!;
    expect(rank('mate'), '玩家已隱藏牌位');
    expect(rank('shy'), '白金 1');
    expect(rank(myPuuid), isNot('玩家已隱藏牌位'));
    await leave(tester, h);
  });

  testWidgets('點隊友進入玩家頁，點自己到對戰紀錄，隱藏名稱的不能點', (tester) async {
    setWidth(tester, 1400);
    // 導頁會移除頁面；不載入玩家卡圖片，避免測試環境的網路圖片錯誤。
    final h = await harness(tester, party: partyJson(cards: false));
    await tester.pumpWidget(
        h.wrap(home: const LivePage(), onGenerateRoute: recordRoute));
    await drain(tester);
    await tester.tap(find.byKey(const ValueKey('live-member-ghost')));
    await tester.pumpAndSettle();
    expect(find.textContaining('route:'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('live-member-mate')));
    await tester.pumpAndSettle();
    expect(find.text('route:/players/detail mate'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('live-member-$myPuuid')));
    await tester.pumpAndSettle();
    expect(find.text('route:/matches '), findsOneWidget);
    await leave(tester, h);
  });

  testWidgets('不在大廳時顯示提示', (tester) async {
    setWidth(tester, 1400);
    final h = await harness(tester, partyStatus: 404);
    await tester.pumpWidget(h.wrap(home: const LivePage()));
    await drain(tester);
    expect(find.text('遊戲沒有開啟，或目前不在大廳'), findsOneWidget);
    await leave(tester, h);
  });

  testWidgets('未登入時引導登入', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const LivePage()));
    await tester.pump();
    expect(find.text('登入 Riot 以查看即時對局'), findsOneWidget);
    await leave(tester, h);
  });
}
