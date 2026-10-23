import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/widgets/hud/hud.dart';
import 'package:http/http.dart' as http;
import 'package:agent_t/models/match_models.dart';
import 'package:agent_t/screens/live_page.dart';
import 'package:agent_t/shell/nav_items.dart';

import '../app_harness.dart';
import '../live_fixtures.dart';
import '../match_fixtures.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  Future<Harness> harness(WidgetTester tester,
      {int partyStatus = 200,
      int coreStatus = 404,
      int pregameStatus = 404,
      Set<String> otherMmrHidden = const {},
      Map<String, int> otherMmrStatus = const {},
      Map<String, dynamic>? party}) async {
    final h = await Harness.create(tester,
        riotHttp: riotClient(
            partyStatus: partyStatus,
            coreStatus: coreStatus,
            pregameStatus: pregameStatus,
            otherMmrHidden: otherMmrHidden,
            otherMmrStatus: otherMmrStatus,
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

  Finder statIn(String key, String text) => find.descendant(
      of: find.byKey(ValueKey(key)), matching: find.textContaining(text));

  for (final width in [1400.0, 375.0]) {
    testWidgets('${width.toInt()} 寬：隊伍卡片顯示最近一場、目前牌位與 RR、歷史最高與賽季',
        (tester) async {
      setWidth(tester, width);
      final h = await harness(tester);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('stats-last-mate')));
      expect(statIn('stats-current-mate', '超凡 1・40 RR'), findsOneWidget);
      expect(statIn('stats-peak-mate', '超凡 1・V26 第六幕'), findsOneWidget);
      expect(statIn('stats-last-mate', '競技'), findsOneWidget);
      expect(statIn('stats-last-mate', '10 / 10 / 5'), findsOneWidget);
      expect(statIn('stats-last-mate', 'ACS 159'), findsOneWidget);
      // 自己的 MMR 沒有本幕資料：未定級。
      expect(statIn('stats-current-$myPuuid', '未定級'), findsOneWidget);
      // 隊伍卡片不顯示總覽。
      expect(find.byKey(const ValueKey('stats-summary-mate')), findsNothing);
      expect(tester.takeException(), isNull);
      await leave(tester, h);
    });
  }

  testWidgets('隊友的 MMR 讀取失敗時，牌位顯示無法取得、最近一場照常', (tester) async {
    setWidth(tester, 1400);
    final h = await harness(tester, otherMmrStatus: {'mate': 500});
    await tester.pumpWidget(h.wrap(home: const LivePage()));
    await drain(tester);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(statIn('stats-current-mate', '無法取得'), findsOneWidget);
    expect(statIn('stats-last-mate', '10 / 10 / 5'), findsOneWidget);
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

  group('即時對戰', () {
    testWidgets('對局中自動切換：地圖、模式、雙方隊伍、名稱、特務、牌位、教練', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, coreStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.text('亞海懸城'), findsOneWidget);
      expect(find.text('競技'), findsOneWidget);
      expect(find.text('我方'), findsOneWidget);
      expect(find.text('敵方'), findsOneWidget);
      expect(find.text('隊伍・大廳'), findsNothing);
      expect(inKey('live-name-r1', 'N-r1#TW1'), findsOneWidget);
      expect(inKey('live-name-r2', 'N-r2#TW1'), findsOneWidget);
      expect(inKey('live-name-$myPuuid', 'Tester#TW1'), findsOneWidget);
      String tip(String key) =>
          tester.widget<Tooltip>(find.byKey(ValueKey(key))).message!;
      expect(tip('live-agent-$myPuuid'), '蓋克');
      expect(tip('live-rank-r1'), '鑽石 2');
      expect(find.text('教練'), findsOneWidget);
      await leave(tester, h);
    });

    testWidgets('每位玩家的最近 5 場與平均 ACS（同模式），教練不查', (tester) async {
      setWidth(tester, 1400);
      final requests = <http.Request>[];
      final h = await Harness.create(tester,
          riotHttp: riotClient(coreStatus: 200, requests: requests));
      await tester.runAsync(() => h.riot.login(fakeRedirect));
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      await drain(tester);
      expect(find.byKey(const ValueKey('form-r1-0')), findsOneWidget);
      expect(inKey('form-r1', '平均 227'), findsOneWidget);
      final all = requests
          .where((r) => r.url.path.startsWith('/match-history/v1/history/'))
          .toList();
      // 自己另外有一次不限模式的掃描（標示遇過的玩家用）。
      bool scan(http.Request r) =>
          r.url.path.endsWith('/$myPuuid') &&
          !r.url.queryParameters.containsKey('queue');
      expect(all.where(scan), isNotEmpty);
      final histories = all.where((r) => !scan(r)).toList();
      expect(
          histories
              .every((r) => r.url.queryParameters['queue'] == 'competitive'),
          isTrue);
      expect(histories.any((r) => r.url.path.endsWith('/coach')), isFalse);
      await leave(tester, h);
    });

    testWidgets('之前同場打過的玩家標示「遇過」，點開列出日期、地圖、隊友或對手與勝負', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, coreStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      await drain(tester);
      // 假資料的每一場歷史都有 r1（對手）與 mate（隊友），自己贏；每人只留最近 5 場。
      expect(inKey('met-tap-r1', '遇過 5+'), findsOneWidget);
      expect(inKey('met-tap-mate', '遇過 5+'), findsOneWidget);
      expect(find.byKey(const ValueKey('met-$myPuuid')), findsNothing);
      // 教練不在歷史場次裡。
      expect(find.byKey(const ValueKey('met-coach')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('met-tap-r1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('當對手 5 場（5 勝 0 敗）'), findsOneWidget);
      expect(find.textContaining('亞海懸城・競技・對手・勝'), findsOneWidget);
      await tester.tap(find.text('關閉'));
      await tester.pumpAndSettle();
      await leave(tester, h);
    });

    testWidgets('點對局中的玩家進入玩家頁', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, coreStatus: 200);
      await tester.pumpWidget(
          h.wrap(home: const LivePage(), onGenerateRoute: recordRoute));
      await drain(tester);
      await tester.tap(find.byKey(const ValueKey('live-player-r1')));
      await tester.pumpAndSettle();
      expect(find.text('route:/players/detail r1'), findsOneWidget);
      await leave(tester, h);
    });

    testWidgets('選角中顯示選角提示', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, pregameStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.textContaining('選角中'), findsOneWidget);
      await leave(tester, h);
    });
  });

  group('即時對戰實測修正', () {
    testWidgets('Rank 為 0 時改顯示查到的這季牌位', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, coreStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      await drain(tester);
      String tip(String key) =>
          tester.widget<Tooltip>(find.byKey(ValueKey(key))).message!;
      expect(tip('live-rank-r3'), '超凡 1');
      expect(tip('live-rank-r1'), '鑽石 2');
      await leave(tester, h);
    });

    testWidgets('等級為 0 不顯示；查不到名稱顯示未知玩家', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, coreStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.byKey(const ValueKey('live-level-r4')), findsNothing);
      expect(inKey('live-level-r1', 'Lv 50'), findsOneWidget);
      // fixture 的 name-service 對 r5 回傳空名稱。
      expect(inKey('live-name-r5', '未知玩家'), findsOneWidget);
      await leave(tester, h);
    });
  });

  group('選角畫面', () {
    testWidgets('地圖、模式、剩餘時間、敵方人數與鎖定數', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, pregameStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.text('亞海懸城'), findsOneWidget);
      expect(find.text('競技'), findsOneWidget);
      expect(find.text('選角中'), findsOneWidget);
      expect(find.byKey(const ValueKey('pregame-remaining')), findsOneWidget);
      expect(find.textContaining('秒'), findsWidgets);
      expect(find.text('敵方 5 人，已鎖定 2 人'), findsOneWidget);
      await leave(tester, h);
    });

    testWidgets('我方成員：特務、選角狀態、名稱、牌位、最近 5 場', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, pregameStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      await drain(tester);
      expect(inKey('pregame-state-mate', '已鎖定'), findsOneWidget);
      expect(inKey('pregame-state-$myPuuid', '已選'), findsOneWidget);
      expect(inKey('pregame-state-b3', '未選'), findsOneWidget);
      expect(inKey('live-name-mate', 'N-mate#TW1'), findsOneWidget);
      String tip(String key) =>
          tester.widget<Tooltip>(find.byKey(ValueKey(key))).message!;
      expect(tip('live-rank-mate'), '鑽石 2');
      expect(tip('live-rank-b4'), '超凡 1');
      expect(find.byKey(const ValueKey('live-level-b5')), findsNothing);
      expect(find.byKey(const ValueKey('form-mate-0')), findsOneWidget);
      await leave(tester, h);
    });

    testWidgets('點隊友進入玩家頁', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, pregameStatus: 200);
      await tester.pumpWidget(
          h.wrap(home: const LivePage(), onGenerateRoute: recordRoute));
      await drain(tester);
      await tester.tap(find.byKey(const ValueKey('live-player-mate')));
      await tester.pumpAndSettle();
      expect(find.text('route:/players/detail mate'), findsOneWidget);
      await leave(tester, h);
    });
  });

  group('對局造型', () {
    testWidgets('預設顯示主要武器的造型（預設造型不顯示），可以展開全部', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, coreStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      String tip(String key) =>
          tester.widget<Tooltip>(find.byKey(ValueKey(key))).message!;
      expect(tip('skin-mate-$vandalId'), 'Prime 幻象');
      expect(tip('skin-mate-$phantomId'), '離子 幻象');
      expect(tip('skin-mate-$sheriffId'), '凌空之志 奧丁');
      expect(tip('skin-mate-$meleeId'), '掠奪者 暴徒');
      expect(find.byKey(const ValueKey('skin-mate-$operatorId')), findsNothing);
      expect(find.byKey(const ValueKey('skin-mate-$ghostId')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('skins-more-mate')));
      await tester.pump();
      expect(find.byKey(const ValueKey('skin-mate-$ghostId')), findsOneWidget);
      expect(find.byKey(const ValueKey('skin-mate-$operatorId')), findsNothing);
      // 全部是預設造型的玩家不顯示造型列。
      expect(find.byKey(const ValueKey('skins-$myPuuid')), findsNothing);
      await leave(tester, h);
    });
  });

  group('小號／代打推測', () {
    testWidgets('預設門檻下 fixture 的玩家都不標示；最近 5 場仍只顯示 5 格', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, coreStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      await drain(tester);
      expect(find.byKey(const ValueKey('sus-r1')), findsNothing);
      expect(find.byKey(const ValueKey('form-r1-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-r1-5')), findsNothing);
      await leave(tester, h);
    });

    testWidgets('符合門檻時標示疑似小號，滑鼠提示列出原因與「推測」', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, coreStatus: 200);
      await tester
          .pumpWidget(h.wrap(home: LivePage(rules: levelAcsRules(200))));
      await drain(tester);
      await drain(tester);
      final tip = tester.widget<Tooltip>(find.byKey(const ValueKey('sus-r1')));
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('sus-r1')),
              matching: find.textContaining('疑似小號')),
          findsOneWidget);
      expect(tip.message, contains('Lv 50'));
      expect(tip.message, contains('推測'));
      expect(find.byKey(const ValueKey('sus-mate')), findsNothing);
      await leave(tester, h);
    });

    testWidgets('對局 10 人都判斷（包括自己），教練不判斷', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, coreStatus: 200);
      await tester
          .pumpWidget(h.wrap(home: LivePage(rules: levelAcsRules(150))));
      await drain(tester);
      await drain(tester);
      // fixture 的 ACS：自己 191、mate 159、r1 227，其餘低於 150。
      for (final id in [myPuuid, 'mate', 'r1']) {
        expect(find.byKey(ValueKey('sus-$id')), findsOneWidget, reason: id);
      }
      expect(find.byKey(const ValueKey('sus-b3')), findsNothing);
      expect(find.byKey(const ValueKey('sus-coach')), findsNothing);
      await leave(tester, h);
    });
  });

  group('戰術 HUD 即時對局', () {
    testWidgets('寬螢幕我方與敵方左右並排，窄螢幕上下排列', (tester) async {
      for (final (width, sideBySide) in [(1400.0, true), (800.0, false)]) {
        setWidth(tester, width);
        final h = await harness(tester, coreStatus: 200);
        await tester.pumpWidget(h.wrap(home: const LivePage()));
        await drain(tester);
        final blue =
            tester.getTopLeft(find.byKey(const ValueKey('live-team-Blue')));
        final red =
            tester.getTopLeft(find.byKey(const ValueKey('live-team-Red')));
        if (sideBySide) {
          expect(red.dy, blue.dy, reason: '$width');
          expect(red.dx, greaterThan(blue.dx));
        } else {
          expect(red.dy, greaterThan(blue.dy), reason: '$width');
        }
        expect(tester.takeException(), isNull);
        await leave(tester, h);
      }
    });

    testWidgets('Bento：地圖、模式、狀態三張 KPI 同一列，隊伍卡用 BentoGrid', (tester) async {
      setWidth(tester, 1440);
      final h = await harness(tester, coreStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      final ys = [
        for (final k in ['live-kpi-map', 'live-kpi-mode', 'live-kpi-state'])
          tester.getTopLeft(find.byKey(ValueKey(k))).dy,
      ];
      expect(ys.toSet().length, 1);
      expect(
          find.ancestor(
              of: find.byKey(const ValueKey('live-team-Blue')),
              matching: find.byType(BentoGrid)),
          findsOneWidget);
      await leave(tester, h);
    });

    testWidgets('375 寬地圖、模式兩張 KPI 同一列', (tester) async {
      setWidth(tester, 375);
      final h = await harness(tester, coreStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      final map = tester.getTopLeft(find.byKey(const ValueKey('live-kpi-map')));
      final mode =
          tester.getTopLeft(find.byKey(const ValueKey('live-kpi-mode')));
      expect(mode.dy, map.dy);
      await leave(tester, h);
    });

    testWidgets('疑似小號標籤是 StatusChip，不用 emoji', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, coreStatus: 200);
      await tester
          .pumpWidget(h.wrap(home: LivePage(rules: levelAcsRules(200))));
      await drain(tester);
      await drain(tester);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('sus-r1')),
              matching: find.byType(StatusChip)),
          findsOneWidget);
      expect(find.textContaining('⚠'), findsNothing);
      await leave(tester, h);
    });

    testWidgets('不在大廳時顯示 EmptyState', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, partyStatus: 404);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.byType(EmptyState), findsOneWidget);
      await leave(tester, h);
    });
  });
}
