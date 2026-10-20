/// 登入後的 Riot 連線資訊；只存在記憶體，不寫入任何儲存。
class RiotSession {
  final String accessToken;
  final String idToken;
  final String entitlementsToken;
  final String puuid;
  final String gameName;
  final String tagLine;
  final String shard;
  final String clientVersion;
  final DateTime expiresAt;

  const RiotSession({
    required this.accessToken,
    required this.idToken,
    required this.entitlementsToken,
    required this.puuid,
    required this.gameName,
    required this.tagLine,
    required this.shard,
    required this.clientVersion,
    required this.expiresAt,
  });

  String get displayName => gameName.isEmpty ? '已登入玩家' : '$gameName#$tagLine';

  @override
  String toString() => 'RiotSession($displayName, $shard)';
}

class RiotWallet {
  final int vp;
  final int radianite;
  final int kingdom;

  const RiotWallet(
      {required this.vp, required this.radianite, required this.kingdom});
}
