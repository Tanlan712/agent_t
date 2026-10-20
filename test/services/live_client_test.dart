import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/services/live_client.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';

import '../live_fixtures.dart';
import '../riot_fixtures.dart';

void main() {
  Future<(LiveClient, RiotProvider, List<http.Request>)> setup(
      {int partyStatus = 200, int partyDetailStatus = 200}) async {
    final requests = <http.Request>[];
    final rc = RiotClient(
        client: riotClient(
            requests: requests,
            partyStatus: partyStatus,
            partyDetailStatus: partyDetailStatus));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    requests.clear();
    return (LiveClient(rc), riot, requests);
  }

  test('用 GET 連到 glz 主機，帶齊 pd 標頭', () async {
    final (c, riot, requests) = await setup();
    final id = await c.fetchPartyId(riot.session!);
    expect(id, testPartyId);
    final r = requests.single;
    expect(r.method, 'GET');
    expect(r.url.host, 'glz-ap-1.ap.a.pvp.net');
    expect(r.url.path, '/parties/v1/players/puuid-1');
    for (final h in [
      'Authorization',
      'X-Riot-Entitlements-JWT',
      'X-Riot-ClientVersion',
      'X-Riot-ClientPlatform'
    ]) {
      expect(r.headers.containsKey(h), isTrue, reason: h);
    }
  });

  test('隊伍詳情', () async {
    final (c, riot, _) = await setup();
    final json = await c.fetchParty(riot.session!, testPartyId);
    expect(json['ID'], testPartyId);
  });

  test('不在隊伍（404）時回傳 null', () async {
    final (c, riot, _) = await setup(partyStatus: 404);
    expect(await c.fetchPartyId(riot.session!), isNull);
  });

  test('401 丟出 RiotApiException', () async {
    final (c, riot, _) = await setup(partyStatus: 401);
    await expectLater(
        c.fetchPartyId(riot.session!),
        throwsA(isA<RiotApiException>()
            .having((e) => e.statusCode, 'status', 401)));
  });

  test('對局：不在對局（404）時回傳 null，對局中回傳場次', () async {
    final (c, riot, _) = await setup();
    expect(await c.fetchCoreMatchId(riot.session!), isNull);
    final rc = RiotClient(client: riotClient(coreStatus: 200));
    final r2 = RiotProvider(rc);
    await r2.login(fakeRedirect);
    final c2 = LiveClient(rc);
    final id = await c2.fetchCoreMatchId(r2.session!);
    expect(id, testCoreMatchId);
    final json = await c2.fetchCoreMatch(r2.session!, id!);
    expect(json['MatchID'], testCoreMatchId);
  });

  test('選角：不在選角（404）時回傳 null', () async {
    final (c, riot, _) = await setup();
    expect(await c.fetchPregameMatchId(riot.session!), isNull);
    final rc = RiotClient(client: riotClient(pregameStatus: 200));
    final r2 = RiotProvider(rc);
    await r2.login(fakeRedirect);
    expect(await LiveClient(rc).fetchPregameMatchId(r2.session!), 'pre-1');
  });

  test('選角場次詳情', () async {
    final rc = RiotClient(client: riotClient(pregameStatus: 200));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    final json = await LiveClient(rc)
        .fetchPregameMatch(riot.session!, testPregameMatchId);
    expect(json['ID'], testPregameMatchId);
  });

  test('對局造型', () async {
    final rc = RiotClient(client: riotClient(coreStatus: 200));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    final json =
        await LiveClient(rc).fetchCoreLoadouts(riot.session!, testCoreMatchId);
    expect((json['Loadouts'] as List).length, 2);
  });
}
