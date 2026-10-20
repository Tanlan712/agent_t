import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

Map<String, dynamic> storefrontJson({bool withNightMarket = true}) => {
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
        'SingleItemOffersRemainingDurationInSeconds': 3600,
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
}) {
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
    if (host == 'pd.ap.a.pvp.net') {
      if (path == '/store/v3/storefront/puuid-1' && req.method == 'POST') {
        return storefrontV3Status == 200
            ? json(storefrontJson())
            : json({'errorCode': 'x'}, storefrontV3Status);
      }
      if (path == '/store/v2/storefront/puuid-1' && req.method == 'GET') {
        return storefrontV2Status == 200
            ? json(storefrontJson())
            : json({'errorCode': 'x'}, storefrontV2Status);
      }
      if (path == '/store/v1/wallet/puuid-1') {
        return walletStatus == 200
            ? json({
                'Balances': {vp: 1500, radianite: 120, kingdom: 3000},
              })
            : json({'errorCode': 'x'}, walletStatus);
      }
      if (path == '/store/v1/entitlements/puuid-1/$skinLevelType') {
        return json({
          'ItemTypeID': skinLevelType,
          'Entitlements': [
            {'TypeID': skinLevelType, 'ItemID': 'lvl-odin'},
            {'TypeID': skinLevelType, 'ItemID': 'lvl-not-in-catalog'},
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
