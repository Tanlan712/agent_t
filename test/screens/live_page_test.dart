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

  testWidgets('使用者決定：隱藏的名稱、等級、牌位也直接顯示，不加標籤', (tester) async {
    setWidth(tester, 1400);
    final h = await harness(tester, otherMmrHidden: {'mate'});
    await tester.pumpWidget(h.wrap(home: const LivePage()));
    await drain(tester);
    expect(inKey('live-name-ghost', 'N-ghost#TW1'), findsOneWidget);
    // 使用者要求：不加「隱藏名稱」標籤。
    expect(find.text('隱藏名稱'), findsNothing);
    expect(inKey('live-level-shy', 'Lv 100'), findsOneWidget);
    String rank(String id) =>
        tester.widget<Tooltip>(find.byKey(ValueKey('live-rank-$id'))).message!;
    expect(rank('mate'), '鑽石 2');
    expect(rank('shy'), '白金 1');
    await leave(tester, h);
  });

  testWidgets('點隊友（含隱藏名稱的）進入玩家頁，點自己到對戰紀錄', (tester) async {
    setWidth(tester, 1400);
    // 導頁會移除頁面；不載入玩家卡圖片，避免測試環境的網路圖片錯誤。
    final h = await harness(tester, party: partyJson(cards: false));
    await tester.pumpWidget(
        h.wrap(home: const LivePage(), onGenerateRoute: recordRoute));
    await drain(tester);
    await tester.tap(find.byKey(const ValueKey('live-member-ghost')));
    await tester.pumpAndSettle();
    expect(find.text('route:/players/detail ghost'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
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

  testWidgets('排隊時間只在配對中顯示（Riot 會保留上次排隊的時間）', (tester) async {
    setWidth(tester, 1400);
    final entry = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 3))
        .toIso8601String();
    var h = await harness(tester,
        party: partyJson(state: 'DEFAULT', queueEntryTime: entry));
    await tester.pumpWidget(h.wrap(home: const LivePage()));
    await drain(tester);
    expect(find.textContaining('已排隊'), findsNothing);
    await leave(tester, h);

    h = await harness(tester,
        party: partyJson(state: 'MATCHMAKING', queueEntryTime: entry));
    await tester.pumpWidget(h.wrap(home: const LivePage()));
    await drain(tester);
    expect(find.textContaining('已排隊 3:'), findsOneWidget);
    await leave(tester, h);
  });

  testWidgets('開了隱藏等級也顯示等級（自己和隊友）', (tester) async {
    setWidth(tester, 1400);
    final party = partyJson();
    for (final m in (party['Members'] as List).cast<Map<String, dynamic>>()) {
      (m['PlayerIdentity'] as Map<String, dynamic>)['HideAccountLevel'] = true;
    }
    final h = await harness(tester, party: party);
    await tester.pumpWidget(h.wrap(home: const LivePage()));
    await drain(tester);
    expect(inKey('live-level-$myPuuid', 'Lv 100'), findsOneWidget);
    // 使用者決定：他人隱藏等級也照樣顯示。
    expect(inKey('live-level-mate', 'Lv 100'), findsOneWidget);
    await leave(tester, h);
  });
}
