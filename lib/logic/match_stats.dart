import '../models/match_models.dart';

/// 對戰紀錄的模式篩選。
enum ModeFilter { all, competitive, unrated, other }

enum ResultFilter { all, win, loss }

/// 對戰紀錄的篩選：模式、特務、地圖、勝負（null 代表不限）。
class MatchFilter {
  final ModeFilter mode;
  final String? agentId;
  final String? mapId;
  final ResultFilter result;

  const MatchFilter({
    this.mode = ModeFilter.all,
    this.agentId,
    this.mapId,
    this.result = ResultFilter.all,
  });

  bool get isEmpty =>
      mode == ModeFilter.all &&
      agentId == null &&
      mapId == null &&
      result == ResultFilter.all;

  bool accepts(MatchSummary s) {
    final modeOk = switch (mode) {
      ModeFilter.all => true,
      ModeFilter.competitive => s.queueId == 'competitive',
      ModeFilter.unrated => s.queueId == 'unrated',
      ModeFilter.other => s.queueId != 'competitive' && s.queueId != 'unrated',
    };
    final resultOk = switch (result) {
      ResultFilter.all => true,
      ResultFilter.win => s.won == true,
      ResultFilter.loss => s.won == false,
    };
    return modeOk &&
        resultOk &&
        (agentId == null || s.myAgentId == agentId) &&
        (mapId == null || s.mapId == mapId);
  }

  MatchFilter copyWith({
    ModeFilter? mode,
    String? Function()? agentId,
    String? Function()? mapId,
    ResultFilter? result,
  }) =>
      MatchFilter(
        mode: mode ?? this.mode,
        agentId: agentId == null ? this.agentId : agentId(),
        mapId: mapId == null ? this.mapId : mapId(),
        result: result ?? this.result,
      );
}

List<MatchSummary> _oldestFirst(Iterable<MatchSummary> games) =>
    [...games]..sort((a, b) => a.startTime.compareTo(b.startTime));

/// RR 走勢：由舊到新累計 RR 變化（只算有 RR 變化的場次）。
List<int> rrSeries(Iterable<MatchSummary> games) {
  var total = 0;
  return [
    for (final g in _oldestFirst(games))
      if (g.rrChange case final rr?) total += rr,
  ];
}

/// ACS 走勢：由舊到新。
List<int> acsSeries(Iterable<MatchSummary> games) =>
    [for (final g in _oldestFirst(games)) g.acs];

/// 一組場次（同一位特務或同一張地圖）的統計。
class GroupStat {
  final String key;
  final int games;

  /// 有勝負的場次中贏的比例；都是平手時為 null。
  final double? winRate;

  /// 總擊殺 ÷ 總死亡（沒有死亡時用 1）。
  final double avgKd;
  final double avgAcs;

  const GroupStat({
    required this.key,
    required this.games,
    required this.winRate,
    required this.avgKd,
    required this.avgAcs,
  });
}

/// 依 [keyOf]（特務或地圖）分組統計；場數多的在前，同場數時勝率高的在前。
List<GroupStat> statsBy(
    Iterable<MatchSummary> games, String Function(MatchSummary) keyOf) {
  final groups = <String, List<MatchSummary>>{};
  for (final g in games) {
    (groups[keyOf(g)] ??= []).add(g);
  }
  final out = [
    for (final e in groups.entries)
      () {
        final list = e.value;
        final decided = list.where((g) => g.won != null).toList();
        final kills = list.fold<int>(0, (s, g) => s + g.kills);
        final deaths = list.fold<int>(0, (s, g) => s + g.deaths);
        return GroupStat(
          key: e.key,
          games: list.length,
          winRate: decided.isEmpty
              ? null
              : decided.where((g) => g.won == true).length / decided.length,
          avgKd: kills / (deaths == 0 ? 1 : deaths),
          avgAcs: list.fold<int>(0, (s, g) => s + g.acs) / list.length,
        );
      }(),
  ];
  out.sort((a, b) {
    final byGames = b.games.compareTo(a.games);
    if (byGames != 0) return byGames;
    return (b.winRate ?? -1).compareTo(a.winRate ?? -1);
  });
  return out;
}
