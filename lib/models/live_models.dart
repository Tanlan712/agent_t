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
