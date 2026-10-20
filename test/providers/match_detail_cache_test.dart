import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valorant_shop_tracker/providers/match_detail_cache.dart';
import 'package:valorant_shop_tracker/providers/match_history_provider.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/services/match_client.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';

import '../riot_fixtures.dart';

void main() {
  late int matchRequests;
  late Set<String> failing;

  Future<(MatchDetailCache, MatchClient, RiotProvider)> setup() async {
    matchRequests = 0;
    failing = {};
    final inner = riotClient(matchDelay: const Duration(milliseconds: 10));
    final client = MockClient((req) async {
      final isMatch = req.url.path.contains('match-details');
      if (isMatch) {
        matchRequests++;
        if (failing.contains(req.url.pathSegments.last)) {
          return http.Response('{}', 500);
        }
      }
      final copy = http.Request(req.method, req.url)
        ..headers.addAll(req.headers)
        ..bodyBytes = req.bodyBytes;
      return inner.send(copy).then(http.Response.fromStream);
    });
    final rc = RiotClient(client: client);
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    return (MatchDetailCache(), MatchClient(rc), riot);
  }

  test('同一場同時要求兩次只請求一次', () async {
    final (cache, c, riot) = await setup();
    final s = riot.session!;
    final results =
        await Future.wait([cache.json(s, 'm1', c), cache.json(s, 'm1', c)]);
    expect(matchRequests, 1);
    expect(identical(results[0], results[1]), isTrue);
    await cache.json(s, 'm1', c);
    expect(matchRequests, 1);
  });

  test('失敗不快取，下次重新請求', () async {
    final (cache, c, riot) = await setup();
    final s = riot.session!;
    failing.add('m1');
    await expectLater(cache.json(s, 'm1', c), throwsA(isA<RiotApiException>()));
    failing.clear();
    final json = await cache.json(s, 'm1', c);
    expect(json['matchInfo'], isNotNull);
    expect(matchRequests, 2);
  });

  test('clear 之後重新請求', () async {
    final (cache, c, riot) = await setup();
    final s = riot.session!;
    await cache.json(s, 'm1', c);
    cache.clear();
    await cache.json(s, 'm1', c);
    expect(matchRequests, 2);
  });

  test('MatchHistoryProvider 共用快取，已快取的場次不再請求', () async {
    final (cache, c, riot) = await setup();
    await cache.json(riot.session!, 'm1', c);
    final p = MatchHistoryProvider(c, riot, cache: cache, pageSize: 3);
    await p.loadFirstPage();
    expect(p.entries.length, 3);
    expect(p.detail('m1'), isNotNull);
    expect(matchRequests, 3);
  });
}
