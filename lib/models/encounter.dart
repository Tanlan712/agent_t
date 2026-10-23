/// 和自己同場打過的一場（使用者決定 2026-10-23，AGENTS.md 第 2 節）。
/// 只記場次與勝負，不記對方名稱（避免留下改名前的 Riot ID）。
class Encounter {
  final String matchId;
  final DateTime startTime;
  final String mapId;
  final String queueId;

  /// 同一隊（隊友）；false 表示對手。
  final bool ally;

  /// 以自己的角度：贏、輸；null 表示平手或無法判斷。
  final bool? won;

  const Encounter({
    required this.matchId,
    required this.startTime,
    required this.mapId,
    required this.queueId,
    required this.ally,
    required this.won,
  });

  factory Encounter.fromJson(Map<String, dynamic> json) => Encounter(
        matchId: json['m'] as String,
        startTime: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
        mapId: json['map'] as String? ?? '',
        queueId: json['q'] as String? ?? '',
        ally: json['a'] == true,
        won: json['w'] as bool?,
      );

  /// 欄位名稱縮短：localStorage 空間有限。
  Map<String, dynamic> toJson() => {
        'm': matchId,
        't': startTime.millisecondsSinceEpoch,
        'map': mapId,
        'q': queueId,
        'a': ally,
        'w': won,
      };
}
