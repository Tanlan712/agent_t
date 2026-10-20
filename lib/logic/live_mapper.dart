import '../models/live_models.dart';

const _partyStates = {
  'DEFAULT': '大廳',
  'MATCHMAKING': '配對中',
  'MATCHMADE_GAME_STARTING': '對戰即將開始',
  'CUSTOM_GAME_SETUP': '自訂對戰設定',
};

String partyStateLabel(String state) => _partyStates[state] ?? state;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// 解析 glz `parties/v1/parties/{id}`（欄位見 docs/api-fields.md）。
LiveParty mapParty(Map<String, dynamic> json, String myPuuid) {
  final members = <PartyMember>[];
  for (final m in (json['Members'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()) {
    final id = m['Subject'] as String? ?? '';
    final identity = m['PlayerIdentity'] as Map<String, dynamic>? ?? const {};
    final member = PartyMember(
      puuid: id,
      isMe: id == myPuuid,
      isOwner: m['IsOwner'] == true,
      isReady: m['IsReady'] == true,
      tier: _int(m['CompetitiveTier']),
      cardId: identity['PlayerCardID'] as String?,
      level: _int(identity['AccountLevel']),
      incognito: identity['Incognito'] == true,
      hideLevel: identity['HideAccountLevel'] == true,
    );
    member.isMe ? members.insert(0, member) : members.add(member);
  }
  // 沒有在排隊時，Riot 回傳 0001-01-01 這個預設值。
  final entry = DateTime.tryParse(json['QueueEntryTime'] as String? ?? '');
  return LiveParty(
    id: json['ID'] as String? ?? '',
    state: json['State'] as String? ?? '',
    queueId: (json['MatchmakingData'] as Map<String, dynamic>?)?['QueueID']
            as String? ??
        '',
    isOpen: json['Accessibility'] == 'OPEN',
    queueEntryTime: entry == null || entry.year < 2000 ? null : entry,
    members: members,
  );
}

/// 玩家卡小圖（valorant-api.com 的公開資料）。
String? playerCardUrl(String? cardId) => cardId == null || cardId.isEmpty
    ? null
    : 'https://media.valorant-api.com/playercards/$cardId/smallart.png';

/// 解析 glz `core-game/v1/matches/{id}`（欄位見 docs/api-fields.md）。
/// 依 AGENTS.md 只讀取需要的欄位，不碰 ConnectionDetails 與任何 token。
LiveMatch mapCoreGame(Map<String, dynamic> json, String myPuuid) {
  final players = <LivePlayer>[];
  var seasonId = '';
  for (final p in (json['Players'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()) {
    final id = p['Subject'] as String? ?? '';
    final identity = p['PlayerIdentity'] as Map<String, dynamic>? ?? const {};
    final badge = p['SeasonalBadgeInfo'] as Map<String, dynamic>? ?? const {};
    final season = badge['SeasonID'] as String? ?? '';
    if (seasonId.isEmpty || id == myPuuid) {
      if (season.isNotEmpty) seasonId = season;
    }
    players.add(LivePlayer(
      puuid: id,
      isMe: id == myPuuid,
      teamId: p['TeamID'] as String? ?? '',
      agentId: (p['CharacterID'] as String? ?? '').toLowerCase(),
      cardId: identity['PlayerCardID'] as String?,
      level: _int(identity['AccountLevel']),
      tier: _int(badge['Rank']),
      incognito: identity['Incognito'] == true,
      hideLevel: identity['HideAccountLevel'] == true,
      isCoach: p['IsCoach'] == true,
    ));
  }
  final me = players.where((p) => p.isMe).firstOrNull;
  return LiveMatch(
    matchId: json['MatchID'] as String? ?? '',
    state: json['State'] as String? ?? '',
    mapId: json['MapID'] as String? ?? '',
    queueId: (json['MatchmakingData'] as Map<String, dynamic>?)?['QueueID']
            as String? ??
        '',
    myTeamId: me?.teamId ?? '',
    seasonId: seasonId,
    players: players,
  );
}

AgentSelection _selection(Object? v) => switch (v) {
      'locked' => AgentSelection.locked,
      'selected' => AgentSelection.selected,
      _ => AgentSelection.none,
    };

/// 解析 glz `pregame/v1/matches/{id}`（欄位見 docs/api-fields.md）。
/// 不讀取 TeamMatchToken、VoiceSessionID、MUCName。
LivePregame mapPregame(Map<String, dynamic> json, String myPuuid) {
  final allies = <PregamePlayer>[];
  var seasonId = '';
  final team = json['AllyTeam'] as Map<String, dynamic>? ?? const {};
  for (final p in (team['Players'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()) {
    final id = p['Subject'] as String? ?? '';
    final identity = p['PlayerIdentity'] as Map<String, dynamic>? ?? const {};
    final badge = p['SeasonalBadgeInfo'] as Map<String, dynamic>? ?? const {};
    final season = badge['SeasonID'] as String? ?? '';
    if (season.isNotEmpty && (seasonId.isEmpty || id == myPuuid)) {
      seasonId = season;
    }
    final player = PregamePlayer(
      puuid: id,
      isMe: id == myPuuid,
      agentId: (p['CharacterID'] as String? ?? '').toLowerCase(),
      selection: _selection(p['CharacterSelectionState']),
      tier: _int(p['CompetitiveTier']),
      level: _int(identity['AccountLevel']),
    );
    player.isMe ? allies.insert(0, player) : allies.add(player);
  }
  return LivePregame(
    matchId: json['ID'] as String? ?? '',
    mapId: json['MapID'] as String? ?? '',
    queueId: json['QueueID'] as String? ?? '',
    seasonId: seasonId,
    // PhaseTimeRemainingNS 是奈秒。
    remaining:
        Duration(microseconds: _int(json['PhaseTimeRemainingNS']) ~/ 1000),
    enemySize: _int(json['EnemyTeamSize']),
    enemyLocked: _int(json['EnemyTeamLockCount']),
    allies: allies,
  );
}
