/// 對戰紀錄相關模型；資料只放在記憶體。
class MatchRef {
  final String matchId;
  final DateTime startTime;
  final String queueId;

  const MatchRef(
      {required this.matchId, required this.startTime, required this.queueId});
}

/// 全場 MVP、隊伍 MVP（另一隊的最佳玩家）或都不是。
enum MvpKind { none, match, team }

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

  /// deaths 為 0 時等於 kills。
  final double kd;

  /// 每回合平均傷害；沒有回合時為 0。
  final int adr;
  final int firstKills;
  final MvpKind mvp;

  /// 遊戲內的「表現分數」（scores.TempValueF）；Riot 沒有提供時為 null。
  final double? rating;

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
    this.kd = 0,
    this.adr = 0,
    this.firstKills = 0,
    this.mvp = MvpKind.none,
    this.rating,
  });

  PlayerLine copyWith({String? riotId, MvpKind? mvp}) => PlayerLine(
        puuid: puuid,
        riotId: riotId ?? this.riotId,
        teamId: teamId,
        partyId: partyId,
        agentId: agentId,
        tier: tier,
        accountLevel: accountLevel,
        kills: kills,
        deaths: deaths,
        assists: assists,
        score: score,
        acs: acs,
        headshotPercent: headshotPercent,
        isMe: isMe,
        kd: kd,
        adr: adr,
        firstKills: firstKills,
        mvp: mvp ?? this.mvp,
        rating: rating,
      );
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

/// 參考資料的一筆：顯示名稱與圖示。
class RefItem {
  final String name;
  final String? iconUrl;

  const RefItem({required this.name, this.iconUrl});

  factory RefItem.fromJson(Map<String, dynamic> json) => RefItem(
      name: json['name'] as String, iconUrl: json['iconUrl'] as String?);

  Map<String, dynamic> toJson() => {'name': name, 'iconUrl': iconUrl};
}

/// 特務（uuid 小寫）、地圖（mapUrl）、牌位（tier 編號）的對照表。
class MatchReference {
  final Map<String, RefItem> agents;
  final Map<String, RefItem> maps;
  final Map<int, RefItem> tiers;

  const MatchReference(
      {required this.agents, required this.maps, required this.tiers});

  factory MatchReference.fromJson(Map<String, dynamic> json) {
    Map<String, RefItem> items(Object? m) => {
          for (final e in (m as Map<String, dynamic>).entries)
            e.key: RefItem.fromJson(e.value as Map<String, dynamic>),
        };
    return MatchReference(
      agents: items(json['agents']),
      maps: items(json['maps']),
      tiers: {
        for (final e in items(json['tiers']).entries) int.parse(e.key): e.value,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'agents': {for (final e in agents.entries) e.key: e.value.toJson()},
        'maps': {for (final e in maps.entries) e.key: e.value.toJson()},
        'tiers': {for (final e in tiers.entries) '${e.key}': e.value.toJson()},
      };
}
