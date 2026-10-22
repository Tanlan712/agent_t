import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:valorant_shop_tracker/screens/collection_page.dart';
import 'package:valorant_shop_tracker/screens/live_page.dart';
import 'package:valorant_shop_tracker/screens/settings_page.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';
import 'package:valorant_shop_tracker/widgets/remote_control_card.dart';

import '../app_harness.dart';
import '../live_fixtures.dart';
import '../match_fixtures.dart';
import '../progress_fixtures.dart';
import '../remote_fixtures.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  late List<http.Request> writes;

  Future<Harness> harness(WidgetTester tester,
      {bool consent = false,
      String? preferredAgent,
      int pregameStatus = 404,
      int coreStatus = 404,
      Map<String, dynamic>? party,
      Map<String, int> status = const {}}) async {
    writes = [];
    final h = await Harness.create(tester,
        riotHttp: remoteHttp(writes,
            status: status,
            inner: riotClient(
                pregameStatus: pregameStatus,
                coreStatus: coreStatus,
                party: party,
                skinLevels: [
                  'lv-vandal-1',
                  'lv-vandal-2',
                  'lv-phantom-1'
                ],
                entitlements: {
                  ItemTypes.skinChroma: ['ch-v-red'],
                  ItemTypes.agent: ['a-paid'],
                })),
        progressApi: FakeProgressApi());
    if (consent) {
      await tester.runAsync(() async {
        await h.settings.setRemoteControl(true);
        if (preferredAgent != null) {
          await h.settings.setPreferredAgent(preferredAgent);
        }
      });
    }
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

  Future<void> leave(WidgetTester tester, Harness h) async {
    await tester.pumpWidget(h.wrap(home: const SizedBox()));
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await drain(tester);
  }

  group('設定頁同意', () {
    Widget card(Harness h) => h.wrap(
        home: const Scaffold(
            body: SingleChildScrollView(child: RemoteControlCard())));

    testWidgets('設定頁有遠端操作卡片', (tester) async {
      setWidth(tester, 1200);
      final h = await harness(tester);
      await tester.pumpWidget(h.wrap(home: const SettingsPage()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('remote-control-card')), 300,
          scrollable: find
              .descendant(
                  of: find.byKey(const ValueKey('settings-list')),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.byType(RemoteControlCard), findsOneWidget);
    });

    testWidgets('預設關閉；開啟要先在對話框確認，取消則不變', (tester) async {
      setWidth(tester, 1200);
      final h = await harness(tester);
      await tester.pumpWidget(card(h));
      await tester.pumpAndSettle();
      expect(find.textContaining('服務條款'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('remote-consent-switch')));
      await tester.pumpAndSettle();
      expect(find.text('啟用遠端操作？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(h.settings.settings.remoteControl, isFalse);

      await tester.tap(find.byKey(const ValueKey('remote-consent-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('remote-consent-confirm')));
      await tester.pumpAndSettle();
      expect(h.settings.settings.remoteControl, isTrue);
      expect(find.text('已啟用遠端操作'), findsOneWidget);
    });

    testWidgets('關閉即撤回，不需要確認', (tester) async {
      setWidth(tester, 1200);
      final h = await harness(tester, consent: true, preferredAgent: 'a-paid');
      await tester.pumpWidget(card(h));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('remote-consent-switch')));
      await tester.pumpAndSettle();
      expect(h.settings.settings.remoteControl, isFalse);
      expect(h.settings.settings.preferredAgent, isNull);
    });
  });

  group('即時對局：隊伍', () {
    testWidgets('未同意時沒有任何遠端按鈕', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.text('隊伍・大廳'), findsOneWidget);
      expect(find.byKey(const ValueKey('remote-party')), findsNothing);
      expect(writes, isEmpty);
      await leave(tester, h);
    });

    testWidgets('隊長：開始排隊、開放隊伍、取得代碼、切換準備', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, consent: true);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.byKey(const ValueKey('remote-party')), findsOneWidget);
      // 進入頁面不會自動送出任何寫入。
      expect(writes, isEmpty);

      await tapKey(tester, 'remote-queue');
      await tapKey(tester, 'remote-access');
      await tapKey(tester, 'remote-invite-code');
      await tapKey(tester, 'remote-ready');
      expect([
        for (final r in writes) r.url.path
      ], [
        '/parties/v1/parties/$testPartyId/matchmaking/join',
        '/parties/v1/parties/$testPartyId/accessibility',
        '/parties/v1/parties/$testPartyId/invitecode',
        '/parties/v1/parties/$testPartyId/members/$myPuuid/setReady',
      ]);
      expect(find.text('ABC123'), findsOneWidget);
      await leave(tester, h);
    });

    testWidgets('排隊中顯示「取消排隊」', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester,
          consent: true, party: partyJson(state: 'MATCHMAKING'));
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.text('取消排隊'), findsOneWidget);
      await tapKey(tester, 'remote-queue');
      expect(writes.single.url.path,
          '/parties/v1/parties/$testPartyId/matchmaking/leave');
      await leave(tester, h);
    });

    testWidgets('不是隊長時只能切換準備', (tester) async {
      setWidth(tester, 1400);
      final p = partyJson();
      for (final m in (p['Members'] as List).cast<Map<String, dynamic>>()) {
        m['IsOwner'] = m['Subject'] == 'mate';
      }
      final h = await harness(tester, consent: true, party: p);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.byKey(const ValueKey('remote-ready')), findsOneWidget);
      for (final k in [
        'remote-queue',
        'remote-access',
        'remote-invite-code',
        'remote-queue-mode'
      ]) {
        expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
      }
      expect(find.textContaining('只有隊長'), findsOneWidget);
      await leave(tester, h);
    });

    testWidgets('失敗時顯示錯誤', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester,
          consent: true, status: {'/matchmaking/join': 409});
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      await tapKey(tester, 'remote-queue');
      // 寫入失敗不重試。
      expect(writes.length, 1);
      expect(find.text('開始排隊：伺服器回應 409'), findsOneWidget);
      await leave(tester, h);
    });
  });

  group('即時對局：選角', () {
    testWidgets('有預選特務時，按下才選擇或鎖定（不自動送出）', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester,
          consent: true, preferredAgent: 'agent-x', pregameStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.byKey(const ValueKey('remote-pregame')), findsOneWidget);
      expect(writes, isEmpty);
      await tapKey(tester, 'remote-select-agent');
      await tapKey(tester, 'remote-lock-agent');
      expect([
        for (final r in writes) r.url.path
      ], [
        '/pregame/v1/matches/$testPregameMatchId/select/agent-x',
        '/pregame/v1/matches/$testPregameMatchId/lock/agent-x',
      ]);
      await leave(tester, h);
    });

    testWidgets('沒有預選特務時按鈕停用並提示設定方式', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, consent: true, pregameStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.textContaining('尚未預選特務'), findsOneWidget);
      final lock = tester.widget<ButtonStyleButton>(
          find.byKey(const ValueKey('remote-lock-agent')));
      expect(lock.onPressed, isNull);
      await leave(tester, h);
    });

    testWidgets('未同意時選角畫面沒有遠端選角', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, pregameStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.byKey(const ValueKey('pregame-remaining')), findsOneWidget);
      expect(find.byKey(const ValueKey('remote-pregame')), findsNothing);
      await leave(tester, h);
    });
  });

  group('收藏', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    Future<void> openVandal(WidgetTester tester, Harness h) async {
      await tester.pumpWidget(h.wrap(home: const CollectionPage()));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('weapon-w-vandal')));
      await settle(tester);
    }

    testWidgets('未同意時造型卡沒有裝備按鈕，也不讀取裝備', (tester) async {
      setWidth(tester, 1440);
      final h = await harness(tester);
      await openVandal(tester, h);
      expect(find.text('光幻 暴徒'), findsOneWidget);
      expect(find.byKey(const ValueKey('equip-skin-v')), findsNothing);
      expect(writes, isEmpty);
    });

    testWidgets('同意後選炫彩並裝備（用最高等級）', (tester) async {
      setWidth(tester, 1440);
      final h = await harness(tester, consent: true);
      await openVandal(tester, h);
      // 進入頁面只讀取目前的裝備。
      expect([for (final r in writes) r.method], ['GET']);
      await tester.tap(find.byKey(const ValueKey('equip-skin-v')));
      await tester.pumpAndSettle();
      expect(find.text('選擇炫彩'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chroma-ch-v-red')));
      await settle(tester);
      expect([for (final r in writes) r.method], ['GET', 'GET', 'PUT']);
      expect(writes.last.body, contains('"SkinLevelID":"lv-vandal-2"'));
      expect(writes.last.body, contains('"ChromaID":"ch-v-red"'));
      expect(find.byKey(const ValueKey('equipped-skin-v')), findsOneWidget);
    });

    testWidgets('特務分頁：同意後可以預選與取消', (tester) async {
      setWidth(tester, 1440);
      final h = await harness(tester);
      await tester.pumpWidget(h.wrap(home: const CollectionPage()));
      await settle(tester);
      await tester.tap(find.byWidgetPredicate(
          (w) => w is Tab && (w.text ?? '').startsWith('特務')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preselect-a-base1')), findsNothing);

      await tester.runAsync(() => h.settings.setRemoteControl(true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preselect-a-base1')));
      await tester.pumpAndSettle();
      expect(h.settings.settings.preferredAgent, 'a-base1');
      await tester.tap(find.byKey(const ValueKey('preselect-a-base1')));
      await tester.pumpAndSettle();
      expect(h.settings.settings.preferredAgent, isNull);
    });
  });

  group('第二批', () {
    Future<void> confirm(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('remote-confirm')));
      await drain(tester);
    }

    testWidgets('選角：逃跑要確認，取消時不送出', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, consent: true, pregameStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      await tapKey(tester, 'remote-quit-pregame');
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await drain(tester);
      expect(writes, isEmpty);
      await tapKey(tester, 'remote-quit-pregame');
      await confirm(tester);
      expect(writes.single.url.path,
          '/pregame/v1/matches/$testPregameMatchId/quit');
      await leave(tester, h);
    });

    testWidgets('對局：同意後才有離開對局，確認後送出', (tester) async {
      setWidth(tester, 1400);
      var h = await harness(tester, coreStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.byKey(const ValueKey('remote-match')), findsNothing);
      await leave(tester, h);

      h = await harness(tester, consent: true, coreStatus: 200);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      await tapKey(tester, 'remote-leave-match');
      await confirm(tester);
      expect(writes.single.url.path,
          '/core-game/v1/players/$myPuuid/disassociate/$testCoreMatchId');
      await leave(tester, h);
    });

    testWidgets('隊伍：邀請、踢人（確認）、建立自訂對戰', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester, consent: true);
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      await tester.enterText(
          find.byKey(const ValueKey('remote-invite-field')), 'Friend#TW1');
      await tapKey(tester, 'remote-invite');
      await tapKey(tester, 'remote-kick-mate');
      await confirm(tester);
      await tapKey(tester, 'remote-make-custom');
      expect([
        for (final r in writes) '${r.method} ${r.url.path}'
      ], [
        'POST /parties/v1/parties/$testPartyId/invites/name/Friend/tag/TW1',
        'DELETE /parties/v1/players/mate',
        'POST /parties/v1/parties/$testPartyId/makecustomgame',
      ]);
      await leave(tester, h);
    });

    testWidgets('自訂對戰：開始與回到一般模式；不顯示排隊', (tester) async {
      setWidth(tester, 1400);
      final h = await harness(tester,
          consent: true,
          party: partyJson(state: 'CUSTOM_GAME_SETUP')
            ..['CustomGameData'] = {
              'Settings': {'Map': '/Game/Maps/Ascent/Ascent', 'Mode': 'bomb'},
              'Membership': {
                'teamOne': [
                  {'Subject': myPuuid}
                ],
              },
            });
      await tester.pumpWidget(h.wrap(home: const LivePage()));
      await drain(tester);
      expect(find.byKey(const ValueKey('remote-queue')), findsNothing);
      expect(find.byKey(const ValueKey('remote-custom-map')), findsOneWidget);
      await tapKey(tester, 'remote-start-custom');
      await tapKey(tester, 'remote-make-default');
      expect([
        for (final r in writes) r.url.path
      ], [
        '/parties/v1/parties/$testPartyId/startcustomgame',
        '/parties/v1/parties/$testPartyId/makedefault',
      ]);
      expect(writes.last.url.queryParameters['queueID'], 'unrated');
      await leave(tester, h);
    });

    // 使用者決定 2026-10-22：我的收藏的特務分頁移除合約按鈕。
    testWidgets('收藏特務：同意遠端操作後也沒有啟用合約按鈕', (tester) async {
      setWidth(tester, 1440);
      final h = await harness(tester, consent: true);
      await tester.pumpWidget(h.wrap(home: const CollectionPage()));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate(
          (w) => w is Tab && (w.text ?? '').startsWith('特務')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('activate-a-paid')), findsNothing);
      expect(
          find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('activate-')),
          findsNothing);
      expect(writes, isEmpty);
    });
  });
}
