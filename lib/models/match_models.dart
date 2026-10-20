/// 對戰紀錄相關模型；資料只放在記憶體。
class MatchRef {
  final String matchId;
  final DateTime startTime;
  final String queueId;

  const MatchRef(
      {required this.matchId, required this.startTime, required this.queueId});
}

class PlayerLine {
  final String puuid;

  /// `名稱#Tag`；名稱為空時為「未知玩家」。
  final String riotId;
  final String teamId;
  final String partyId;
  final String agentId;
  final int tier;
  final int accountLevel;
  final int kills;
  final int deaths;
  final int assists;
  final int score;
  final int acs;
  final double? headshotPercent;
  final bool isMe;

  const PlayerLine({
    required this.puuid,
    required this.riotId,
    required this.teamId,
    required this.partyId,
    required this.agentId,
    required this.tier,
    required this.accountLevel,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.score,
    required this.acs,
    this.headshotPercent,
    required this.isMe,
  });
}

class MatchSummary {
  final String matchId;
  final DateTime startTime;
  final String queueId;
  final String mapId;
  final int durationMs;
  final bool isRanked;
  final String myTeamId;

  /// null 表示平手或無法判斷。
  final bool? won;
  final int myScore;
  final int enemyScore;
  final String myAgentId;
  final int kills;
  final int deaths;
  final int assists;
  final int? rrChange;

  const MatchSummary({
    required this.matchId,
    required this.startTime,
    required this.queueId,
    required this.mapId,
    required this.durationMs,
    required this.isRanked,
    required this.myTeamId,
    this.won,
    required this.myScore,
    required this.enemyScore,
    required this.myAgentId,
    required this.kills,
    required this.deaths,
    required this.assists,
    this.rrChange,
  });
}

class MatchDetail {
  final MatchSummary summary;

  /// teamId → 該隊玩家，依 score 由高到低。
  final Map<String, List<PlayerLine>> teams;

  const MatchDetail({required this.summary, required this.teams});
}

class RankInfo {
  final int tier;
  final int rr;

  const RankInfo({required this.tier, required this.rr});
}
