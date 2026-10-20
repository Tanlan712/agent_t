import '../providers/recent_form_loader.dart' show FormGame;

/// 小號／代打推測的門檻（使用者決定，AGENTS.md 第 2 節）。只是推測，可能誤判。
class SuspicionRules {
  /// 等級在這個值以下（且大於 0）視為新帳號。
  final int lowLevel;

  /// 本季勝場在這個值以下視為很少打。
  final int lowSeasonWins;

  /// 最近場次平均 ACS 達到這個值視為表現很好。
  final int smurfMinAcs;

  /// 至少要有幾場才判斷。
  final int minGames;

  /// 「最近」與「之前」各取幾場比較。
  final int window;

  /// 最近比之前平均 ACS 高出多少視為表現突變。
  final int shiftMinDiff;

  /// 表現突變時，最近平均 ACS 至少要多少。
  final int shiftMinRecentAcs;

  const SuspicionRules({
    this.lowLevel = 30,
    this.lowSeasonWins = 5,
    this.smurfMinAcs = 260,
    this.minGames = 3,
    this.window = 5,
    this.shiftMinDiff = 100,
    this.shiftMinRecentAcs = 250,
  });
}

class Suspicion {
  /// 疑似小號：新帳號或很少打，但最近表現很好。
  final bool smurf;

  /// 表現突變（疑似代打）：最近幾場比之前高很多。
  final bool shift;

  /// 觸發的原因與數字，給滑鼠提示用。
  final List<String> reasons;

  const Suspicion(
      {required this.smurf, required this.shift, required this.reasons});

  bool get any => smurf || shift;
}

int _avg(Iterable<FormGame> g) =>
    (g.fold<int>(0, (s, x) => s + x.acs) / g.length).round();

/// [recent] 依時間由新到舊；最多看前 2 × window 場。[level] 為 0 表示未知。
Suspicion assessAccount({
  required int level,
  required int? seasonWins,
  required List<FormGame> recent,
  required SuspicionRules rules,
}) {
  final reasons = <String>[];
  final latest = recent.take(rules.window).toList();
  final older = recent.skip(rules.window).take(rules.window).toList();

  var smurf = false;
  if (latest.length >= rules.minGames) {
    final avg = _avg(latest);
    final lowLevel = level > 0 && level <= rules.lowLevel;
    final fewWins = seasonWins != null && seasonWins <= rules.lowSeasonWins;
    if ((lowLevel || fewWins) && avg >= rules.smurfMinAcs) {
      smurf = true;
      if (lowLevel) reasons.add('Lv $level（≤ ${rules.lowLevel}）');
      if (fewWins) reasons.add('本季勝場 $seasonWins（≤ ${rules.lowSeasonWins}）');
      reasons.add('最近 ${latest.length} 場平均 ACS $avg（≥ ${rules.smurfMinAcs}）');
    }
  }

  var shift = false;
  if (latest.length >= rules.minGames && older.length >= rules.minGames) {
    final now = _avg(latest);
    final before = _avg(older);
    if (now - before >= rules.shiftMinDiff && now >= rules.shiftMinRecentAcs) {
      shift = true;
      reasons.add('最近 ${latest.length} 場平均 ACS $now，'
          '之前 ${older.length} 場 $before（差 ${now - before}）');
    }
  }
  return Suspicion(smurf: smurf, shift: shift, reasons: reasons);
}
