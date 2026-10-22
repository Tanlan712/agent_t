import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'account_fixtures.dart';
import 'live_fixtures.dart';
import 'match_fixtures.dart';

/// 依社群文件（valapidocs）格式精簡的 storefront 測試資料。
const vp = '85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741';

Map<String, dynamic> offer(String itemId, int cost) => {
      'OfferID': itemId,
      'IsDirectPurchase': true,
      'Cost': {vp: cost},
      'Rewards': [
        {
          'ItemTypeID': 'e7c63390-eda7-46e0-bb7a-a6abdacd2433',
          'ItemID': itemId,
          'Quantity': 1
        },
      ],
    };

Map<String, dynamic> storefrontJson(
        {bool withNightMarket = true, int dailyRemaining = 3600}) =>
    {
      'FeaturedBundle': {
        'Bundle': {
          'ID': 'b-offer',
          'DataAssetID': 'bundle-rgx',
          'CurrencyID': vp,
          'TotalBaseCost': {vp: 8700},
          'TotalDiscountedCost': {vp: 7100},
          'DurationRemainingInSeconds': 500000,
        },
        'BundleRemainingDurationInSeconds': 500000,
      },
      'SkinsPanelLayout': {
        'SingleItemOffers': ['lvl-odin', 'lvl-noicon', 'lvl-a', 'lvl-unknown'],
        'SingleItemStoreOffers': [
          offer('lvl-odin', 1275),
          offer('lvl-noicon', 2475),
          offer('lvl-a', 875),
          offer('lvl-unknown', 1775),
        ],
        'SingleItemOffersRemainingDurationInSeconds': dailyRemaining,
      },
      if (withNightMarket)
        'BonusStore': {
          'BonusStoreOffers': [
            {
              'BonusOfferID': 'n1',
              'Offer': offer('lvl-odin', 1275),
              'DiscountPercent': 30,
              'DiscountCosts': {vp: 893},
              'IsSeen': false,
            },
            {
              'BonusOfferID': 'n2',
              'Offer': offer('lvl-noicon', 2475),
              'DiscountPercent': 20,
              'DiscountCosts': {vp: 1980},
              'IsSeen': false,
            },
          ],
          'BonusStoreRemainingDurationInSeconds': 86400,
        },
    };

const radianite = 'e59aa87c-4cbf-517a-5983-6e81511be9b7';
const kingdom = '85ca954a-41f2-ce94-9b45-8ca3dd39a00d';
const skinLevelType = 'e7c63390-eda7-46e0-bb7a-a6abdacd2433';

/// 假的 Riot 各端點；可指定 storefront v3／v2 與 wallet 的狀態碼。
/// [requests] 會記錄每個請求，方便驗證方法、URL 與標頭。
MockClient riotClient({
  List<http.Request>? requests,
  int storefrontV3Status = 200,
  int storefrontV2Status = 200,
  int walletStatus = 200,
  bool corsBlocked = false,
  int historyStatus = 200,
  int historyTotal = 25,
  int mmrStatus = 200,
  bool brokenHistory = false,
  Set<String> failMatchIds = const {},
  Duration matchDelay = Duration.zero,
  bool blankNames = false,
  int nameStatus = 200,
  bool nameMalformed = false,
  Map<String, int> history429 = const {},
  bool retryAfter = false,
  Map<String, int> otherHistoryStatus = const {},
  Map<String, int> historyConnectionFail = const {},
  Map<String, int> otherMmrStatus = const {},
  Set<String> otherMmrHidden = const {},
  int partyStatus = 200,
  int partyDetailStatus = 200,
  Map<String, dynamic>? party,
  int coreStatus = 404,
  int pregameStatus = 404,
  bool unratedTiers = false,
  Map<String, List<String>> entitlements = const {},
  Map<String, int> entitlementStatus = const {},
  Map<String, int> entitlement429 = const {},
  int xpStatus = 200,
  int contractsStatus = 200,
  Map<String, dynamic>? contracts,
  void Function(String path)? onEntitlement,
  List<String>? skinLevels,
  // 他人紀錄的第 2 場是死鬥、第 3 場是一般（其他是競技）。
  bool mixedQueues = false,
  // 指定場次的 matchInfo 覆寫（例如 {'m2': {'queueID': 'unrated'}}）。
  Map<String, Map<String, dynamic>> matchInfoOverrides = const {},
  // 商店剩餘秒數（Riot 還沒換新商店時接近 0）。
  int dailyRemaining = 3600,
}) {
  final throttled = <String, int>{};
  final dropped = <String, int>{};
  return MockClient((req) async {
    requests?.add(req);
    final host = req.url.host;
    final path = req.url.path;
    // 瀏覽器實測：userinfo 與 riot-geo 的實際回應沒有 CORS 標頭，會被擋下。
    if (corsBlocked &&
        ((host == 'auth.riotgames.com' && path == '/userinfo') ||
            host == 'riot-geo.pas.si.riotgames.com')) {
      throw http.ClientException('XMLHttpRequest error.');
    }
    http.Response json(Object body, [int status = 200]) =>
        http.Response.bytes(utf8.encode(jsonEncode(body)), status,
            headers: {'content-type': 'application/json'});

    if (host == 'entitlements.auth.riotgames.com' && req.method == 'POST') {
      return json({'entitlements_token': 'fake-ent'});
    }
    if (host == 'auth.riotgames.com' && path == '/userinfo') {
      return json({
        'sub': 'puuid-1',
        'acct': {'game_name': 'Tester', 'tag_line': 'TW1'},
      });
    }
    if (host == 'riot-geo.pas.si.riotgames.com' && req.method == 'PUT') {
      return json({
        'token': 'geo',
        'affinities': {'pbe': 'na', 'live': 'ap'},
      });
    }
    if (host == 'valorant-api.com' && path == '/v1/version') {
      return json({
        'status': 200,
        'data': {'riotClientVersion': 'release-13.08-shipping-19-5698904'},
      });
    }
    // 即時對局（glz）：只有 GET。
    if (host == 'glz-ap-1.ap.a.pvp.net' && req.method == 'GET') {
      // 預設不在選角也不在對局（404），與實測相同。
      if (path == '/core-game/v1/players/puuid-1') {
        return coreStatus == 200
            ? json(corePlayerJson())
            : json({'httpStatus': coreStatus, 'errorCode': 'x'}, coreStatus);
      }
      if (path == '/core-game/v1/matches/$testCoreMatchId/loadouts') {
        return json(coreLoadoutsJson());
      }
      if (path == '/core-game/v1/matches/$testCoreMatchId') {
        return json(coreMatchJson());
      }
      if (path == '/pregame/v1/matches/$testPregameMatchId') {
        return json(pregameMatchJson());
      }
      if (path == '/pregame/v1/players/puuid-1') {
        return pregameStatus == 200
            ? json({
                'Subject': 'puuid-1',
                'MatchID': testPregameMatchId,
                'Version': 1
              })
            : json(
                {'httpStatus': pregameStatus, 'errorCode': 'x'}, pregameStatus);
      }
      if (path == '/parties/v1/players/puuid-1') {
        return partyStatus == 200
            ? json(partyPlayerJson())
            : json({'httpStatus': partyStatus, 'errorCode': 'x'}, partyStatus);
      }
      if (path == '/parties/v1/parties/$testPartyId') {
        return partyDetailStatus == 200
            ? json(party ?? partyJson())
            : json({'httpStatus': partyDetailStatus, 'errorCode': 'x'},
                partyDetailStatus);
      }
    }
    if (host == 'pd.ap.a.pvp.net') {
      if (path == '/store/v3/storefront/puuid-1' && req.method == 'POST') {
        return storefrontV3Status == 200
            ? json(storefrontJson(dailyRemaining: dailyRemaining))
            : json({'errorCode': 'x'}, storefrontV3Status);
      }
      if (path == '/store/v2/storefront/puuid-1' && req.method == 'GET') {
        return storefrontV2Status == 200
            ? json(storefrontJson(dailyRemaining: dailyRemaining))
            : json({'errorCode': 'x'}, storefrontV2Status);
      }
      if (path == '/store/v1/wallet/puuid-1') {
        return walletStatus == 200
            ? json({
                'Balances': {vp: 1500, radianite: 120, kingdom: 3000},
              })
            : json({'errorCode': 'x'}, walletStatus);
      }
      if (path == '/match-history/v1/history/puuid-1') {
        if (historyStatus != 200)
          return json({'errorCode': 'x'}, historyStatus);
        final start = int.parse(req.url.queryParameters['startIndex'] ?? '0');
        final end = int.parse(req.url.queryParameters['endIndex'] ?? '20');
        final count = (end < historyTotal ? end : historyTotal) - start;
        if (brokenHistory) {
          return json({
            'Total': 1,
            'History': [
              {'GameStartTime': 1}
            ]
          });
        }
        return json(historyJson(
            total: historyTotal, count: count < 0 ? 0 : count, start: start));
      }
      // 其他玩家的紀錄：第 1 場固定是 m1（所有人共用），其餘是各自的場次。
      if (path.startsWith('/match-history/v1/history/')) {
        final p = path.split('/').last;
        // 瀏覽器實測推測：限流回應沒有 CORS 標頭時只會看到連線失敗。
        final c = dropped[p] = (dropped[p] ?? 0) + 1;
        if (c <= (historyConnectionFail[p] ?? 0)) {
          throw http.ClientException('XMLHttpRequest error.');
        }
        final n = throttled[p] = (throttled[p] ?? 0) + 1;
        if (n <= (history429[p] ?? 0)) {
          return http.Response('{}', 429,
              headers: retryAfter ? {'retry-after': '1'} : const {});
        }
        final status = otherHistoryStatus[p] ?? 200;
        if (status != 200) return json({'errorCode': 'x'}, status);
        final start = int.parse(req.url.queryParameters['startIndex'] ?? '0');
        final end = int.parse(req.url.queryParameters['endIndex'] ?? '5');
        // 實測：查他人紀錄一次要 20 場會回 400，10 場正常。
        if (end - start > 10) return json({'errorCode': 'x'}, 400);
        return json({
          'Subject': p,
          'Total': 30,
          'History': [
            for (var i = start; i < end && i < 30; i++)
              {
                'MatchID': i == 0 ? 'm1' : '$p-g$i',
                'GameStartTime': 1760900000000 - i * 3600000,
                'QueueID': mixedQueues && i == 1
                    ? 'deathmatch'
                    : mixedQueues && i == 2
                        ? 'unrated'
                        : 'competitive',
              },
          ],
        });
      }
      if (path.startsWith('/match-details/v1/matches/')) {
        final id = path.split('/').last;
        if (matchDelay > Duration.zero) await Future<void>.delayed(matchDelay);
        if (failMatchIds.contains(id)) return json({'errorCode': 'x'}, 500);
        final m = matchDetailsJson();
        (m['matchInfo'] as Map<String, dynamic>)['matchId'] = id;
        final info = m['matchInfo'] as Map<String, dynamic>;
        for (final e in (matchInfoOverrides[id] ?? const {}).entries) {
          info[e.key] = e.value;
        }
        if (unratedTiers) {
          // 實測：一般模式的 match-details 每個人的牌位都是 0。
          for (final p in (m['players'] as List).cast<Map<String, dynamic>>()) {
            p['competitiveTier'] = 0;
          }
        }
        if (blankNames) {
          // 實測：match-details 的 gameName／tagLine 全部是空的。
          for (final p in (m['players'] as List).cast<Map<String, dynamic>>()) {
            p['gameName'] = '';
            p['tagLine'] = '';
          }
        }
        return json(m);
      }
      if (path == '/name-service/v2/players' && req.method == 'PUT') {
        if (nameStatus != 200) return json({'errorCode': 'x'}, nameStatus);
        if (nameMalformed)
          return json([
            {'Subject': 5, 'GameName': 'X'}
          ]);
        final ids = (jsonDecode(req.body) as List).cast<String>();
        return http.Response.bytes(
            utf8.encode(jsonEncode([
              for (final id in ids)
                {
                  'Subject': id,
                  'GameName': id == 'r5' ? '' : 'N-$id',
                  'TagLine': id == 'r5' ? '' : 'TW1',
                },
            ])),
            200,
            headers: {'content-type': 'application/json'});
      }
      if (path == '/mmr/v1/players/puuid-1/competitiveupdates') {
        return json(competitiveUpdatesJson());
      }
      // 他人的 MMR：用賽季資料找出他在這季的競技牌位。
      if (path.startsWith('/mmr/v1/players/') &&
          path != '/mmr/v1/players/puuid-1' &&
          !path.endsWith('/competitiveupdates')) {
        final p = path.split('/').last;
        final status = otherMmrStatus[p] ?? 200;
        if (status != 200) return json({'errorCode': 'x'}, status);
        return json(seasonalMmrJson(p, hidden: otherMmrHidden.contains(p)));
      }
      if (path == '/mmr/v1/players/puuid-1') {
        if (mmrStatus != 200) return json({'errorCode': 'x'}, mmrStatus);
        return json(mmrJson());
      }
      if (path == '/account-xp/v1/players/puuid-1') {
        if (xpStatus != 200) return json({'errorCode': 'x'}, xpStatus);
        return json(accountXpJson());
      }
      if (path == '/contracts/v1/contracts/puuid-1' && req.method == 'GET') {
        if (contractsStatus != 200) {
          return json({'errorCode': 'x'}, contractsStatus);
        }
        return json(contracts ?? contractsJson());
      }
      if (path.startsWith('/store/v1/entitlements/puuid-1/') &&
          path != '/store/v1/entitlements/puuid-1/$skinLevelType') {
        final type = path.split('/').last;
        onEntitlement?.call(type);
        final n = throttled['ent-$type'] = (throttled['ent-$type'] ?? 0) + 1;
        if (n <= (entitlement429[type] ?? 0)) {
          return http.Response('{}', 429,
              headers: retryAfter ? {'retry-after': '1'} : const {});
        }
        final status = entitlementStatus[type] ?? 200;
        if (status != 200) return json({'errorCode': 'x'}, status);
        return json({
          'ItemTypeID': type,
          'Entitlements': [
            for (final id in entitlements[type] ?? const <String>[])
              {'TypeID': type, 'ItemID': id},
          ],
        });
      }
      if (path == '/store/v1/entitlements/puuid-1/$skinLevelType') {
        onEntitlement?.call(skinLevelType);
        final n = throttled['ent-$skinLevelType'] =
            (throttled['ent-$skinLevelType'] ?? 0) + 1;
        if (n <= (entitlement429[skinLevelType] ?? 0)) {
          return http.Response('{}', 429,
              headers: retryAfter ? {'retry-after': '1'} : const {});
        }
        return json({
          'ItemTypeID': skinLevelType,
          'Entitlements': [
            if (skinLevels != null)
              for (final id in skinLevels)
                {'TypeID': skinLevelType, 'ItemID': id},
            if (skinLevels == null) ...[
              {'TypeID': skinLevelType, 'ItemID': 'lvl-odin'},
              {'TypeID': skinLevelType, 'ItemID': 'lvl-not-in-catalog'},
            ],
          ],
        });
      }
    }
    return http.Response('not found', 404);
  });
}

/// 測試用的假 JWT（簽章是假的；App 只解碼 payload，不驗證簽章）。
String fakeJwt(Map<String, dynamic> payload) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'RS256'})}.${part(payload)}.fake-signature';
}

final fakeAccessToken = fakeJwt({'sub': 'puuid-1'});
final fakeIdToken = fakeJwt({
  'sub': 'puuid-1',
  'acct': {'game_name': 'Tester', 'tag_line': 'TW1'},
});
final fakeRedirect = 'https://playvalorant.com/opt_in'
    '#access_token=$fakeAccessToken&id_token=$fakeIdToken&expires_in=3600';
