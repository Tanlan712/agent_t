/// 對戰紀錄相關模型；資料只放在記憶體。
library;

import 'match_rounds.dart';

export 'match_rounds.dart';

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
  final String seasonId;
  final int durationMs;
  final bool isRanked;
  final String myTeamId;

  /// 這份摘要的主角（自己，或玩家頁查看的那位）；舊資料為空字串。
  final String focusPuuid;

  /// null 表示平手或無法判斷。
  final bool? won;
  final int myScore;
  final int enemyScore;
  final String myAgentId;
  final int kills;
  final int deaths;
  final int assists;
  final int acs;
  final int? rrChange;

  const MatchSummary({
    required this.matchId,
    required this.startTime,
    required this.queueId,
    required this.mapId,
    this.seasonId = '',
    required this.durationMs,
    required this.isRanked,
    required this.myTeamId,
    this.focusPuuid = '',
    this.won,
    required this.myScore,
    required this.enemyScore,
    required this.myAgentId,
    required this.kills,
    required this.deaths,
    required this.assists,
    this.acs = 0,
    this.rrChange,
  });
}

class MatchDetail {
  final MatchSummary summary;

  /// teamId → 該隊玩家，依 score 由高到低。
  final Map<String, List<PlayerLine>> teams;

  /// 每回合的勝方、結束方式與經濟（回合時間軸用）。
  final List<RoundInfo> rounds;

  /// 所有擊殺，依回合與時間排序（武器統計、殘局、熱區圖用）。
  final List<KillEvent> kills;

  const MatchDetail(
      {required this.summary,
      required this.teams,
      this.rounds = const [],
      this.kills = const []});

  /// puuid → teamId。
  Map<String, String> get teamOf => {
        for (final e in teams.entries)
          for (final p in e.value) p.puuid: e.key,
      };
}

/// 玩家頁的參數：要查看的玩家。
class PlayerRef {
  final String puuid;
  final String riotId;

  const PlayerRef({required this.puuid, required this.riotId});
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
/// 賽季（valorant-api `/v1/seasons`）：[name] 是「上層賽季 + 幕」，例如「V26 第六幕」。
class SeasonRef {
  final String name;
  final DateTime start;
  final DateTime end;

  /// 幕（Act）；上層賽季（Episode）為 false。
  final bool isAct;

  const SeasonRef(
      {required this.name,
      required this.start,
      required this.end,
      required this.isAct});

  factory SeasonRef.fromJson(Map<String, dynamic> json) => SeasonRef(
        name: json['name'] as String? ?? '',
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        isAct: json['isAct'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'isAct': isAct,
      };
}

/// 小地圖圖片與遊戲座標的換算係數（valorant-api `/v1/maps`）。
class MinimapRef {
  final String imageUrl;
  final double xMultiplier;
  final double yMultiplier;
  final double xScalarToAdd;
  final double yScalarToAdd;

  const MinimapRef({
    required this.imageUrl,
    required this.xMultiplier,
    required this.yMultiplier,
    required this.xScalarToAdd,
    required this.yScalarToAdd,
  });

  /// 遊戲座標 → 小地圖上的比例位置（0～1）；valorant-api 的公式是 x、y 互換。
  (double, double) project(MapPoint p) => (
        p.y * xMultiplier + xScalarToAdd,
        p.x * yMultiplier + yScalarToAdd,
      );

  factory MinimapRef.fromJson(Map<String, dynamic> json) => MinimapRef(
        imageUrl: json['imageUrl'] as String,
        xMultiplier: (json['xm'] as num).toDouble(),
        yMultiplier: (json['ym'] as num).toDouble(),
        xScalarToAdd: (json['xa'] as num).toDouble(),
        yScalarToAdd: (json['ya'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'imageUrl': imageUrl,
        'xm': xMultiplier,
        'ym': yMultiplier,
        'xa': xScalarToAdd,
        'ya': yScalarToAdd,
      };
}

class MatchReference {
  final Map<String, RefItem> agents;
  final Map<String, RefItem> maps;
  final Map<int, RefItem> tiers;

  /// 賽季 uuid（小寫）→ 名稱與起訖。
  final Map<String, SeasonRef> seasons;

  /// 武器 uuid（小寫）→ 名稱與圖示（武器統計、擅長槍枝用）。
  final Map<String, RefItem> weapons;

  /// mapUrl → 小地圖（熱區圖用）。
  final Map<String, MinimapRef> minimaps;

  const MatchReference(
      {required this.agents,
      required this.maps,
      required this.tiers,
      this.seasons = const {},
      this.weapons = const {},
      this.minimaps = const {}});

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
      seasons: {
        for (final e
            in (json['seasons'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: SeasonRef.fromJson(e.value as Map<String, dynamic>),
      },
      weapons: items(json['weapons'] ?? const <String, dynamic>{}),
      minimaps: {
        for (final e
            in (json['minimaps'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: MinimapRef.fromJson(e.value as Map<String, dynamic>),
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'agents': {for (final e in agents.entries) e.key: e.value.toJson()},
        'maps': {for (final e in maps.entries) e.key: e.value.toJson()},
        'tiers': {for (final e in tiers.entries) '${e.key}': e.value.toJson()},
        'seasons': {for (final e in seasons.entries) e.key: e.value.toJson()},
        'weapons': {for (final e in weapons.entries) e.key: e.value.toJson()},
        'minimaps': {for (final e in minimaps.entries) e.key: e.value.toJson()},
      };
}
