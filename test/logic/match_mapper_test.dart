import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/match_mapper.dart';
import 'package:valorant_shop_tracker/models/match_models.dart';

import '../match_fixtures.dart';

void main() {
  group('審查修正', reviewFixTests);
  group('加強版數據', playerStatsTests);
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

void reviewFixTests() {
  test('勝負優先採用 teams[].won（例如對手投降時回合數較少仍判勝）', () {
    final json = matchDetailsJson();
    json['teams'] = [
      {'teamId': 'Blue', 'won': true, 'roundsWon': 7},
      {'teamId': 'Red', 'won': false, 'roundsWon': 9},
    ];
    final s = mapMatchDetail(json, myPuuid).summary;
    expect(s.won, isTrue);
    expect(s.myScore, 7);
    expect(s.enemyScore, 9);
  });

  test('rrByMatch 只保留競技場次', () {
    expect(rrByMatch(competitiveUpdatesJson()).containsKey('m9'), isFalse);
  });
}

void playerStatsTests() {
  final d = mapMatchDetail(matchDetailsJson(), myPuuid);
  final all = d.teams.values.expand((t) => t).toList();
  PlayerLine p(String id) => all.singleWhere((l) => l.puuid == id);

  test('K/D 取兩位小數前的原值，deaths 為 0 時等於 kills', () {
    expect(p(myPuuid).kd, closeTo(1.666, 0.01));
    expect(p('b5').kd, 7);
  });

  test('ADR 為總傷害 ÷ roundsPlayed 四捨五入，沒有回合時為 0', () {
    // 第 0 回合 2×40+4×25+1×20=200，第 1 回合 40+2×25=90，共 290 ÷ 22。
    expect(p(myPuuid).adr, 13);
    expect(p('r5').adr, 0);
  });

  test('首殺優先用 firstBloodPlayer，缺少時取最早的擊殺', () {
    expect(p(myPuuid).firstKills, 1);
    expect(p('r1').firstKills, 2);
    expect(p('mate').firstKills, 0);
  });

  test('MVP 採用 Riot 的 matchMvp 與 teams[].mvp', () {
    expect(p('r1').mvp, MvpKind.match);
    expect(p(myPuuid).mvp, MvpKind.team);
    expect(p('mate').mvp, MvpKind.none);
  });

  test('沒有 MVP 欄位時以分數推算', () {
    final f = mapMatchDetail(matchDetailsJson(withTeams: false), myPuuid);
    final fa = f.teams.values.expand((t) => t).toList();
    MvpKind m(String id) => fa.singleWhere((l) => l.puuid == id).mvp;
    expect(m('r1'), MvpKind.match);
    expect(m(myPuuid), MvpKind.team);
    expect(m('r2'), MvpKind.none);
  });

  test('表現分數取自 scores.TempValueF，沒有時為 null', () {
    expect(p(myPuuid).rating, closeTo(265.4, 0.001));
    expect(p('r1').rating, 452);
    expect(p('mate').rating, isNull);
  });

  test('summary 以 focusPuuid 為主，isMe 依 selfPuuid', () {
    final o = mapMatchDetail(matchDetailsJson(), 'r1', selfPuuid: myPuuid);
    expect(o.summary.myAgentId, 'agent-r1');
    expect(o.summary.myTeamId, 'Red');
    expect(o.summary.won, isFalse);
    final mine = o.teams.values.expand((t) => t).where((l) => l.isMe);
    expect(mine.single.puuid, myPuuid);
  });

  test('applyNames 保留新欄位', () {
    final n = applyNames(d, {'r1': 'X#1'});
    final r1 = n.teams['Red']!.first;
    expect(r1.riotId, 'X#1');
    expect(r1.mvp, MvpKind.match);
    expect(r1.rating, 452);
    expect(r1.firstKills, 2);
    expect(r1.kd, p('r1').kd);
    expect(r1.adr, p('r1').adr);
  });
}
