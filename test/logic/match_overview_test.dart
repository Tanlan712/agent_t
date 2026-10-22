import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/match_overview.dart';
import 'package:valorant_shop_tracker/models/match_models.dart';

PlayerLine line(String puuid,
        {String team = 'Blue',
        String agent = 'jett',
        int k = 10,
        int d = 10,
        int acs = 200,
        int adr = 130,
        double? hs = 20,
        double? rating}) =>
    PlayerLine(
      puuid: puuid,
      riotId: '$puuid#TW',
      teamId: team,
      partyId: '',
      agentId: agent,
      tier: 0,
      accountLevel: 1,
      kills: k,
      deaths: d,
      assists: 3,
      score: acs * 20,
      acs: acs,
      headshotPercent: hs,
      isMe: puuid == 'me',
      adr: adr,
      rating: rating,
    );

MatchDetail detail(String id,
    {DateTime? at,
    String focus = 'me',
    bool? won = true,
    int? rr,
    String map = 'ascent',
    String agent = 'jett',
    List<PlayerLine>? lines}) {
  final ls = lines ?? [line('me', agent: agent), line('x', team: 'Red')];
  final me = ls.firstWhere((l) => l.puuid == focus);
  return MatchDetail(
    summary: MatchSummary(
      matchId: id,
      startTime: at ?? DateTime(2026, 10, 22, 12),
      queueId: 'competitive',
      mapId: map,
      durationMs: 1,
      isRanked: true,
      myTeamId: me.teamId,
      focusPuuid: focus,
      won: won,
      myScore: 13,
      enemyScore: 7,
      myAgentId: me.agentId,
      kills: me.kills,
      deaths: me.deaths,
      assists: me.assists,
      acs: me.acs,
      rrChange: rr,
    ),
    teams: {
      for (final t in {for (final l in ls) l.teamId})
        t: [
          for (final l in ls)
            if (l.teamId == t) l
        ],
    },
  );
}

void main() {
  group('焦點玩家', () {
    test('依 focusPuuid 找到那一列（看別人的場次時不是自己）', () {
      final d = detail('m',
          focus: 'other',
          lines: [line('me'), line('other', acs: 321, team: 'Red')]);
      expect(focusLine(d)?.acs, 321);
    });

    test('沒有 focusPuuid 時找不到就回傳 null', () {
      final d = detail('m', focus: 'me');
      final noFocus = MatchDetail(
          summary: MatchSummary(
            matchId: 'm',
            startTime: DateTime(2026),
            queueId: '',
            mapId: '',
            durationMs: 0,
            isRanked: false,
            myTeamId: 'Blue',
            myScore: 0,
            enemyScore: 0,
            myAgentId: 'jett',
            kills: 0,
            deaths: 0,
            assists: 0,
          ),
          teams: d.teams);
      expect(focusLine(noFocus), isNull);
    });
  });

  group('摘要', () {
    test('K/D 是總擊殺÷總死亡；爆頭率與 ADR 是平均；勝率不算平手', () {
      final o = summarizeHistory([
        detail('a', lines: [line('me', k: 20, d: 10, hs: 30, adr: 160)]),
        detail('b',
            won: false, lines: [line('me', k: 10, d: 10, hs: null, adr: 100)]),
        detail('c', won: null, lines: [line('me', k: 0, d: 10, hs: 10)]),
      ]);
      expect(o.games, 3);
      expect(o.wins, 1);
      expect(o.losses, 1);
      expect(o.winRate, 0.5);
      expect(o.kd, closeTo(1.0, 1e-9));
      expect(o.headshot, closeTo(20, 1e-9));
      expect(o.adr, closeTo(130, 1e-9));
    });

    test('沒有場次時都是 null', () {
      final o = summarizeHistory([]);
      expect(o.games, 0);
      expect(o.winRate, isNull);
      expect(o.kd, isNull);
      expect(o.headshot, isNull);
      expect(o.adr, isNull);
    });

    test('近期戰績由新到舊最多 10 場；常用特務依場數取前 3', () {
      final list = [
        for (var i = 0; i < 12; i++)
          detail('m$i',
              won: i.isEven,
              agent: i < 6
                  ? 'jett'
                  : (i < 9 ? 'sage' : (i < 11 ? 'omen' : 'kayo'))),
      ];
      final o = summarizeHistory(list);
      expect(o.form.map((d) => d.summary.matchId).toList(),
          [for (var i = 0; i < 10; i++) 'm$i']);
      expect(o.topAgents.map((a) => a.key).toList(), ['jett', 'sage', 'omen']);
      expect(o.topAgents.first.games, 6);
      expect(o.topAgents.first.winRate, 0.5);
    });
  });

  group('依日期分組', () {
    final now = DateTime(2026, 10, 22, 15);

    test('標題：今天、昨天、其他日期加星期', () {
      expect(dayLabel(DateTime(2026, 10, 22), now), '今天');
      expect(dayLabel(DateTime(2026, 10, 21), now), '昨天');
      expect(dayLabel(DateTime(2026, 10, 20), now), '10/20（二）');
      expect(dayLabel(DateTime(2026, 10, 18), now), '10/18（日）');
      expect(dayLabel(DateTime(2025, 12, 31), now), '2025/12/31（三）');
    });

    test('依本地日期分組、保留順序；每組統計勝敗與 RR', () {
      final items = [
        (DateTime(2026, 10, 22, 1), detail('a', rr: 20)),
        (DateTime(2026, 10, 22, 0, 30), detail('b', won: false, rr: -15)),
        (DateTime(2026, 10, 21, 23, 59), detail('c', won: true)),
        (DateTime(2026, 10, 21, 10), null),
      ];
      final groups = groupByDay(items, (e) => e.$1, (e) => e.$2?.summary);
      expect(groups.map((g) => g.day).toList(),
          [DateTime(2026, 10, 22), DateTime(2026, 10, 21)]);
      expect(groups.first.items.length, 2);
      expect(groups.first.wins, 1);
      expect(groups.first.losses, 1);
      expect(groups.first.rr, 5);
      expect(groups.last.items.length, 2);
      expect(groups.last.wins, 1);
      expect(groups.last.rr, isNull);
    });

    test('組標題的副標', () {
      expect(dayStatsLabel(wins: 3, losses: 1, rr: 25), '3 勝 1 敗 · RR +25');
      expect(dayStatsLabel(wins: 0, losses: 2, rr: -30), '0 勝 2 敗 · RR -30');
      expect(dayStatsLabel(wins: 1, losses: 0, rr: null), '1 勝 0 敗');
    });
  });
}
