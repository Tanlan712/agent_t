import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/models/match_models.dart';
import 'package:valorant_shop_tracker/providers/match_reference_provider.dart';
import 'package:valorant_shop_tracker/services/match_reference_api.dart';
import 'package:valorant_shop_tracker/storage/match_reference_cache.dart';

/// 依 valorant-api.com 實際欄位精簡的參考資料。
MockClient referenceClient({void Function()? onRequest, bool fail = false}) =>
    MockClient((req) async {
      onRequest?.call();
      if (fail) return http.Response('down', 503);
      http.Response json(Object o) => http.Response.bytes(
          utf8.encode(jsonEncode({'status': 200, 'data': o})), 200);
      expect(req.url.queryParameters['language'], 'zh-TW');
      switch (req.url.path) {
        case '/v1/agents':
          return json([
            {
              'uuid': 'E370FA57-AAAA',
              'displayName': '蓋克',
              'displayIcon': 'https://x/gekko.png'
            },
          ]);
        case '/v1/maps':
          return json([
            {
              'mapUrl': '/Game/Maps/Ascent/Ascent',
              'displayName': '亞海懸城',
              'listViewIcon': 'https://x/ascent.png'
            },
          ]);
        case '/v1/seasons':
          return json([
            {
              'uuid': 'EP-26',
              'displayName': 'V26',
              'type': null,
              'parentUuid': null,
              'startTime': '2026-06-24T00:00:00Z',
              'endTime': '2027-01-06T00:00:00Z',
            },
            {
              'uuid': 'ACT-6',
              'displayName': '第六幕',
              'type': 'EAresSeasonType::Act',
              'parentUuid': 'EP-26',
              'startTime': '2026-10-14T00:00:00Z',
              'endTime': '2027-01-06T00:00:00Z',
            },
            {'uuid': 'broken', 'displayName': 'x'},
          ]);
        case '/v1/competitivetiers':
          return json([
            {
              'tiers': [
                {
                  'tier': 18,
                  'tierName': '舊賽季鑽石',
                  'smallIcon': 'https://x/old18.png'
                },
              ],
            },
            {
              'tiers': [
                {'tier': 0, 'tierName': '未定級', 'smallIcon': null},
                {
                  'tier': 18,
                  'tierName': '鑽石 2',
                  'smallIcon': 'https://x/18.png'
                },
              ],
            },
          ]);
      }
      return http.Response('not found', 404);
    });

/// 只讓 /v1/seasons 失敗，其他請求轉給 [inner]。
class _FailSeasons extends http.BaseClient {
  final http.Client inner;
  _FailSeasons(this.inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      request.url.path == '/v1/seasons'
          ? http.StreamedResponse(Stream.value(const []), 500)
          : inner.send(request);
}

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('fetch 解析特務、地圖與最後一個賽季的牌位', () async {
    final r = await MatchReferenceApi(client: referenceClient()).fetch();
    expect(r.agents['e370fa57-aaaa']!.name, '蓋克');
    expect(r.maps['/Game/Maps/Ascent/Ascent']!.name, '亞海懸城');
    expect(r.maps['/Game/Maps/Ascent/Ascent']!.iconUrl, 'https://x/ascent.png');
    expect(r.tiers[18]!.name, '鑽石 2');
    expect(r.tiers[18]!.iconUrl, 'https://x/18.png');
  });

  test('fetch 解析賽季：幕的名稱帶上層賽季，缺日期的略過', () async {
    final r = await MatchReferenceApi(client: referenceClient()).fetch();
    final act = r.seasons['act-6']!;
    expect(act.name, 'V26 第六幕');
    expect(act.isAct, isTrue);
    expect(act.start, DateTime.utc(2026, 10, 14));
    expect(r.seasons['ep-26']!.isAct, isFalse);
    expect(r.seasons.containsKey('broken'), isFalse);
  });

  test('賽季下載失敗時其他資料照常', () async {
    final r = await MatchReferenceApi(client: _FailSeasons(referenceClient()))
        .fetch();
    expect(r.seasons, isEmpty);
    expect(r.tiers[18]!.name, '鑽石 2');
  });

  test('快取存入讀出一致、損壞時回傳 null', () async {
    final cache = MatchReferenceCache(prefs);
    await cache
        .save(await MatchReferenceApi(client: referenceClient()).fetch());
    expect(cache.load()!.tiers[18]!.name, '鑽石 2');
    expect(cache.load()!.seasons['act-6']!.name, 'V26 第六幕');
    SharedPreferences.setMockInitialValues({'match_reference_v2': '{bad'});
    expect(MatchReferenceCache(await SharedPreferences.getInstance()).load(),
        isNull);
  });

  test('provider：特務 uuid 不分大小寫、找不到時用縮寫', () async {
    final p = MatchReferenceProvider(
        MatchReferenceApi(client: referenceClient()),
        MatchReferenceCache(prefs));
    await p.init();
    expect(p.agent('E370FA57-aaaa').name, '蓋克');
    expect(p.map('/Game/Maps/Ascent/Ascent').name, '亞海懸城');
    expect(p.tier(18).name, '鑽石 2');
    expect(p.agent('ABCDEFGH-1234').name, 'abcdefgh');
    expect(p.tier(99).name, '未定級');
  });

  test('provider：下載失敗不丟例外，回傳佔位', () async {
    final p = MatchReferenceProvider(
        MatchReferenceApi(client: referenceClient(fail: true)),
        MatchReferenceCache(prefs));
    await p.init();
    expect(p.reference, isNull);
    expect(p.agent('ABCDEFGH-1234').name, 'abcdefgh');
    expect(p.agent('ABCDEFGH-1234').iconUrl, isNull);
  });

  test('provider：有快取時不呼叫 API', () async {
    await MatchReferenceCache(prefs).save(const MatchReference(
        agents: {}, maps: {}, tiers: {18: RefItem(name: '鑽石 2')}));
    var requests = 0;
    final p = MatchReferenceProvider(
        MatchReferenceApi(client: referenceClient(onRequest: () => requests++)),
        MatchReferenceCache(prefs));
    await p.init();
    expect(requests, 0);
    expect(p.tier(18).name, '鑽石 2');
  });
}
