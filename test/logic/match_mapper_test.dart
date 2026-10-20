import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/match_mapper.dart';

import '../match_fixtures.dart';

void main() {
  group('mapMatchDetail', () {
    final d = mapMatchDetail(matchDetailsJson(), myPuuid, rrChange: 18);
    final all = d.teams.values.expand((t) => t).toList();
    final me = all.singleWhere((p) => p.isMe);

    test('Riot ID 與未知玩家', () {
      expect(me.riotId, 'Alpha#TW1');
      expect(all.singleWhere((p) => p.puuid == 'r5').riotId, '未知玩家');
    });

    test('ACS 四捨五入且 roundsPlayed 為 0 時為 0', () {
      expect(me.acs, 191);
      expect(all.singleWhere((p) => p.puuid == 'r5').acs, 0);
    });

    test('排除觀戰者，兩隊各 5 人且依分數遞減', () {
      expect(all.any((p) => p.puuid == 'obs'), isFalse);
      expect(d.teams['Blue']!.length, 5);
      expect(d.teams['Red']!.length, 5);
      final scores = d.teams['Red']!.map((p) => p.score).toList();
      expect(scores, [5000, 3100, 2500, 900, 0]);
    });

    test('比分與勝負取自 teams', () {
      expect(d.summary.myScore, 13);
      expect(d.summary.enemyScore, 9);
      expect(d.summary.won, isTrue);
      expect(d.summary.myTeamId, 'Blue');
    });

    test('沒有 teams 時從 roundResults 計數', () {
      final s =
          mapMatchDetail(matchDetailsJson(withTeams: false), myPuuid).summary;
      expect(s.myScore, 1);
      expect(s.enemyScore, 1);
      expect(s.won, isNull);
    });

    test('爆頭率', () {
      expect(me.headshotPercent, 30.0);
      expect(all.singleWhere((p) => p.puuid == 'r1').headshotPercent, isNull);
    });

    test('自己的摘要欄位', () {
      expect(all.where((p) => p.isMe).length, 1);
      expect(d.summary.myAgentId, 'agent-$myPuuid');
      expect(d.summary.kills, 20);
      expect(d.summary.deaths, 12);
      expect(d.summary.assists, 4);
      expect(d.summary.rrChange, 18);
      expect(d.summary.mapId, '/Game/Maps/Ascent/Ascent');
      expect(d.summary.durationMs, 2100000);
      expect(d.summary.isRanked, isTrue);
      expect(d.summary.startTime,
          DateTime.fromMillisecondsSinceEpoch(1760900000000));
      expect(me.partyId, 'p1');
      expect(me.tier, 18);
    });
  });

  test('queueName', () {
    expect(queueName('competitive'), '競技');
    expect(queueName('unrated'), '一般');
    expect(queueName('swiftplay'), '超速衝點');
    expect(queueName('newmode'), 'newmode');
  });

  test('rrByMatch', () {
    expect(rrByMatch(competitiveUpdatesJson()), {'m1': 18, 'm2': -15});
  });

  test('mapRank', () {
    final r = mapRank(mmrJson())!;
    expect(r.tier, 18);
    expect(r.rr, 45);
    expect(mapRank(mmrJson(empty: true)), isNull);
  });

  test('mapHistory', () {
    final refs = mapHistory(historyJson());
    expect(refs.length, 3);
    expect(refs.first.matchId, 'm1');
    expect(refs.first.queueId, 'competitive');
    expect(refs.first.startTime,
        DateTime.fromMillisecondsSinceEpoch(1760900000000));
  });
}
