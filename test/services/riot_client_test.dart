import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:agent_t/services/riot_auth.dart';
import 'package:agent_t/services/riot_client.dart';

import '../riot_fixtures.dart';

void main() {
  group('CORS 限制', corsTests);
  final now = DateTime(2026, 10, 20, 10);
  final tokens = parseRiotRedirect(fakeRedirect)!;

  test('createSession 組出 puuid、名稱、區域與版本', () async {
    final s = await RiotClient(client: riotClient()).createSession(tokens, now);
    expect(s.puuid, 'puuid-1');
    expect(s.displayName, 'Tester#TW1');
    expect(s.shard, 'ap');
    expect(s.clientVersion, 'release-13.08-shipping-19-5698904');
    expect(s.entitlementsToken, 'fake-ent');
    expect(s.expiresAt, now.add(const Duration(hours: 1)));
  });

  test('pd 請求帶齊 4 個標頭並使用 v3 POST', () async {
    final requests = <http.Request>[];
    final c = RiotClient(client: riotClient(requests: requests));
    final s = await c.createSession(tokens, now);
    await c.fetchStorefront(s);
    final store = requests.firstWhere((r) => r.url.path.contains('storefront'));
    expect(store.method, 'POST');
    expect(store.url.toString(),
        'https://pd.ap.a.pvp.net/store/v3/storefront/puuid-1');
    expect(store.headers['Authorization'], 'Bearer $fakeAccessToken');
    expect(store.headers['X-Riot-Entitlements-JWT'], 'fake-ent');
    expect(store.headers['X-Riot-ClientVersion'],
        'release-13.08-shipping-19-5698904');
    expect(store.headers['X-Riot-ClientPlatform'], isNotEmpty);
  });

  test('storefront v3 回應 404 時改用 v2 GET', () async {
    final requests = <http.Request>[];
    final c = RiotClient(
        client: riotClient(requests: requests, storefrontV3Status: 404));
    final s = await c.createSession(tokens, now);
    final json = await c.fetchStorefront(s);
    expect(json.containsKey('SkinsPanelLayout'), isTrue);
    expect(
        requests.any((r) =>
            r.method == 'GET' && r.url.path == '/store/v2/storefront/puuid-1'),
        isTrue);
  });

  test('錢包解析三種貨幣', () async {
    final c = RiotClient(client: riotClient());
    final w = await c.fetchWallet(await c.createSession(tokens, now));
    expect(w.vp, 1500);
    expect(w.radianite, 120);
    expect(w.kingdom, 3000);
  });

  test('擁有的造型等級', () async {
    final c = RiotClient(client: riotClient());
    final owned =
        await c.fetchOwnedSkinLevels(await c.createSession(tokens, now));
    expect(owned, {'lvl-odin', 'lvl-not-in-catalog'});
  });

  test('401 丟出 isAuthError 的例外且訊息不含 token', () async {
    final c = RiotClient(client: riotClient(walletStatus: 401));
    final s = await c.createSession(tokens, now);
    try {
      await c.fetchWallet(s);
      fail('應丟出例外');
    } on RiotApiException catch (e) {
      expect(e.statusCode, 401);
      expect(e.isAuthError, isTrue);
      expect(e.message.contains(fakeAccessToken), isFalse);
      expect(e.toString().contains(fakeAccessToken), isFalse);
    }
  });
}

void corsTests() {
  final now = DateTime(2026, 10, 20, 10);

  test('userinfo 與 riot-geo 被 CORS 擋下時：puuid 取自 JWT、名稱取自 id_token、區域用預設 ap',
      () async {
    final tokens = parseRiotRedirect(fakeRedirect)!;
    final s = await RiotClient(client: riotClient(corsBlocked: true))
        .createSession(tokens, now);
    expect(s.puuid, 'puuid-1');
    expect(s.displayName, 'Tester#TW1');
    expect(s.shard, 'ap');
  });

  test('區域偵測失敗時使用指定的備用區域', () async {
    final requests = <http.Request>[];
    final c =
        RiotClient(client: riotClient(corsBlocked: true, requests: requests));
    final s = await c.createSession(parseRiotRedirect(fakeRedirect)!, now,
        fallbackShard: 'kr');
    expect(s.shard, 'kr');
  });

  test('id_token 沒有名稱且 userinfo 被擋時仍可登入', () async {
    final url = 'https://playvalorant.com/opt_in#access_token=$fakeAccessToken'
        '&id_token=${fakeJwt({'sub': 'puuid-1'})}&expires_in=3600';
    final s = await RiotClient(client: riotClient(corsBlocked: true))
        .createSession(parseRiotRedirect(url)!, now);
    expect(s.puuid, 'puuid-1');
    expect(s.displayName, '已登入玩家');
  });

  test('access_token 不是 JWT 時丟出格式錯誤', () async {
    final tokens = parseRiotRedirect(
        'https://x/#access_token=not-a-jwt&id_token=$fakeIdToken')!;
    expect(
        RiotClient(client: riotClient(corsBlocked: true))
            .createSession(tokens, now),
        throwsA(isA<RiotApiException>()
            .having((e) => e.message, 'message', '登入資訊格式不符')));
  });

  test('pd 請求逾時：當成連線失敗並釋放名額，後面的請求照常完成', () async {
    final inner = riotClient();
    var held = 0;
    final c = RiotClient(
        maxPvpConcurrent: 1,
        pvpTimeout: const Duration(milliseconds: 50),
        client: MockClient((req) async {
          if (req.url.path.startsWith('/mmr/v1/players/hang')) {
            held++;
            await Future<void>.delayed(const Duration(seconds: 5));
          }
          final copy = http.Request(req.method, req.url)
            ..headers.addAll(req.headers)
            ..bodyBytes = req.bodyBytes;
          return http.Response.fromStream(await inner.send(copy));
        }));
    final s = await c.createSession(
        parseRiotRedirect(fakeRedirect)!, DateTime(2026, 10, 20, 10));
    await expectLater(
        c.getPd(s, '/mmr/v1/players/hang', label: '取得玩家牌位'),
        throwsA(isA<RiotApiException>()
            .having((e) => e.statusCode, 'statusCode', isNull)));
    expect(held, 1);
    final ok = await c.getPd(s, '/mmr/v1/players/puuid-1', label: '取得牌位');
    expect(ok['Subject'], isNotNull);
  });

  test('被限流（429）後所有 pd 請求暫停到 Retry-After 結束才送', () async {
    final inner = riotClient();
    final sentAt = <String, DateTime>{};
    var limited = true;
    final c = RiotClient(client: MockClient((req) async {
      if (req.url.path == '/mmr/v1/players/limited' && limited) {
        limited = false;
        return http.Response('{}', 429, headers: {'retry-after': '1'});
      }
      sentAt[req.url.path] = DateTime.now();
      final copy = http.Request(req.method, req.url)
        ..headers.addAll(req.headers)
        ..bodyBytes = req.bodyBytes;
      return http.Response.fromStream(await inner.send(copy));
    }));
    final s = await c.createSession(
        parseRiotRedirect(fakeRedirect)!, DateTime(2026, 10, 20, 10));
    final start = DateTime.now();
    await expectLater(c.getPd(s, '/mmr/v1/players/limited', label: 'x'),
        throwsA(isA<RiotApiException>()));
    await c.getPd(s, '/mmr/v1/players/puuid-1', label: 'x');
    expect(sentAt['/mmr/v1/players/puuid-1']!.difference(start),
        greaterThanOrEqualTo(const Duration(milliseconds: 900)));
  });
}
