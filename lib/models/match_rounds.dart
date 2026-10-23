/// 單場的回合與擊殺資料（match-details 的 roundResults），只放在記憶體。
library;

/// 地圖上的座標（遊戲座標，轉到小地圖要用 valorant-api 的係數）。
class MapPoint {
  final double x;
  final double y;

  const MapPoint(this.x, this.y);
}

class KillEvent {
  /// 第幾回合（0 起算）。
  final int round;

  /// 回合開始後幾毫秒。
  final int roundTime;
  final String killer;
  final String victim;

  /// `Weapon`、`Ability`、`Bomb`、`Melee`…
  final String damageType;

  /// 武器 uuid（小寫）；技能時是 `Ability1` 之類。
  final String damageItem;
  final MapPoint? victimAt;
  final MapPoint? killerAt;

  const KillEvent({
    required this.round,
    required this.roundTime,
    required this.killer,
    required this.victim,
    this.damageType = '',
    this.damageItem = '',
    this.victimAt,
    this.killerAt,
  });

  bool get isWeapon => damageType == 'Weapon' && damageItem.isNotEmpty;
}

/// 一位玩家在某一回合的經濟與命中。
class RoundPlayer {
  /// 裝備價值（回合開始時身上的槍與護甲）。
  final int loadout;
  final int spent;
  final int remaining;

  /// 這回合的主武器 uuid（小寫）；沒有時為空字串。
  final String weapon;
  final String armor;
  final int headshots;
  final int bodyshots;
  final int legshots;
  final int damage;
  final int kills;

  const RoundPlayer({
    this.loadout = 0,
    this.spent = 0,
    this.remaining = 0,
    this.weapon = '',
    this.armor = '',
    this.headshots = 0,
    this.bodyshots = 0,
    this.legshots = 0,
    this.damage = 0,
    this.kills = 0,
  });

  int get shots => headshots + bodyshots + legshots;
}

/// 回合的結束方式。
enum RoundEnd { elimination, detonate, defuse, timer, surrender, unknown }

class RoundInfo {
  /// 0 起算。
  final int number;
  final String winningTeam;
  final RoundEnd end;
  final String? planter;
  final String? defuser;
  final MapPoint? plantAt;

  /// puuid → 這回合的經濟與命中。
  final Map<String, RoundPlayer> players;

  const RoundInfo({
    required this.number,
    required this.winningTeam,
    this.end = RoundEnd.unknown,
    this.planter,
    this.defuser,
    this.plantAt,
    this.players = const {},
  });
}
