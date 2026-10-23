import '../models/match_models.dart';

/// 一位玩家的多殺與殘局（Ace、4K、3K、1vX 勝場）。
class PlayerHighlights {
  final int aces;
  final int fourKs;
  final int threeKs;

  /// 1vN 殘局贏下的次數（N → 次數）。
  final Map<int, int> clutches;

  const PlayerHighlights({
    this.aces = 0,
    this.fourKs = 0,
    this.threeKs = 0,
    this.clutches = const {},
  });

  int get clutchesWon => clutches.values.fold(0, (a, b) => a + b);

  bool get isEmpty =>
      aces == 0 && fourKs == 0 && threeKs == 0 && clutchesWon == 0;

  PlayerHighlights operator +(PlayerHighlights o) => PlayerHighlights(
        aces: aces + o.aces,
        fourKs: fourKs + o.fourKs,
        threeKs: threeKs + o.threeKs,
        clutches: {
          for (final k in {...clutches.keys, ...o.clutches.keys})
            k: (clutches[k] ?? 0) + (o.clutches[k] ?? 0),
        },
      );
}

/// 一場裡 [puuid] 的多殺與殘局。
/// 殘局：回合中第一次變成隊上只剩自己活著時，對面還活著 N 人，且這回合贏了，算一次 1vN。
PlayerHighlights matchHighlights(MatchDetail d, String puuid) {
  final teamOf = d.teamOf;
  final myTeam = teamOf[puuid];
  if (myTeam == null) return const PlayerHighlights();
  var aces = 0, fours = 0, threes = 0;
  final clutches = <int, int>{};
  final byRound = <int, List<KillEvent>>{};
  for (final k in d.kills) {
    (byRound[k.round] ??= []).add(k);
  }
  for (final round in d.rounds) {
    final kills = byRound[round.number] ?? const [];
    final mine = kills.where((k) => k.killer == puuid && k.victim != puuid);
    final n = mine.length;
    if (n >= 5) {
      aces++;
    } else if (n == 4) {
      fours++;
    } else if (n == 3) {
      threes++;
    }

    // 只有參與這回合的人才算活著（中途離開的不算）。
    final alive = <String>{
      for (final id in round.players.keys)
        if (teamOf.containsKey(id)) id,
    };
    if (alive.isEmpty) alive.addAll(teamOf.keys);
    int? clutchVs;
    bool soleSurvivor() =>
        alive.contains(puuid) &&
        alive.where((id) => teamOf[id] == myTeam).length == 1;
    if (soleSurvivor()) {
      clutchVs = alive.where((id) => teamOf[id] != myTeam).length;
    }
    for (final k in kills) {
      alive.remove(k.victim);
      if (clutchVs == null && soleSurvivor()) {
        clutchVs = alive.where((id) => teamOf[id] != myTeam).length;
      }
    }
    if (clutchVs != null && clutchVs > 0 && round.winningTeam == myTeam) {
      clutches[clutchVs] = (clutches[clutchVs] ?? 0) + 1;
    }
  }
  return PlayerHighlights(
      aces: aces, fourKs: fours, threeKs: threes, clutches: clutches);
}

/// 一把武器的跨場統計。
class WeaponStat {
  final String weapon;
  final int kills;

  /// 以這把為主武器的回合中的命中（match-details 的傷害沒有標武器，用每回合主武器推算）。
  final int headshots;
  final int shots;
  final int rounds;
  final int roundsWon;

  const WeaponStat({
    required this.weapon,
    this.kills = 0,
    this.headshots = 0,
    this.shots = 0,
    this.rounds = 0,
    this.roundsWon = 0,
  });

  double? get headshotPercent => shots == 0 ? null : headshots / shots * 100;
  double? get winRate => rounds == 0 ? null : roundsWon / rounds * 100;
}

/// [puuid] 在 [details] 裡每把武器的擊殺、爆頭率、勝率，依擊殺數由多到少。
/// 擊殺只算槍枝（不含技能、炸彈）；爆頭率與勝率依每回合的主武器推算。
List<WeaponStat> weaponStats(Iterable<MatchDetail> details, String puuid) {
  final kills = <String, int>{};
  final hs = <String, int>{};
  final shots = <String, int>{};
  final rounds = <String, int>{};
  final won = <String, int>{};
  for (final d in details) {
    final team = d.teamOf[puuid];
    for (final k in d.kills) {
      if (k.killer == puuid && k.victim != puuid && k.isWeapon) {
        kills[k.damageItem] = (kills[k.damageItem] ?? 0) + 1;
      }
    }
    for (final r in d.rounds) {
      final p = r.players[puuid];
      if (p == null || p.weapon.isEmpty) continue;
      hs[p.weapon] = (hs[p.weapon] ?? 0) + p.headshots;
      shots[p.weapon] = (shots[p.weapon] ?? 0) + p.shots;
      rounds[p.weapon] = (rounds[p.weapon] ?? 0) + 1;
      if (team != null && r.winningTeam == team) {
        won[p.weapon] = (won[p.weapon] ?? 0) + 1;
      }
    }
  }
  final ids = {...kills.keys, ...rounds.keys};
  final out = [
    for (final id in ids)
      WeaponStat(
        weapon: id,
        kills: kills[id] ?? 0,
        headshots: hs[id] ?? 0,
        shots: shots[id] ?? 0,
        rounds: rounds[id] ?? 0,
        roundsWon: won[id] ?? 0,
      ),
  ]..sort((a, b) => b.kills != a.kills
      ? b.kills.compareTo(a.kills)
      : b.rounds.compareTo(a.rounds));
  return out;
}

/// 一回合兩隊的裝備價值與花費總和（[myTeam] 在前）。
({int myLoadout, int enemyLoadout, int mySpent, int enemySpent}) teamEconomy(
    RoundInfo r, Map<String, String> teamOf, String myTeam) {
  var ml = 0, el = 0, ms = 0, es = 0;
  for (final e in r.players.entries) {
    final team = teamOf[e.key];
    if (team == null) continue;
    if (team == myTeam) {
      ml += e.value.loadout;
      ms += e.value.spent;
    } else {
      el += e.value.loadout;
      es += e.value.spent;
    }
  }
  return (myLoadout: ml, enemyLoadout: el, mySpent: ms, enemySpent: es);
}

/// 依隊伍裝備價值判斷這回合是什麼局（社群常用的門檻）。
String buyLabel(int teamLoadout, int players) {
  if (players <= 0) return '';
  final avg = teamLoadout / players;
  if (avg < 1000) return '經濟局';
  if (avg < 2500) return '半起';
  if (avg < 3900) return '半全起';
  return '全起';
}

/// 熱區圖的點：[kill] 為 true 是 [puuid] 擊殺對手的位置（對手倒下處），false 是自己陣亡的位置。
List<(MapPoint, bool kill)> heatPoints(MatchDetail d, String puuid) => [
      for (final k in d.kills)
        if (k.victimAt case final at?)
          if (k.killer == puuid && k.victim != puuid)
            (at, true)
          else if (k.victim == puuid)
            (at, false),
    ];
