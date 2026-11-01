import '../models/match_models.dart';

/// 今日小結（規格 docs/superpowers/specs/2026-11-01-five-features-design.md §3）：
/// 只用對戰紀錄頁已讀到的自己的場次計算，不另外送請求。
class TodaySummary {
  /// 今天的場次，由新到舊。
  final List<MatchSummary> games;

  /// 還有更早的場次沒載入，而且最後一場已載入的仍是今天（數字可能不完整）。
  final bool partial;

  const TodaySummary({required this.games, this.partial = false});

  int get count => games.length;
  int get wins => games.where((g) => g.won == true).length;
  int get losses => games.where((g) => g.won == false).length;
  int get draws => count - wins - losses;

  /// 勝率（0–100，四捨五入）；有勝負的場次為 0 時為 null。
  int? get winRate {
    final decided = wins + losses;
    return decided == 0 ? null : (wins * 100 / decided).round();
  }

  /// 競技的 RR 淨變化；今天沒有讀到 RR 的競技場次時為 null。
  int? get rrNet {
    final changes = [
      for (final g in games)
        if (g.rrChange case final c?) c
    ];
    return changes.isEmpty ? null : changes.reduce((a, b) => a + b);
  }

  int get kills => games.fold(0, (s, g) => s + g.kills);
  int get deaths => games.fold(0, (s, g) => s + g.deaths);
  int get assists => games.fold(0, (s, g) => s + g.assists);

  /// K/D（兩位小數）；沒有死亡時等於擊殺數。
  double get kd => deaths == 0 ? kills.toDouble() : kills / deaths;

  int get avgAcs {
    final withAcs = games.where((g) => g.acs > 0).toList();
    if (withAcs.isEmpty) return 0;
    return (withAcs.fold(0, (s, g) => s + g.acs) / withAcs.length).round();
  }

  /// 今天最常用的特務（同場數時取較晚玩的）。
  String? get topAgentId {
    final n = <String, int>{};
    for (final g in games.reversed) {
      if (g.myAgentId.isEmpty) continue;
      n[g.myAgentId] = (n[g.myAgentId] ?? 0) + 1;
    }
    String? best;
    for (final e in n.entries) {
      if (best == null || e.value >= n[best]!) best = e.key;
    }
    return best;
  }
}

bool sameLocalDay(DateTime a, DateTime b) {
  final x = a.toLocal(), y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// 從已載入的場次（由新到舊）挑出今天（本地日曆日）的場次；今天沒打時回傳 null。
TodaySummary? todaySummary(List<MatchSummary> loaded, DateTime now,
    {bool hasMore = false}) {
  final today = [
    for (final g in loaded)
      if (sameLocalDay(g.startTime, now)) g
  ];
  if (today.isEmpty) return null;
  final partial =
      hasMore && loaded.isNotEmpty && sameLocalDay(loaded.last.startTime, now);
  return TodaySummary(games: today, partial: partial);
}
