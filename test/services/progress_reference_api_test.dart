import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valorant_shop_tracker/models/progress_reference.dart';
import 'package:valorant_shop_tracker/services/catalog_api.dart';
import 'package:valorant_shop_tracker/services/progress_reference_api.dart';

http.Response data(Object body) => http.Response.bytes(
    utf8.encode(jsonEncode({'status': 200, 'data': body})), 200);

MockClient api({int failStatus = 200, List<Uri>? seen}) =>
    MockClient((req) async {
      seen?.add(req.url);
      if (failStatus != 200 && req.url.path == '/v1/missions') {
        return http.Response('', failStatus);
      }
      return switch (req.url.path) {
        '/v1/weapons' => data([
            {
              'uuid': 'W-VANDAL',
              'displayName': '暴徒',
              'displayIcon': 'vandal.png',
              'category': 'EEquippableCategory::Rifle',
              'shopData': {'categoryText': '突擊步槍'},
              'skins': [
                {
                  'uuid': 'SKIN-V',
                  'displayName': '光幻 暴徒',
                  'levels': [
                    {
                      'uuid': 'LV-1',
                      'displayIcon': 'a.png',
                      'streamedVideo': null
                    },
                    {
                      'uuid': 'LV-2',
                      'displayIcon': 'b.png',
                      'streamedVideo': 'b.mp4'
                    },
                  ],
                  'chromas': [
                    {'uuid': 'CH-1', 'swatch': 'sw.png'},
                  ],
                },
              ],
            },
          ]),
        '/v1/agents' => data([
            {
              'uuid': 'AG-1',
              'displayName': '捷風',
              'displayIcon': 'j.png',
              'role': {'displayName': '決鬥者'},
              'isBaseContent': true,
            },
          ]),
        '/v1/buddies' => data([
            {
              'displayName': '小吊飾',
              'displayIcon': 'bd.png',
              'levels': [
                {'uuid': 'BL-1'},
              ],
            },
          ]),
        '/v1/sprays' => data([
            {'uuid': 'SP-1', 'displayName': '噴漆', 'displayIcon': 'sp.png'},
          ]),
        '/v1/playercards' => data([
            {'uuid': 'PC-1', 'displayName': '卡片', 'smallArt': 'pc.png'},
          ]),
        '/v1/playertitles' => data([
            {'uuid': 'T-1', 'displayName': '稱號名', 'titleText': '稱號文字'},
            {'uuid': 'T-2', 'displayName': '只有名稱', 'titleText': null},
          ]),
        '/v1/contracts' => data([
            {
              'uuid': 'BP-1',
              'displayName': '通行證',
              'content': {
                'relationType': 'Season',
                'relationUuid': 'ACT-1',
                'chapters': [
                  {
                    'levels': [
                      {
                        'reward': {
                          'type': 'Spray',
                          'uuid': 'SP-1',
                          'amount': 1
                        },
                        'xp': 2000,
                      },
                      {
                        'reward': {
                          'type': 'PlayerCard',
                          'uuid': 'PC-1',
                          'amount': 1
                        },
                        'xp': 3000,
                      },
                    ],
                    'freeRewards': [
                      {'type': 'Title', 'uuid': 'T-1', 'amount': 1},
                    ],
                  },
                  {
                    'isEpilogue': true,
                    'levels': [
                      {
                        'reward': {
                          'type': 'Currency',
                          'uuid': 'VP',
                          'amount': 10
                        },
                        'xp': 4000,
                      },
                    ],
                    'freeRewards': null,
                  },
                ],
              },
            },
          ]),
        '/v1/currencies' => data([
            {
              'uuid': 'E59AA87C-4CBF-517A-5983-6E81511BE9B7',
              'displayName': '輻能點數',
              'displayIcon': 'rad.png',
            },
          ]),
        '/v1/seasons' => data([
            {
              'uuid': 'ACT-1',
              'displayName': '第一幕',
              'startTime': '2026-09-01T00:00:00Z',
              'endTime': '2026-11-01T00:00:00Z',
            },
          ]),
        '/v1/missions' => data([
            {
              'uuid': 'M-1',
              'title': '每日任務',
              'type': 'EAresMissionType::Daily',
              'xpGrant': 2000,
              'progressToComplete': 3,
            },
            {
              'uuid': 'M-2',
              'title': '每週任務',
              'type': 'EAresMissionType::Weekly',
              'xpGrant': 8000,
              'progressToComplete': 0,
            },
            {'uuid': 'M-3', 'title': '新手', 'type': null, 'xpGrant': 0},
          ]),
        _ => http.Response('', 404),
      };
    });

void main() {
  test('下載並轉成以小寫 uuid 為 key 的參考資料', () async {
    final seen = <Uri>[];
    final r = await ProgressReferenceApi(client: api(seen: seen)).fetch();
    expect(seen.every((u) => u.host == 'valorant-api.com'), isTrue);
    expect(seen.every((u) => u.queryParameters['language'] == 'zh-TW'), isTrue);

    final lv2 = r.skinLevels['lv-2']!;
    expect(lv2.skinUuid, 'skin-v');
    expect(lv2.weaponName, '暴徒');
    expect(lv2.levelIndex, 1);
    expect(lv2.videoUrl, 'b.mp4');
    expect(lv2.weaponUuid, 'w-vandal');
    expect(r.weapons.single.uuid, 'w-vandal');
    expect(r.weapons.single.name, '暴徒');
    expect(r.weapons.single.iconUrl, 'vandal.png');
    expect(r.weapons.single.category, 'EEquippableCategory::Rifle');
    expect(r.weapons.single.categoryText, '突擊步槍');
    expect(r.agents['ag-1']!.uuid, 'ag-1');
    expect(r.chromas['ch-1']!.swatchUrl, 'sw.png');
    expect(r.agents['ag-1']!.isBase, isTrue);
    expect(r.agents['ag-1']!.role, '決鬥者');
    expect(r.buddyLevels['bl-1']!.name, '小吊飾');
    expect(r.sprays['sp-1']!.iconUrl, 'sp.png');
    expect(r.cards['pc-1']!.iconUrl, 'pc.png');
    expect(r.titles['t-1']!.name, '稱號文字');
    expect(r.titles['t-2']!.name, '只有名稱');

    final bp = r.contracts['bp-1']!;
    expect(bp.relationType, 'Season');
    expect(bp.relationUuid, 'act-1');
    expect(bp.tiers.map((t) => t.xp), [2000, 3000, 4000]);
    // 章節的免費獎勵掛在該章最後一階。
    expect(bp.tiers[1].freeRewards.single.uuid, 't-1');
    expect(bp.tiers[0].freeRewards, isEmpty);
    expect(bp.tiers[2].reward.amount, 10);
    expect(bp.chapters, hasLength(2));
    expect(bp.chapters[0].tiers, hasLength(2));
    expect(bp.chapters[0].freeRewards.single.uuid, 't-1');
    expect(bp.chapters[0].isEpilogue, isFalse);
    expect(bp.chapters[1].isEpilogue, isTrue);
    expect(bp.chapters[1].freeRewards, isEmpty);
    expect(r.currencies['e59aa87c-4cbf-517a-5983-6e81511be9b7']!.name, '輻能點數');

    expect(r.seasons['act-1']!.end, DateTime.utc(2026, 11, 1));
    expect(r.missions['m-1']!.kind, MissionKind.daily);
    expect(r.missions['m-2']!.kind, MissionKind.weekly);
    expect(r.missions['m-2']!.target, 1);
    expect(r.missions['m-3']!.kind, MissionKind.other);
  });

  test('任一端點失敗時丟 CatalogFetchException', () async {
    await expectLater(
        ProgressReferenceApi(client: api(failStatus: 500)).fetch(),
        throwsA(isA<CatalogFetchException>()));
  });
}
