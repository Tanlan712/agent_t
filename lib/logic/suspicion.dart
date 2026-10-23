import '../providers/recent_form_loader.dart' show FormGame;

/// 小號／代打推測的門檻（使用者決定，AGENTS.md 第 2 節）。只是推測，可能誤判。
///
/// 每個訊號給 1～2 分：
/// - 疑似小號 = 「帳號淺」分數 ≥ [smurfMinAccount] 且「表現強」分數 ≥ [smurfMinSkill]，
///   兩邊都要有，避免把老玩家打得好、或新手打不好的帳號標出來。
/// - 疑似代打 = 最近幾場和之前比「換了一個人」的分數 ≥ [shiftMinScore]，
///   而且至少要有一項是表現變好（ACS 或 K/D），最近平均 ACS 也要夠高。
/// 小號分數 ≥ [highScore]、代打分數 ≥ [shiftHighScore] 時標成「高度疑似」。
class SuspicionRules {
  /// 至少要有幾場才判斷。
  final int minGames;

  /// 「最近」與「之前」各取幾場比較。
  final int window;

  // ── 帳號淺 ──
  /// 等級在這個值以下（且大於 0）給 2 分。
  final int newLevel;

  /// 等級在這個值以下（且大於 0）給 1 分。
  final int lowLevel;

  /// 本季勝場在這個值以下給 1 分。
  final int lowSeasonWins;

  /// 所有賽季的競技總場數在這個值以下給 2 分。
  final int newCareerGames;

  /// 所有賽季的競技總場數在這個值以下給 1 分。
  final int lowCareerGames;

  /// 歷史最高比目前牌位高出至少這麼多 tier（3 tier 是一個大段）給 2 分。
  final int peakGap;

  // ── 表現強（最近 [window] 場） ──
  final int strongAcs;
  final int goodAcs;
  final double strongKd;
  final double goodKd;
  final double strongHeadshot;

  /// 有勝負的場次至少 4 場且勝率達到這個值給 1 分。
  final double strongWinRate;

  /// 至少這個比例的場次 ACS ≥ [steadyAcs] 給 1 分（穩定碾壓）。
  final double steadyShare;
  final int steadyAcs;

  final int smurfMinAccount;
  final int smurfMinSkill;

  // ── 換人打（最近 vs 之前） ──
  final int shiftStrongAcs;
  final int shiftGoodAcs;
  final double shiftKd;
  final double shiftHeadshot;

  /// 兩段之間隔了至少這麼多天沒打給 1 分。
  final int restDays;

  /// 疑似代打時，最近平均 ACS 至少要多少。
  final int shiftMinRecentAcs;
  final int shiftMinScore;

  /// 小號分數達到這個值標成「高度疑似」。
  final int highScore;

  /// 代打分數（最高 6 分）達到這個值標成「高度疑似」。
  final int shiftHighScore;

  const SuspicionRules({
    this.minGames = 3,
    this.window = 5,
    this.newLevel = 20,
    this.lowLevel = 40,
    this.lowSeasonWins = 5,
    this.newCareerGames = 30,
    this.lowCareerGames = 80,
    this.peakGap = 6,
    this.strongAcs = 260,
    this.goodAcs = 230,
    this.strongKd = 1.5,
    this.goodKd = 1.25,
    this.strongHeadshot = 30,
    this.strongWinRate = 0.8,
    this.steadyShare = 0.8,
    this.steadyAcs = 220,
    this.smurfMinAccount = 2,
    this.smurfMinSkill = 3,
    this.shiftStrongAcs = 80,
    this.shiftGoodAcs = 50,
    this.shiftKd = 0.5,
    this.shiftHeadshot = 8,
    this.restDays = 30,
    this.shiftMinRecentAcs = 220,
    this.shiftMinScore = 3,
    this.highScore = 7,
    this.shiftHighScore = 5,
  });
}

enum SignalGroup { account, skill, shift }

/// 一個觸發的訊號：分數與給使用者看的原因（含數字）。
class SuspicionSignal {
  final SignalGroup group;
  final int points;
  final String text;

  const SuspicionSignal(this.group, this.points, this.text);
}

class Suspicion {
  /// 疑似小號：帳號淺，但最近表現很強。
  final bool smurf;

  /// 疑似代打：最近幾場的表現、爆頭率、特務池等和之前差很多。
  final bool shift;

  /// 所有觸發的訊號（包括沒有達到門檻的那一類，對話框裡一併列出）。
  final List<SuspicionSignal> signals;

  final SuspicionRules rules;

  const Suspicion(
      {required this.smurf,
      required this.shift,
      required this.signals,
      this.rules = const SuspicionRules()});

  bool get any => smurf || shift;

  int _sum(SignalGroup g) => signals
      .where((s) => s.group == g)
      .fold<int>(0, (sum, s) => sum + s.points);

  int get accountScore => _sum(SignalGroup.account);
  int get skillScore => _sum(SignalGroup.skill);
  int get shiftScore => _sum(SignalGroup.shift);

  int get smurfScore => smurf ? accountScore + skillScore : 0;

  bool get _smurfHigh => smurf && smurfScore >= rules.highScore;
  bool get _shiftHigh => shift && shiftScore >= rules.shiftHighScore;

  /// 任一類達到「高度疑似」。
  bool get high => _smurfHigh || _shiftHigh;

  /// 標籤文字，例如「疑似小號」或「高度疑似小號・疑似代打」。
  String get label => [
        if (smurf) '${_smurfHigh ? '高度' : ''}疑似小號',
        if (shift) '${_shiftHigh ? '高度' : ''}疑似代打',
      ].join('・');

  /// 觸發的原因與數字，給提示與對話框用；依類別分段。
  List<String> get reasons => [
        for (final s in signals) '${s.text}（+${s.points}）',
      ];

  String get detail {
    String section(String title, SignalGroup g, int score) {
      final lines = [
        for (final s in signals)
          if (s.group == g) '・${s.text}（+${s.points}）'
      ];
      return lines.isEmpty ? '' : '$title $score 分\n${lines.join('\n')}\n';
    }

    return [
      section('帳號淺', SignalGroup.account, accountScore),
      section('表現強', SignalGroup.skill, skillScore),
      section('前後落差', SignalGroup.shift, shiftScore),
    ].join();
  }
}

int _avg(Iterable<FormGame> g) =>
    (g.fold<int>(0, (s, x) => s + x.acs) / g.length).round();

double _kd(Iterable<FormGame> g) {
  final k = g.fold<int>(0, (s, x) => s + x.kills);
  final d = g.fold<int>(0, (s, x) => s + x.deaths);
  return k / (d == 0 ? 1 : d);
}

double? _hs(Iterable<FormGame> g) {
  final hs = [
    for (final x in g)
      if (x.headshotPercent case final h?) h
  ];
  return hs.isEmpty ? null : hs.reduce((a, b) => a + b) / hs.length;
}

String _f(double v) => v.toStringAsFixed(2);
String _pct(double v) => '${v.round()}%';

/// [recent] 依時間由新到舊；最多看前 2 × window 場。[level] 為 0 表示未知。
/// [currentTier]、[peakTier]、[careerGames] 來自 MMR，未知時給 0／null。
Suspicion assessAccount({
  required int level,
  required int? seasonWins,
  required List<FormGame> recent,
  required SuspicionRules rules,
  int currentTier = 0,
  int? peakTier,
  int? careerGames,
}) {
  final signals = <SuspicionSignal>[];
  void add(SignalGroup g, int points, String text) =>
      signals.add(SuspicionSignal(g, points, text));

  final latest = recent.take(rules.window).toList();
  final older = recent.skip(rules.window).take(rules.window).toList();
  if (latest.length < rules.minGames) {
    return Suspicion(smurf: false, shift: false, signals: [], rules: rules);
  }

  // ── 帳號淺 ──
  if (level > 0 && level <= rules.newLevel) {
    add(SignalGroup.account, 2, 'Lv $level（≤ ${rules.newLevel}）');
  } else if (level > 0 && level <= rules.lowLevel) {
    add(SignalGroup.account, 1, 'Lv $level（≤ ${rules.lowLevel}）');
  }
  if (seasonWins != null && seasonWins <= rules.lowSeasonWins) {
    add(SignalGroup.account, 1, '本季勝場 $seasonWins（≤ ${rules.lowSeasonWins}）');
  }
  if (careerGames != null) {
    if (careerGames <= rules.newCareerGames) {
      add(SignalGroup.account, 2,
          '競技總場數 $careerGames（≤ ${rules.newCareerGames}）');
    } else if (careerGames <= rules.lowCareerGames) {
      add(SignalGroup.account, 1,
          '競技總場數 $careerGames（≤ ${rules.lowCareerGames}）');
    }
  }
  if (peakTier != null &&
      currentTier > 0 &&
      peakTier - currentTier >= rules.peakGap) {
    add(SignalGroup.account, 2, '歷史最高比目前高 ${peakTier - currentTier} 階');
  }

  // ── 表現強 ──
  final n = latest.length;
  final acs = _avg(latest);
  if (acs >= rules.strongAcs) {
    add(SignalGroup.skill, 2, '最近 $n 場平均 ACS $acs（≥ ${rules.strongAcs}）');
  } else if (acs >= rules.goodAcs) {
    add(SignalGroup.skill, 1, '最近 $n 場平均 ACS $acs（≥ ${rules.goodAcs}）');
  }
  final hasKills = latest.any((g) => g.kills > 0 || g.deaths > 0);
  final kd = _kd(latest);
  if (hasKills && kd >= rules.strongKd) {
    add(SignalGroup.skill, 2, 'K/D ${_f(kd)}（≥ ${_f(rules.strongKd)}）');
  } else if (hasKills && kd >= rules.goodKd) {
    add(SignalGroup.skill, 1, 'K/D ${_f(kd)}（≥ ${_f(rules.goodKd)}）');
  }
  final hs = _hs(latest);
  if (hs != null && hs >= rules.strongHeadshot) {
    add(SignalGroup.skill, 1,
        '爆頭率 ${_pct(hs)}（≥ ${_pct(rules.strongHeadshot)}）');
  }
  final decided = latest.where((g) => g.won != null).toList();
  if (decided.length >= 4) {
    final wr = decided.where((g) => g.won == true).length / decided.length;
    if (wr >= rules.strongWinRate) {
      add(SignalGroup.skill, 1, '勝率 ${_pct(wr * 100)}（${decided.length} 場）');
    }
  }
  final steady = latest.where((g) => g.acs >= rules.steadyAcs).length;
  if (steady / n >= rules.steadyShare) {
    add(SignalGroup.skill, 1, '$n 場中 $steady 場 ACS ≥ ${rules.steadyAcs}');
  }

  // ── 前後落差（疑似換人打） ──
  var improved = false;
  if (older.length >= rules.minGames) {
    final before = _avg(older);
    final diff = acs - before;
    if (diff >= rules.shiftStrongAcs) {
      improved = true;
      add(SignalGroup.shift, 2, 'ACS $before → $acs（+$diff）');
    } else if (diff >= rules.shiftGoodAcs) {
      improved = true;
      add(SignalGroup.shift, 1, 'ACS $before → $acs（+$diff）');
    }
    final kdBefore = _kd(older);
    if (hasKills && kd - kdBefore >= rules.shiftKd) {
      improved = true;
      add(SignalGroup.shift, 1, 'K/D ${_f(kdBefore)} → ${_f(kd)}');
    }
    final hsBefore = _hs(older);
    if (hs != null &&
        hsBefore != null &&
        hs - hsBefore >= rules.shiftHeadshot) {
      add(SignalGroup.shift, 1, '爆頭率 ${_pct(hsBefore)} → ${_pct(hs)}');
    }
    final agentsNow = {for (final g in latest) g.agentId}..remove('');
    final agentsBefore = {for (final g in older) g.agentId}..remove('');
    if (agentsNow.isNotEmpty &&
        agentsBefore.isNotEmpty &&
        agentsNow.intersection(agentsBefore).isEmpty) {
      add(SignalGroup.shift, 1, '最近用的特務和之前完全不同');
    }
    final newestOld = older.first.startTime;
    final oldestNew = latest.last.startTime;
    if (newestOld != null && oldestNew != null) {
      final gap = oldestNew.difference(newestOld).inDays;
      if (gap >= rules.restDays) {
        add(SignalGroup.shift, 1, '中間 $gap 天沒打');
      }
    }
  }

  final s =
      Suspicion(smurf: false, shift: false, signals: signals, rules: rules);
  return Suspicion(
    smurf: s.accountScore >= rules.smurfMinAccount &&
        s.skillScore >= rules.smurfMinSkill,
    shift: improved &&
        acs >= rules.shiftMinRecentAcs &&
        s.shiftScore >= rules.shiftMinScore,
    signals: signals,
    rules: rules,
  );
}
