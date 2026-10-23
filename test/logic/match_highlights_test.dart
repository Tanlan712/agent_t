import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/match_highlights.dart';
import 'package:agent_t/logic/match_mapper.dart';
import 'package:agent_t/models/match_models.dart';

const vandal = '9C82E19D-4575-0200-1A81-3EACF00CF872';
const phantom = 'EE8E8D15-496B-07AC-E5F6-8FAE5D4C7B1A';

Map<String, dynamic> player(String id, String team) => {
      'subject': id,
      'teamId': team,
      'characterId': 'agent-$id',
      'stats': {'kills': 0, 'deaths': 0, 'assists': 0, 'score': 0},
    };

Map<String, dynamic> kill(String killer, String victim, int t,
        {String item = vandal, String type = 'Weapon'}) =>
    {
      'killer': killer,
      'victim': victim,
      'roundTime': t,
      'victimLocation': {'x': 100, 'y': 200},
      'playerLocations': [
        {
          'subject': killer,
          'location': {'x': 1, 'y': 2}
        }
      ],
      'finishingDamage': {'damageType': type, 'damageItem': item},
    };

Map<String, dynamic> stat(String id,
        {List<Map<String, dynamic>> kills = const [],
        String weapon = vandal,
        int loadout = 3900,
        int spent = 2900,
        int hs = 0,
        int body = 0}) =>
    {
      'subject': id,
      'kills': kills,
      'damage': [
        {'receiver': 'x', 'damage': 150, 'headshots': hs, 'bodyshots': body, 'legshots': 0}
      ],
      'economy': {
        'loadoutValue': loadout,
        'weapon': weapon,
        'armor': 'a',
        'remaining': 100,
        'spent': spent,
      },
    };

/// 藍隊 me、m1、m2；紅隊 e1、e2、e3。
Map<String, dynamic> matchJson() => {
      'matchInfo': {'matchId': 'm', 'mapId': '/Game/Maps/Ascent/Ascent'},
      'players': [
        player('me', 'Blue'),
        player('m1', 'Blue'),
        player('m2', 'Blue'),
        player('e1', 'Red'),
        player('e2', 'Red'),
        player('e3', 'Red'),
      ],
      'teams': [
        {'teamId': 'Blue', 'won': true, 'roundsWon': 2},
        {'teamId': 'Red', 'won': false, 'roundsWon': 1},
      ],
      'roundResults': [
        // 第 1 回合：我三殺、清光。
        {
          'roundNum': 0,
          'winningTeam': 'Blue',
          'roundResult': 'Eliminated',
          'roundResultCode': 'Elimination',
          'bombPlanter': 'me',
          'plantLocation': {'x': 5, 'y': 6},
          'playerStats': [
            stat('me',
                kills: [kill('me', 'e1', 1000), kill('me', 'e2', 2000), kill('me', 'e3', 3000)],
                hs: 3,
                body: 1),
            stat('m1'),
            stat('m2'),
            stat('e1', loadout: 800, spent: 400),
            stat('e2', loadout: 800, spent: 400),
            stat('e3', loadout: 800, spent: 400),
          ],
        },
        // 第 2 回合：隊友先死光，我 1v3 贏（拆包）。
        {
          'roundNum': 1,
          'winningTeam': 'Blue',
          'roundResult': 'Bomb defused',
          'roundResultCode': 'Defuse',
          'bombDefuser': 'me',
          'playerStats': [
            stat('me', kills: [kill('me', 'e1', 9000, item: phantom)], weapon: phantom, hs: 1, body: 3),
            stat('m1'),
            stat('m2'),
            stat('e1', kills: [kill('e1', 'm1', 1000)]),
            stat('e2', kills: [kill('e2', 'm2', 2000, item: 'Ability1', type: 'Ability')]),
            stat('e3', kills: [kill('e3', 'me', 99999)]),
          ],
        },
        // 第 3 回合：輸（爆炸），我被殺。
        {
          'roundNum': 2,
          'winningTeam': 'Red',
          'roundResult': 'Bomb detonated',
          'roundResultCode': 'Detonate',
          'playerStats': [
            stat('me', weapon: vandal),
            stat('e1', kills: [kill('e1', 'me', 500)]),
          ],
        },
      ],
    };

void main() {
  final d = mapMatchDetail(matchJson(), 'me');

  test('解析回合：勝方、結束方式、下包／拆包者與經濟', () {
    expect(d.rounds.map((r) => r.end),
        [RoundEnd.elimination, RoundEnd.defuse, RoundEnd.detonate]);
    expect(d.rounds.first.planter, 'me');
    expect(d.rounds.first.plantAt?.x, 5);
    expect(d.rounds[1].defuser, 'me');
    final me = d.rounds.first.players['me']!;
    expect(me.loadout, 3900);
    expect(me.spent, 2900);
    expect(me.weapon, vandal.toLowerCase());
    expect(me.headshots, 3);
    expect(me.kills, 3);
  });

  test('解析擊殺：依回合與時間排序，武器 uuid 轉小寫，位置', () {
    expect(d.kills, hasLength(8));
    expect(d.kills.first.victim, 'e1');
    expect(d.kills.first.damageItem, vandal.toLowerCase());
    expect(d.kills.first.victimAt?.y, 200);
    expect(d.kills.first.killerAt?.x, 1);
    expect(d.kills.where((k) => k.round == 1).map((k) => k.victim),
        ['m1', 'm2', 'e1', 'me']);
  });

  test('多殺與殘局：3 殺一次、1v3 勝一次', () {
    final h = matchHighlights(d, 'me');
    expect(h.threeKs, 1);
    expect(h.aces, 0);
    expect(h.clutches, {3: 1});
    expect(h.clutchesWon, 1);
    final sum = h + h;
    expect(sum.threeKs, 2);
    expect(sum.clutches, {3: 2});
    expect(matchHighlights(d, 'nobody').isEmpty, isTrue);
  });

  test('輸掉的回合不算殘局', () {
    final json = matchJson();
    (json['roundResults'] as List)[1]['winningTeam'] = 'Red';
    expect(matchHighlights(mapMatchDetail(json, 'me'), 'me').clutches, isEmpty);
  });

  test('武器統計：擊殺只算槍枝；爆頭率與勝率依每回合主武器', () {
    final stats = weaponStats([d], 'me');
    final v = stats.firstWhere((s) => s.weapon == vandal.toLowerCase());
    final p = stats.firstWhere((s) => s.weapon == phantom.toLowerCase());
    expect(v.kills, 3);
    expect(p.kills, 1);
    expect(v.rounds, 2);
    expect(v.roundsWon, 1);
    expect(v.winRate, 50);
    expect(v.headshotPercent, closeTo(3 / 4 * 100, 0.01));
    expect(p.headshotPercent, 25);
    expect(stats.first.weapon, vandal.toLowerCase());
  });

  test('隊伍經濟與局型', () {
    final eco = teamEconomy(d.rounds.first, d.teamOf, 'Blue');
    expect(eco.myLoadout, 3900 * 3);
    expect(eco.enemyLoadout, 2400);
    expect(eco.enemySpent, 1200);
    expect(buyLabel(eco.myLoadout, 3), '全起');
    expect(buyLabel(eco.enemyLoadout, 3), '經濟局');
    expect(buyLabel(1800 * 5, 5), '半起');
  });

  test('熱區點：擊殺與陣亡', () {
    final pts = heatPoints(d, 'me');
    expect(pts.where((p) => p.$2), hasLength(4));
    expect(pts.where((p) => !p.$2), hasLength(2));
  });

  test('小地圖座標換算（x、y 互換）', () {
    const m = MinimapRef(
        imageUrl: 'u',
        xMultiplier: 0.0001,
        yMultiplier: -0.0001,
        xScalarToAdd: 0.5,
        yScalarToAdd: 0.4);
    final (x, y) = m.project(const MapPoint(1000, 2000));
    expect(x, closeTo(0.7, 1e-9));
    expect(y, closeTo(0.3, 1e-9));
    final back = MinimapRef.fromJson(m.toJson());
    expect(back.yScalarToAdd, 0.4);
  });

  test('applyNames 保留回合與擊殺', () {
    expect(applyNames(d, {'me': 'Me#1'}).kills, hasLength(8));
  });
}
