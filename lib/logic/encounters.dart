import '../models/encounter.dart';
import '../models/match_models.dart';

/// [d] 裡和自己（isMe）同場的其他玩家；自己不在這場時回傳空的。
/// 勝負一律換算成自己的角度（玩家頁查看他人場次時，摘要是以對方為主）。
Map<String, Encounter> encountersIn(MatchDetail d) {
  final lines = d.teams.values.expand((t) => t).toList();
  final me = lines.where((l) => l.isMe).firstOrNull;
  if (me == null || d.summary.matchId.isEmpty) return const {};
  final s = d.summary;
  final bool? won;
  if (s.myTeamId == me.teamId) {
    won = s.won;
  } else if (d.teams.length == 2 && s.won != null) {
    won = !s.won!;
  } else {
    won = null;
  }
  return {
    for (final l in lines)
      if (!l.isMe)
        l.puuid: Encounter(
          matchId: s.matchId,
          startTime: s.startTime,
          mapId: s.mapId,
          queueId: s.queueId,
          ally: l.teamId == me.teamId,
          won: won,
        ),
  };
}

/// 遇過的次數與身為隊友／對手時的勝負。
class EncounterSummary {
  final int allyGames;
  final int allyWins;
  final int allyLosses;
  final int enemyGames;
  final int enemyWins;
  final int enemyLosses;

  const EncounterSummary({
    required this.allyGames,
    required this.allyWins,
    required this.allyLosses,
    required this.enemyGames,
    required this.enemyWins,
    required this.enemyLosses,
  });

  factory EncounterSummary.of(List<Encounter> list) {
    int count(bool ally, bool? won) => list
        .where((e) => e.ally == ally && (won == null || e.won == won))
        .length;
    return EncounterSummary(
      allyGames: count(true, null),
      allyWins: count(true, true),
      allyLosses: count(true, false),
      enemyGames: count(false, null),
      enemyWins: count(false, true),
      enemyLosses: count(false, false),
    );
  }

  int get total => allyGames + enemyGames;
}
