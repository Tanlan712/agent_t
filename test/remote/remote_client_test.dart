import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:agent_t/providers/riot_provider.dart';
import 'package:agent_t/services/remote_client.dart';
import 'package:agent_t/services/riot_client.dart';

import '../remote_fixtures.dart';
import '../riot_fixtures.dart';

void main() {
  late List<http.Request> requests;
  late bool allowed;

  Future<(RemoteClient, RiotProvider)> setup(
      {Map<String, int> status = const {},
      String? inviteCode = 'ABC123'}) async {
    requests = [];
    allowed = true;
    final rc = RiotClient(
        client: remoteHttp(requests, status: status, inviteCode: inviteCode));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    return (RemoteClient(rc, allowed: () => allowed), riot);
  }

  const glz = 'glz-ap-1.ap.a.pvp.net';

  void expectHeaders(http.Request r) {
    for (final h in [
      'Authorization',
      'X-Riot-Entitlements-JWT',
      'X-Riot-ClientVersion',
      'X-Riot-ClientPlatform'
    ]) {
      expect(r.headers.containsKey(h), isTrue, reason: h);
    }
  }

  test('選擇與鎖定特務：POST 到 pregame 的 select／lock', () async {
    final (c, riot) = await setup();
    await c.selectAgent(riot.session!, 'pre-1', 'agent-a');
    await c.lockAgent(riot.session!, 'pre-1', 'agent-a');
    expect([
      for (final r in requests) '${r.method} ${r.url.host}${r.url.path}'
    ], [
      'POST $glz/pregame/v1/matches/pre-1/select/agent-a',
      'POST $glz/pregame/v1/matches/pre-1/lock/agent-a',
    ]);
    requests.forEach(expectHeaders);
  });

  test('隊伍：準備、排隊、取消、模式、開放與鎖定', () async {
    final (c, riot) = await setup();
    final s = riot.session!;
    await c.setReady(s, 'party-1', false);
    await c.joinQueue(s, 'party-1');
    await c.leaveQueue(s, 'party-1');
    await c.changeQueue(s, 'party-1', 'competitive');
    await c.setAccessibility(s, 'party-1', true);
    await c.setAccessibility(s, 'party-1', false);
    expect([
      for (final r in requests) r.url.path
    ], [
      '/parties/v1/parties/party-1/members/puuid-1/setReady',
      '/parties/v1/parties/party-1/matchmaking/join',
      '/parties/v1/parties/party-1/matchmaking/leave',
      '/parties/v1/parties/party-1/queue',
      '/parties/v1/parties/party-1/accessibility',
      '/parties/v1/parties/party-1/accessibility',
    ]);
    expect(
        requests.every((r) => r.method == 'POST' && r.url.host == glz), isTrue);
    expect(jsonDecode(requests[0].body), {'ready': false});
    expect(jsonDecode(requests[3].body), {'queueId': 'competitive'});
    expect(jsonDecode(requests[4].body), {'accessibility': 'OPEN'});
    expect(jsonDecode(requests[5].body), {'accessibility': 'CLOSED'});
  });

  test('隊伍代碼：從回應讀取 InviteCode', () async {
    final (c, riot) = await setup();
    expect(await c.generateInviteCode(riot.session!, 'party-1'), 'ABC123');
    expect(requests.single.url.path, '/parties/v1/parties/party-1/invitecode');
  });

  test('隊伍代碼：回應沒有代碼時回傳 null', () async {
    final (c, riot) = await setup(inviteCode: null);
    expect(await c.generateInviteCode(riot.session!, 'party-1'), isNull);
  });

  test('裝備：GET 與 PUT 到 pd 的 playerloadout', () async {
    final (c, riot) = await setup();
    final loadout = await c.fetchLoadout(riot.session!);
    expect(loadout['Version'], 7);
    final res =
        await c.putLoadout(riot.session!, {...loadout, 'Incognito': true});
    expect(res?['Incognito'], isTrue);
    expect([
      for (final r in requests) '${r.method} ${r.url.host}${r.url.path}'
    ], [
      'GET pd.ap.a.pvp.net/personalization/v3/players/puuid-1/playerloadout',
      'PUT pd.ap.a.pvp.net/personalization/v3/players/puuid-1/playerloadout',
    ]);
    requests.forEach(expectHeaders);
  });

  test('非 2xx 丟出 RiotApiException', () async {
    final (c, riot) = await setup(status: {'/lock/': 409});
    await expectLater(
        c.lockAgent(riot.session!, 'pre-1', 'agent-a'),
        throwsA(isA<RiotApiException>()
            .having((e) => e.statusCode, 'status', 409)));
  });

  test('未同意時丟出 RemoteDisabledException，不送出任何請求', () async {
    final (c, riot) = await setup();
    allowed = false;
    final s = riot.session!;
    for (final call in <Future<Object?> Function()>[
      () => c.fetchLoadout(s),
      () => c.putLoadout(s, const {}),
      () => c.selectAgent(s, 'm', 'a'),
      () => c.lockAgent(s, 'm', 'a'),
      () => c.setReady(s, 'p', true),
      () => c.generateInviteCode(s, 'p'),
      () => c.joinQueue(s, 'p'),
      () => c.leaveQueue(s, 'p'),
      () => c.changeQueue(s, 'p', 'q'),
      () => c.setAccessibility(s, 'p', true),
    ]) {
      await expectLater(call(), throwsA(isA<RemoteDisabledException>()));
    }
    expect(requests, isEmpty);
  });
}
