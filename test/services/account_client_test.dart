import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:valorant_shop_tracker/services/riot_auth.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';

import '../riot_fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 21, 10);
  final tokens = parseRiotRedirect(fakeRedirect)!;

  test('ItemTypes 與 AGENTS.md 核准的 ID 一致', () {
    expect(ItemTypes.skinLevel, 'e7c63390-eda7-46e0-bb7a-a6abdacd2433');
    expect(ItemTypes.skinChroma, '3ad1b2b2-acdb-4524-852f-954a76ddae0a');
    expect(ItemTypes.agent, '01bb38e1-da47-4e6a-9b3d-945fe4655707');
    expect(ItemTypes.buddyLevel, 'dd3bf334-87f3-40bd-b043-682a57a8dc3a');
    expect(ItemTypes.spray, 'd5f120f8-ff8c-4aac-92ea-f2b5acbe9475');
    expect(ItemTypes.playerCard, '3f296c07-64c3-494c-923b-fe692a4fa1bd');
    expect(ItemTypes.title, 'de7caa6b-adf7-4588-bbd1-143831e786c6');
  });

  test('fetchEntitlements：GET 自己的 puuid、帶 pd 標頭、ID 轉小寫', () async {
    final requests = <http.Request>[];
    final c = RiotClient(
        client: riotClient(requests: requests, entitlements: {
      ItemTypes.spray: ['SPRAY-A', 'spray-b'],
    }));
    final s = await c.createSession(tokens, now);
    final ids = await c.fetchEntitlements(s, ItemTypes.spray);
    expect(ids, {'spray-a', 'spray-b'});
    final r = requests.last;
    expect(r.method, 'GET');
    expect(r.url.toString(),
        'https://pd.ap.a.pvp.net/store/v1/entitlements/puuid-1/${ItemTypes.spray}');
    expect(r.headers['X-Riot-Entitlements-JWT'], 'fake-ent');
  });

  test('fetchAccountXp 與 fetchContracts 只用 GET', () async {
    final requests = <http.Request>[];
    final c = RiotClient(client: riotClient(requests: requests));
    final s = await c.createSession(tokens, now);
    final xp = await c.fetchAccountXp(s);
    final contracts = await c.fetchContracts(s);
    expect(xp.level, 4);
    expect(contracts.missions, isNotEmpty);
    final paths = {
      for (final r in requests.where((r) => r.url.host == 'pd.ap.a.pvp.net'))
        '${r.method} ${r.url.path}',
    };
    expect(paths, contains('GET /account-xp/v1/players/puuid-1'));
    expect(paths, contains('GET /contracts/v1/contracts/puuid-1'));
    expect(paths.where((p) => !p.startsWith('GET')), isEmpty);
  });

  test('失敗時丟 RiotApiException，訊息不含 token', () async {
    final c = RiotClient(client: riotClient(contractsStatus: 500));
    final s = await c.createSession(tokens, now);
    await expectLater(
        c.fetchContracts(s),
        throwsA(isA<RiotApiException>()
            .having((e) => e.statusCode, 'status', 500)
            .having((e) => e.message, 'message',
                isNot(contains(fakeAccessToken)))));
  });
}
