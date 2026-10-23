import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/match_stats.dart';
import 'package:agent_t/models/match_models.dart';

MatchSummary game(
  String id, {
  int day = 1,
  String queue = 'competitive',
  String map = 'ascent',
  String agent = 'jett',
  bool? won = true,
  int k = 10,
  int d = 10,
  int acs = 200,
  int? rr,
}) =>
    MatchSummary(
      matchId: id,
      startTime: DateTime(2026, 10, day),
      queueId: queue,
      mapId: map,
      durationMs: 1,
      isRanked: queue == 'competitive',
      myTeamId: 'Blue',
      won: won,
      myScore: 13,
      enemyScore: 7,
      myAgentId: agent,
      kills: k,
      deaths: d,
      assists: 0,
      acs: acs,
      rrChange: rr,
    );

void main() {
  // 新到舊（與對戰紀錄列表相同順序）。
  final games = [
    game('g4', day: 4, rr: 18, acs: 300, k: 20, d: 10),
    game('g3', day: 3, queue: 'unrated', agent: 'sage', won: false, acs: 150),
    game('g2', day: 2, map: 'bind', rr: -15, won: false, acs: 180),
    game('g1', day: 1, queue: 'deathmatch', won: null, acs: 90),
  ];

  group('篩選', () {
    test('模式：競技／一般／其他', () {
      List<String> ids(MatchFilter f) =>
          [for (final g in games.where(f.accepts)) g.matchId];
      expect(ids(const MatchFilter()), ['g4', 'g3', 'g2', 'g1']);
      expect(
          ids(const MatchFilter(mode: ModeFilter.competitive)), ['g4', 'g2']);
      expect(ids(const MatchFilter(mode: ModeFilter.unrated)), ['g3']);
      expect(ids(const MatchFilter(mode: ModeFilter.other)), ['g1']);
    });

    test('特務、地圖、勝負可以一起用', () {
      List<String> ids(MatchFilter f) =>
          [for (final g in games.where(f.accepts)) g.matchId];
      expect(ids(const MatchFilter(agentId: 'sage')), ['g3']);
      expect(ids(const MatchFilter(mapId: 'bind')), ['g2']);
      expect(ids(const MatchFilter(result: ResultFilter.win)), ['g4']);
      expect(ids(const MatchFilter(result: ResultFilter.loss)), ['g3', 'g2']);
      expect(
          ids(const MatchFilter(
              mode: ModeFilter.competitive, result: ResultFilter.loss)),
          ['g2']);
    });
  });

  test('RR 走勢：由舊到新累計，只算有 RR 變化的場次', () {
    expect(rrSeries(games), [-15, 3]);
    expect(rrSeries(const []), isEmpty);
  });

  test('ACS 走勢：由舊到新', () {
    expect(acsSeries(games), [90, 180, 150, 300]);
  });

  group('依特務／地圖分組', () {
    test('場數、勝率（平手不算）、平均 K/D、平均 ACS；場數多的在前', () {
      final byAgent = statsBy(games, (g) => g.myAgentId);
      expect(byAgent.map((s) => s.key), ['jett', 'sage']);
      final jett = byAgent.first;
      expect(jett.games, 3);
      expect(jett.winRate, closeTo(0.5, 1e-9));
      expect(jett.avgKd, closeTo(40 / 30, 1e-9));
      expect(jett.avgAcs, closeTo((300 + 180 + 90) / 3, 1e-9));
      expect(byAgent.last.winRate, 0);
    });

    test('同場數時勝率高的在前；只有平手時勝率為 null', () {
      final byMap = statsBy([
        game('a', map: 'bind', won: false),
        game('b', map: 'ascent', won: true),
        game('c', map: 'haven', won: null),
      ], (g) => g.mapId);
      expect(byMap.map((s) => s.key), ['ascent', 'bind', 'haven']);
      expect(byMap.last.winRate, isNull);
    });
  });
}
