import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:agent_t/providers/live_party_provider.dart';
import 'package:agent_t/providers/riot_provider.dart';
import 'package:agent_t/services/live_client.dart';
import 'package:agent_t/services/match_client.dart';
import 'package:agent_t/services/riot_client.dart';

import '../live_fixtures.dart';
import '../match_fixtures.dart';
import '../riot_fixtures.dart';

/// 測試用的計時器：記錄間隔，手動觸發，可以檢查是否已取消。
class _FakeTimer implements Timer {
  final Duration interval;
  final void Function(Timer) callback;
  bool cancelled = false;

  _FakeTimer(this.interval, this.callback);

  void fire() => callback(this);

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

void main() {
  late List<http.Request> requests;
  _FakeTimer? timer;

  Future<(LivePartyProvider, RiotProvider)> setup({
    int partyStatus = 200,
    int coreStatus = 404,
    int pregameStatus = 404,
    int sessionStatus = 200,
    String? loopState,
    Set<String> otherMmrHidden = const {},
    Map<String, int> otherMmrStatus = const {},
  }) async {
    requests = [];
    timer = null;
    final inner = riotClient(
        partyStatus: partyStatus,
        coreStatus: coreStatus,
        pregameStatus: pregameStatus,
        sessionStatus: sessionStatus,
        loopState: loopState,
        otherMmrHidden: otherMmrHidden,
        otherMmrStatus: otherMmrStatus);
    final client = MockClient((req) async {
      requests.add(req);
      final copy = http.Request(req.method, req.url)
        ..headers.addAll(req.headers)
        ..bodyBytes = req.bodyBytes;
      return inner.send(copy).then(http.Response.fromStream);
    });
    final rc = RiotClient(client: client);
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    requests.clear();
    final p = LivePartyProvider(LiveClient(rc), MatchClient(rc), riot,
        periodic: (d, cb) => timer = _FakeTimer(d, cb));
    return (p, riot);
  }

  Iterable<http.Request> where(String fragment) =>
      requests.where((r) => r.url.path.contains(fragment));

  test('讀取隊伍：成員、自己的名稱、隊友名稱', () async {
    final (p, _) = await setup();
    await p.refresh();
    expect(p.status, LiveStatus.ready);
    expect(p.party!.members.length, 4);
    expect(p.name(myPuuid), 'Tester#TW1');
    expect(p.name('mate'), 'N-mate#TW1');
  });

  test('使用者決定（2026-10-21）：隱藏名稱的成員也查名稱並顯示', () async {
    final (p, _) = await setup();
    await p.refresh();
    expect(p.name('ghost'), 'N-ghost#TW1');
    final asked = [
      for (final r in where('/name-service/'))
        ...(jsonDecode(r.body) as List).cast<String>(),
    ];
    expect(asked, containsAll(['mate', 'ghost', 'shy']));
    expect(asked, isNot(contains(myPuuid)));
  });

  test('牌位直接用隊伍資料，不查任何人的 MMR', () async {
    final (p, _) = await setup(otherMmrHidden: {'shy'});
    await p.refresh();
    expect(where('/mmr/v1/players/'), isEmpty);
  });

  test('名稱只查一次', () async {
    final (p, _) = await setup();
    await p.refresh();
    await p.refresh();
    expect(where('/name-service/').length, 1);
  });

  test('不在隊伍（404）顯示沒有隊伍', () async {
    final (p, _) = await setup(partyStatus: 404);
    await p.refresh();
    expect(p.status, LiveStatus.noParty);
    expect(p.party, isNull);
  });

  group('遊戲狀態（使用者決定 2026-10-23）', () {
    test('遊戲沒開（404）：只送這一個請求，顯示遊戲沒有開啟', () async {
      final (p, _) = await setup(sessionStatus: 404);
      await p.refresh();
      expect(p.status, LiveStatus.offline);
      expect(p.party, isNull);
      expect(requests.map((r) => r.url.path),
          ['/session/v1/sessions/puuid-1']);
    });

    test('在大廳（MENUS）：不試對局與選角，直接讀隊伍與延遲', () async {
      final (p, _) = await setup();
      await p.refresh();
      expect(p.status, LiveStatus.ready);
      expect(where('/core-game/'), isEmpty);
      expect(where('/pregame/'), isEmpty);
      expect(p.party!.pings.single.podId, 'pod-a');
      expect(p.party!.pings.single.ping, 40);
    });

    test('選角中（PREGAME）：不試對局', () async {
      final (p, _) = await setup(pregameStatus: 200);
      await p.refresh();
      expect(p.phase, LivePhase.pregame);
      expect(where('/core-game/'), isEmpty);
    });

    test('遊戲狀態讀不到（非 404）：改回逐一試，之後不再問', () async {
      final (p, _) = await setup(sessionStatus: 500);
      await p.refresh();
      expect(p.status, LiveStatus.ready);
      expect(where('/core-game/v1/players/'), hasLength(1));
      await p.refresh();
      expect(where('/session/'), hasLength(1));
    });
  });

  test('401 登出並停止更新', () async {
    final (p, riot) = await setup(partyStatus: 401);
    p.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(riot.isLoggedIn, isFalse);
    expect(p.status, LiveStatus.loggedOut);
    expect(timer!.cancelled, isTrue);
  });

  test('start 立即更新一次，之後每 10 秒；stop 取消計時器', () async {
    final (p, _) = await setup();
    p.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(timer!.interval, const Duration(seconds: 10));
    expect(where('/parties/v1/players/').length, 1);
    timer!.fire();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(where('/parties/v1/players/').length, 2);
    p.stop();
    expect(timer!.cancelled, isTrue);
  });

  test('上一輪還沒結束時跳過這一輪', () async {
    final (p, _) = await setup();
    final a = p.refresh();
    final b = p.refresh();
    await Future.wait([a, b]);
    expect(where('/parties/v1/players/').length, 1);
  });

  test('stop 或 dispose 之後，進行中的更新完成也不通知、不丟例外', () async {
    final (p, _) = await setup();
    var notified = 0;
    p.addListener(() => notified++);
    final f = p.refresh();
    // 開始時同步通知一次「載入中」是正常的；dispose 之後不可以再通知。
    notified = 0;
    p.dispose();
    await f;
    expect(notified, 0);
  });

  group('階段判斷', () {
    test('對局中：切到 inGame，讀取對局並查所有人的名稱，不讀隊伍', () async {
      final (p, _) = await setup(coreStatus: 200);
      await p.refresh();
      expect(p.phase, LivePhase.inGame);
      expect(p.match!.players.length, 11);
      expect(p.name('r1'), 'N-r1#TW1');
      expect(p.name('r2'), 'N-r2#TW1');
      expect(p.name(myPuuid), 'Tester#TW1');
      expect(where('/parties/'), isEmpty);
      expect(where('/pregame/'), isEmpty);
    });

    test('對局中：造型每場只讀一次', () async {
      final (p, _) = await setup(coreStatus: 200);
      await p.refresh();
      await p.refresh();
      expect(p.skins('mate')![vandalId], 'p');
      expect(p.skins('nobody'), isNull);
      expect(where('/loadouts').length, 1);
    });

    test('選角中：切到 pregame，讀取我方並查名稱，不讀隊伍', () async {
      final (p, _) = await setup(pregameStatus: 200);
      await p.refresh();
      expect(p.phase, LivePhase.pregame);
      expect(p.match, isNull);
      expect(p.pregame!.allies.length, 5);
      expect(p.name('mate'), 'N-mate#TW1');
      expect(p.pregameFetchedAt, isNotNull);
      expect(where('/parties/'), isEmpty);
    });

    test('不在選角也不在對局（讀不到遊戲狀態時逐一試）：隊伍階段', () async {
      final (p, _) = await setup(sessionStatus: 500);
      await p.refresh();
      expect(p.phase, LivePhase.party);
      expect(p.party, isNotNull);
      expect(where('/core-game/v1/players/'), hasLength(1));
      expect(where('/pregame/v1/players/'), hasLength(1));
    });
  });
}
