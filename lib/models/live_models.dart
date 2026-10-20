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

  const LiveParty({
    required this.id,
    required this.state,
    required this.queueId,
    required this.isOpen,
    required this.queueEntryTime,
    required this.members,
  });
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
