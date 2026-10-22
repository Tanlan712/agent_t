/// 即時對局（隊伍階段）的模型；資料只放在記憶體。
class PartyMember {
  final String puuid;
  final bool isMe;
  final bool isOwner;
  final bool isReady;

  /// 隊伍資料裡的牌位；他人要確認公開才可以顯示。
  final int tier;
  final String? cardId;
  final int level;

  /// 成員在遊戲中隱藏名稱：不查名稱、不顯示、不能點進玩家頁。
  final bool incognito;

  /// 成員隱藏等級：不顯示等級。
  final bool hideLevel;

  const PartyMember({
    required this.puuid,
    required this.isMe,
    required this.isOwner,
    required this.isReady,
    required this.tier,
    required this.cardId,
    required this.level,
    required this.incognito,
    required this.hideLevel,
  });
}

class LiveParty {
  final String id;
  final String state;
  final String queueId;
  final bool isOpen;

  /// 開始排隊的時間；沒有在排隊時為 null。
  final DateTime? queueEntryTime;

  /// 自己排第一，其餘照隊伍資料的順序。
  final List<PartyMember> members;

  /// 隊伍目前可以選的模式（`EligibleQueues`），遠端變更模式用。
  final List<String> eligibleQueues;

  /// 自訂對戰設定（`CustomGameData.Settings`：Map、Mode、UseBots、GamePod、GameRules），
  /// 遠端變更時原樣帶回其他欄位；不是自訂對戰時為 null。
  final Map<String, dynamic>? customSettings;

  /// 自訂對戰的分隊：puuid → `TeamOne`／`TeamTwo`／`TeamSpectate`。
  final Map<String, String> customTeams;

  const LiveParty({
    required this.id,
    required this.state,
    required this.queueId,
    required this.isOpen,
    required this.queueEntryTime,
    required this.members,
    this.eligibleQueues = const [],
    this.customSettings,
    this.customTeams = const {},
  });

  bool get isCustomGame => state == 'CUSTOM_GAME_SETUP';

  /// 自己是不是隊長。
  bool get iAmOwner => members.any((m) => m.isMe && m.isOwner);

  PartyMember? get me => members.where((m) => m.isMe).firstOrNull;
}

/// 對局中（core-game）的一位玩家。
class LivePlayer {
  final String puuid;
  final bool isMe;
  final String teamId;
  final String agentId;
  final String? cardId;
  final int level;

  /// 本季牌位（SeasonalBadgeInfo.Rank）。
  final int tier;
  final bool incognito;
  final bool hideLevel;
  final bool isCoach;

  /// 本季勝場（SeasonalBadgeInfo.NumberOfWins）；沒有資料時為 null。
  final int? seasonWins;

  const LivePlayer({
    required this.puuid,
    required this.isMe,
    required this.teamId,
    required this.agentId,
    required this.cardId,
    required this.level,
    required this.tier,
    required this.incognito,
    required this.hideLevel,
    required this.isCoach,
    this.seasonWins,
  });
}

/// 對局中（core-game）的場次。依 AGENTS.md，不保存連線資訊與任何 token。
class LiveMatch {
  final String matchId;
  final String state;
  final String mapId;
  final String queueId;
  final String myTeamId;

  /// 本季 ID（SeasonalBadgeInfo.SeasonID）；Rank 為 0 時用來查這季牌位。
  final String seasonId;
  final List<LivePlayer> players;

  const LiveMatch({
    required this.matchId,
    required this.state,
    required this.mapId,
    required this.queueId,
    required this.myTeamId,
    this.seasonId = '',
    required this.players,
  });

  /// 我方在前，其餘依名稱排序。
  List<String> get teamIds {
    final ids = {for (final p in players) p.teamId}.toList()
      ..sort(
          (a, b) => a == myTeamId ? -1 : (b == myTeamId ? 1 : a.compareTo(b)));
    return ids;
  }

  /// 該隊玩家，自己排第一。
  List<LivePlayer> team(String teamId) {
    final list = players.where((p) => p.teamId == teamId).toList();
    final me = list.where((p) => p.isMe).toList();
    return [...me, ...list.where((p) => !p.isMe)];
  }
}

/// 選角狀態：尚未選、已選（未鎖定）、已鎖定。
enum AgentSelection { none, selected, locked }

/// 選角中的我方一位成員。
class PregamePlayer {
  final String puuid;
  final bool isMe;

  /// 還沒選特務時是空字串。
  final String agentId;
  final AgentSelection selection;
  final int tier;
  final int level;

  /// 本季勝場；沒有資料時為 null。
  final int? seasonWins;

  const PregamePlayer({
    required this.puuid,
    required this.isMe,
    required this.agentId,
    required this.selection,
    required this.tier,
    required this.level,
    this.seasonWins,
  });
}

/// 選角中（pregame）的場次。依 AGENTS.md，不保存 token 與語音／聊天 ID。
/// 選角時 Riot 不提供對手資料，只有人數與已鎖定人數。
class LivePregame {
  final String matchId;
  final String mapId;
  final String queueId;
  final String seasonId;

  /// 讀取當下的剩餘時間。
  final Duration remaining;
  final int enemySize;
  final int enemyLocked;

  /// 自己排第一。
  final List<PregamePlayer> allies;

  const LivePregame({
    required this.matchId,
    required this.mapId,
    required this.queueId,
    required this.seasonId,
    required this.remaining,
    required this.enemySize,
    required this.enemyLocked,
    required this.allies,
  });
}
