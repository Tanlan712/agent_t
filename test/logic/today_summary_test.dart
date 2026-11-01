import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/today_summary.dart';
import 'package:agent_t/models/match_models.dart';

MatchSummary _g(DateTime t,
        {bool? won, int? rr, String agent = 'jett', int k = 10, int d = 10}) =>
    MatchSummary(
      matchId: '$t',
      startTime: t,
      queueId: 'competitive',
      mapId: 'm',
      durationMs: 1,
      isRanked: true,
      myTeamId: 'Blue',
      won: won,
      myScore: 13,
      enemyScore: 7,
      myAgentId: agent,
      kills: k,
      deaths: d,
      assists: 2,
      acs: 200,
      rrChange: rr,
    );

void main() {
  final now = DateTime(2026, 11, 1, 22);

  test('只算今天的場次：勝率、RR 淨變化、K/D、最常用特務', () {
    final s = todaySummary([
      _g(DateTime(2026, 11, 1, 21), won: true, rr: 20, agent: 'sova', k: 20),
      _g(DateTime(2026, 11, 1, 20), won: false, rr: -15, agent: 'jett'),
      _g(DateTime(2026, 11, 1, 19), won: true, rr: 18, agent: 'sova'),
      _g(DateTime(2026, 10, 31, 23), won: false, rr: -20),
    ], now)!;
    expect(s.count, 3);
    expect(s.wins, 2);
    expect(s.losses, 1);
    expect(s.winRate, 67);
    expect(s.rrNet, 23);
    expect(s.kd, closeTo(40 / 30, 0.001));
    expect(s.avgAcs, 200);
    expect(s.topAgentId, 'sova');
    expect(s.partial, isFalse);
  });

  test('今天沒打時為 null；沒有 RR 資料時 RR 為 null', () {
    expect(todaySummary([_g(DateTime(2026, 10, 31, 23))], now), isNull);
    final s = todaySummary([_g(DateTime(2026, 11, 1, 1))], now)!;
    expect(s.rrNet, isNull);
    expect(s.winRate, isNull);
  });

  test('最後一場已載入的仍是今天且還有更多：標示不完整', () {
    final games = [
      _g(DateTime(2026, 11, 1, 21), won: true),
      _g(DateTime(2026, 11, 1, 20), won: true),
    ];
    expect(todaySummary(games, now, hasMore: true)!.partial, isTrue);
    expect(todaySummary(games, now)!.partial, isFalse);
  });
}
