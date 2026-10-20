import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:valorant_shop_tracker/models/riot_session.dart';
import 'package:valorant_shop_tracker/services/match_client.dart';
import 'package:valorant_shop_tracker/services/riot_auth.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';

import '../riot_fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 20, 10);

  Future<(MatchClient, RiotSession)> setup(http.Client client) async {
    final riot = RiotClient(client: client);
    final s = await riot.createSession(parseRiotRedirect(fakeRedirect)!, now);
    return (MatchClient(riot), s);
  }

  test('fetchHistory 分頁參數、總數與標頭', () async {
    final requests = <http.Request>[];
    final (c, s) = await setup(riotClient(requests: requests));
    final (refs, total) = await c.fetchHistory(s, 10, 10);
    expect(total, 25);
    expect(refs.length, 10);
    expect(refs.first.matchId, 'm11');
    final req = requests.lastWhere((r) => r.url.path.contains('match-history'));
    expect(req.url.queryParameters['startIndex'], '10');
    expect(req.url.queryParameters['endIndex'], '20');
    expect(req.headers['Authorization'], 'Bearer $fakeAccessToken');
    expect(req.headers['X-Riot-Entitlements-JWT'], 'fake-ent');
    expect(req.headers['X-Riot-ClientVersion'], isNotEmpty);
    expect(req.headers['X-Riot-ClientPlatform'], isNotEmpty);
  });

  test('fetchMatchJson 回傳詳情', () async {
    final (c, s) = await setup(riotClient());
    final json = await c.fetchMatchJson(s, 'm7');
    expect(json['players'], isList);
    expect((json['matchInfo'] as Map)['matchId'], 'm7');
  });

  test('fetchRrChanges 與 fetchRank', () async {
    final requests = <http.Request>[];
    final (c, s) = await setup(riotClient(requests: requests));
    expect(await c.fetchRrChanges(s, 5), {'m1': 18, 'm2': -15});
    final req =
        requests.lastWhere((r) => r.url.path.contains('competitiveupdates'));
    expect(req.url.queryParameters['startIndex'], '0');
    expect(req.url.queryParameters['endIndex'], '5');
    final rank = await c.fetchRank(s);
    expect(rank!.tier, 18);
    expect(rank.rr, 45);
  });

  test('401 丟出 isAuthError 且訊息不含 token', () async {
    final (c, s) = await setup(riotClient(historyStatus: 401));
    try {
      await c.fetchHistory(s, 0, 10);
      fail('應丟出例外');
    } on RiotApiException catch (e) {
      expect(e.isAuthError, isTrue);
      expect(e.toString().contains(fakeAccessToken), isFalse);
    }
  });
}
