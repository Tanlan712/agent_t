/// 對戰中遇過的玩家；存在本機（localStorage），方便之後查詢他的紀錄。
class SeenPlayer {
  final String puuid;
  final String riotId;
  final DateTime lastSeen;

  /// 最後一次遇到的場次。
  final String matchId;

  const SeenPlayer({
    required this.puuid,
    required this.riotId,
    required this.lastSeen,
    required this.matchId,
  });

  factory SeenPlayer.fromJson(Map<String, dynamic> json) => SeenPlayer(
        puuid: json['puuid'] as String,
        riotId: json['riotId'] as String,
        lastSeen: DateTime.parse(json['lastSeen'] as String),
        matchId: json['matchId'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'puuid': puuid,
        'riotId': riotId,
        'lastSeen': lastSeen.toIso8601String(),
        'matchId': matchId,
      };
}
