/// 登入後的 Riot 連線資訊；由 SessionStorage 保存到過期為止（AGENTS.md 第 4 節）。
class RiotSession {
  final String accessToken;
  final String idToken;
  final String entitlementsToken;
  final String puuid;
  final String gameName;
  final String tagLine;

  /// riot-geo 的 `affinities.live`，其實是**區域**（ap、na、latam、br、eu、kr）；
  /// pd 主機要用 [pdShard]，glz 主機是 `glz-{區域}-1.{pdShard}`。
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

  /// pd／glz 主機的 shard：拉丁美洲與巴西的區域共用 na shard，其他區域同名。
  String get pdShard => shard == 'latam' || shard == 'br' ? 'na' : shard;

  /// pd 端點主機。
  String get pdHost => 'pd.$pdShard.a.pvp.net';

  /// glz（即時對局、隊伍）端點主機。
  String get glzHost => 'glz-$shard-1.$pdShard.a.pvp.net';

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
