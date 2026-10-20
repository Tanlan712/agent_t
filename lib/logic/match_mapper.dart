import '../models/match_models.dart';

const _queueNames = {
  'competitive': '競技',
  'unrated': '一般',
  'swiftplay': '超速衝點',
  'spikerush': '輻能搶攻',
  'deathmatch': '死鬥',
  'ggteam': '軍備升級',
  'hurm': '團隊死鬥',
  'premier': 'Premier',
};

/// match-details 沒有名稱、name-service 也查不到時顯示的名稱。
const unknownPlayerName = '未知玩家';

String queueName(String queueId) => _queueNames[queueId] ?? queueId;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

List<MatchRef> mapHistory(Map<String, dynamic> json) => [
      for (final h in (json['History'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>())
        MatchRef(
          matchId: h['MatchID'] as String,
          startTime:
              DateTime.fromMillisecondsSinceEpoch(_int(h['GameStartTime'])),
          queueId: h['QueueID'] as String? ?? '',
        ),
    ];

/// 每場競技的 RR 變化。實測 RankedRatingEarned 常為 0，所以改用前後牌位計算：
/// (TierAfter − TierBefore) × 100 + (RRAfter − RRBefore)，升降牌也正確。
/// 非競技場次與定級中（TierBeforeUpdate 為 0）不列入。
Map<String, int> rrByMatch(Map<String, dynamic> competitiveUpdates) => {
      for (final m
          in (competitiveUpdates['Matches'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>())
        if (m['QueueID'] == 'competitive' && _int(m['TierBeforeUpdate']) > 0)
          m['MatchID'] as String:
              (_int(m['TierAfterUpdate']) - _int(m['TierBeforeUpdate'])) * 100 +
                  _int(m['RankedRatingAfterUpdate']) -
                  _int(m['RankedRatingBeforeUpdate']),
    };

RankInfo? mapRank(Map<String, dynamic> mmr) {
  final latest = mmr['LatestCompetitiveUpdate'] as Map<String, dynamic>?;
  if (latest == null) return null;
  return RankInfo(
    tier: _int(latest['TierAfterUpdate']),
    rr: _int(latest['RankedRatingAfterUpdate']),
  );
}

/// 每位玩家在所有回合的命中部位加總：(head, body, leg)。
Map<String, (int, int, int)> _hits(Map<String, dynamic> json) {
  final totals = <String, (int, int, int)>{};
  for (final round in (json['roundResults'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()) {
    for (final ps in (round['playerStats'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()) {
      final id = ps['subject'] as String?;
      if (id == null) continue;
      var (h, b, l) = totals[id] ?? (0, 0, 0);
      for (final d in (ps['damage'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()) {
        h += _int(d['headshots']);
        b += _int(d['bodyshots']);
        l += _int(d['legshots']);
      }
      totals[id] = (h, b, l);
    }
  }
  return totals;
}

/// 比分：優先用 teams[].roundsWon，沒有時從 roundResults[].winningTeam 計數。
Map<String, int> _roundsWon(Map<String, dynamic> json) {
  final teams = (json['teams'] as List<dynamic>?)?.cast<Map<String, dynamic>>();
  if (teams != null && teams.isNotEmpty) {
    return {for (final t in teams) t['teamId'] as String: _int(t['roundsWon'])};
  }
  final counts = <String, int>{};
  for (final r in (json['roundResults'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()) {
    final w = r['winningTeam'] as String?;
    if (w != null) counts[w] = (counts[w] ?? 0) + 1;
  }
  return counts;
}

MatchDetail mapMatchDetail(Map<String, dynamic> json, String myPuuid,
    {int? rrChange}) {
  final info = json['matchInfo'] as Map<String, dynamic>? ?? const {};
  final hits = _hits(json);

  final lines = <PlayerLine>[];
  for (final p in (json['players'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()) {
    if (p['isObserver'] == true) continue;
    final id = p['subject'] as String;
    final stats = p['stats'] as Map<String, dynamic>? ?? const {};
    final rounds = _int(stats['roundsPlayed']);
    final score = _int(stats['score']);
    final name = p['gameName'] as String? ?? '';
    final (h, b, l) = hits[id] ?? (0, 0, 0);
    final shots = h + b + l;
    lines.add(PlayerLine(
      puuid: id,
      riotId: name.isEmpty ? unknownPlayerName : '$name#${p['tagLine'] ?? ''}',
      teamId: p['teamId'] as String? ?? '',
      partyId: p['partyId'] as String? ?? '',
      agentId: p['characterId'] as String? ?? '',
      tier: _int(p['competitiveTier']),
      accountLevel: _int(p['accountLevel']),
      kills: _int(stats['kills']),
      deaths: _int(stats['deaths']),
      assists: _int(stats['assists']),
      score: score,
      acs: rounds == 0 ? 0 : (score / rounds).round(),
      headshotPercent: shots == 0 ? null : h / shots * 100,
      isMe: id == myPuuid,
    ));
  }

  final teams = <String, List<PlayerLine>>{};
  for (final l in lines) {
    (teams[l.teamId] ??= []).add(l);
  }
  for (final t in teams.values) {
    t.sort((a, b) => b.score.compareTo(a.score));
  }

  final me = lines.where((l) => l.isMe).firstOrNull;
  final myTeam = me?.teamId ?? '';
  final won = _roundsWon(json);
  final myScore = won[myTeam] ?? 0;
  final enemyScore = won.entries
      .where((e) => e.key != myTeam)
      .fold<int>(0, (m, e) => e.value > m ? e.value : m);

  return MatchDetail(
    summary: MatchSummary(
      matchId: info['matchId'] as String? ?? '',
      startTime:
          DateTime.fromMillisecondsSinceEpoch(_int(info['gameStartMillis'])),
      queueId: info['queueID'] as String? ?? '',
      mapId: info['mapId'] as String? ?? '',
      durationMs: _int(info['gameLengthMillis']),
      isRanked: info['isRanked'] == true,
      myTeamId: myTeam,
      won: _teamWon(json, myTeam) ??
          (myScore == enemyScore ? null : myScore > enemyScore),
      myScore: myScore,
      enemyScore: enemyScore,
      myAgentId: me?.agentId ?? '',
      kills: me?.kills ?? 0,
      deaths: me?.deaths ?? 0,
      assists: me?.assists ?? 0,
      rrChange: rrChange,
    ),
    teams: teams,
  );
}

/// teams[] 有 won 旗標時以它為準（投降等提早結束的場次回合數不代表勝負）。
bool? _teamWon(Map<String, dynamic> json, String teamId) {
  for (final t in (json['teams'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()) {
    if (t['teamId'] == teamId && t['won'] is bool) return t['won'] as bool;
  }
  return null;
}

/// 用 name-service 的結果補上 [names] 裡有的玩家名稱；其他玩家維持原樣。
MatchDetail applyNames(MatchDetail d, Map<String, String> names) {
  if (names.isEmpty) return d;
  PlayerLine named(PlayerLine p) {
    final n = names[p.puuid];
    if (n == null) return p;
    return PlayerLine(
      puuid: p.puuid,
      riotId: n,
      teamId: p.teamId,
      partyId: p.partyId,
      agentId: p.agentId,
      tier: p.tier,
      accountLevel: p.accountLevel,
      kills: p.kills,
      deaths: p.deaths,
      assists: p.assists,
      score: p.score,
      acs: p.acs,
      headshotPercent: p.headshotPercent,
      isMe: p.isMe,
    );
  }

  return MatchDetail(
    summary: d.summary,
    teams: {
      for (final e in d.teams.entries) e.key: e.value.map(named).toList()
    },
  );
}
