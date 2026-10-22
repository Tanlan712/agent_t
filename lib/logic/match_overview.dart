import '../models/match_models.dart';
import 'match_stats.dart';

/// 摘要主角那一列（[MatchSummary.focusPuuid]）；找不到時為 null。
PlayerLine? focusLine(MatchDetail d) {
  final id = d.summary.focusPuuid;
  if (id.isEmpty) return null;
  for (final team in d.teams.values) {
    for (final l in team) {
      if (l.puuid == id) return l;
    }
  }
  return null;
}

/// 對戰紀錄頁首的摘要（只用已載入、有詳細資料的場次）。
class HistoryOverview {
  final int games;
  final int wins;
  final int losses;

  /// 有勝負的場次中贏的比例；沒有時為 null。
  final double? winRate;

  /// 總擊殺 ÷ 總死亡（沒有死亡時用 1）。
  final double? kd;

  /// 有爆頭資料的場次的平均爆頭率（%）。
  final double? headshot;
  final double? adr;

  /// 最近 10 場，由新到舊。
  final List<MatchDetail> form;

  /// 最常用的 3 位特務。
  final List<GroupStat> topAgents;

  const HistoryOverview({
    required this.games,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.kd,
    required this.headshot,
    required this.adr,
    required this.form,
    required this.topAgents,
  });
}

double? _avg(Iterable<num> xs) =>
    xs.isEmpty ? null : xs.fold<num>(0, (a, b) => a + b) / xs.length;

/// [details] 由新到舊。
HistoryOverview summarizeHistory(List<MatchDetail> details) {
  final summaries = [for (final d in details) d.summary];
  final wins = summaries.where((s) => s.won == true).length;
  final losses = summaries.where((s) => s.won == false).length;
  final kills = summaries.fold<int>(0, (a, s) => a + s.kills);
  final deaths = summaries.fold<int>(0, (a, s) => a + s.deaths);
  final lines = [
    for (final d in details)
      if (focusLine(d) case final l?) l,
  ];
  return HistoryOverview(
    games: details.length,
    wins: wins,
    losses: losses,
    winRate: wins + losses == 0 ? null : wins / (wins + losses),
    kd: details.isEmpty ? null : kills / (deaths == 0 ? 1 : deaths),
    headshot: _avg([
      for (final l in lines)
        if (l.headshotPercent case final h?) h,
    ]),
    adr: _avg([for (final l in lines) l.adr]),
    form: details.take(10).toList(),
    topAgents: statsBy(summaries, (s) => s.myAgentId).take(3).toList(),
  );
}

/// 同一天（本地日期）的場次。
class DayGroup<T> {
  final DateTime day;
  final List<T> items;
  final int wins;
  final int losses;

  /// 當天有 RR 變化的場次合計；都沒有時為 null。
  final int? rr;

  const DayGroup({
    required this.day,
    required this.items,
    required this.wins,
    required this.losses,
    required this.rr,
  });
}

/// 依 [timeOf] 的本地日期分組，保留原順序。
List<DayGroup<T>> groupByDay<T>(List<T> items, DateTime Function(T) timeOf,
    MatchSummary? Function(T) summaryOf) {
  final days = <DateTime, List<T>>{};
  for (final item in items) {
    final t = timeOf(item);
    (days[DateTime(t.year, t.month, t.day)] ??= []).add(item);
  }
  return [
    for (final e in days.entries)
      () {
        final ss = [
          for (final i in e.value)
            if (summaryOf(i) case final s?) s,
        ];
        final rrs = [
          for (final s in ss)
            if (s.rrChange case final rr?) rr,
        ];
        return DayGroup<T>(
          day: e.key,
          items: e.value,
          wins: ss.where((s) => s.won == true).length,
          losses: ss.where((s) => s.won == false).length,
          rr: rrs.isEmpty ? null : rrs.fold<int>(0, (a, b) => a + b),
        );
      }(),
  ];
}

const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

/// 「今天」「昨天」或「10/20（二）」；不是今年時加上年份。
String dayLabel(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  if (d == today) return '今天';
  if (d == DateTime(today.year, today.month, today.day - 1)) return '昨天';
  final date = d.year == today.year
      ? '${d.month}/${d.day}'
      : '${d.year}/${d.month}/${d.day}';
  return '$date（${_weekdays[d.weekday - 1]}）';
}

String dayStatsLabel({required int wins, required int losses, int? rr}) {
  final base = '$wins 勝 $losses 敗';
  if (rr == null) return base;
  return '$base · RR ${rr > 0 ? '+$rr' : '$rr'}';
}
