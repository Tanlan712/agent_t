import '../models/match_models.dart';

int _int(Object? v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);

/// 目前牌位（這一幕的競技牌位與 RR）。
class RankSnapshot {
  final int tier;
  final int rr;

  const RankSnapshot({required this.tier, required this.rr});
}

/// 歷史最高牌位與取得的賽季（推算）。
class PeakRank {
  final int tier;
  final String seasonId;

  const PeakRank({required this.tier, required this.seasonId});
}

/// 第五章第一幕開始（valorant-api 實測 2022-06-21）；之前的舊制 tier 21～23 是神話 1～3、24 是輻能。
final _newTierSystem = DateTime.utc(2022, 6, 21);

/// 把舊制 tier 換成新制（新制在鑽石之後多了超凡 21～23）。
int normalizeTier(int tier, DateTime? seasonStart) {
  if (seasonStart == null || !seasonStart.isBefore(_newTierSystem)) return tier;
  return tier >= 21 ? tier + 3 : tier;
}

Map<String, dynamic> _seasonal(Map<String, dynamic> mmr) =>
    (((mmr['QueueSkills'] as Map<String, dynamic>?)?['competitive']
            as Map<String, dynamic>?)?['SeasonalInfoBySeasonID']
        as Map<String, dynamic>?) ??
    const {};

/// 現在時間所在的幕（Act）uuid；找不到時為 null。
String? currentActId(Map<String, SeasonRef> seasons, DateTime now) {
  for (final e in seasons.entries) {
    final s = e.value;
    if (s.isAct && !now.isBefore(s.start) && now.isBefore(s.end)) return e.key;
  }
  return null;
}

/// MMR 最近一次競技更新所在的賽季（小寫）；本幕查不到時的後備。
String? latestSeasonId(Map<String, dynamic> mmr) {
  final id =
      (mmr['LatestCompetitiveUpdate'] as Map<String, dynamic>?)?['SeasonID'];
  return id is String && id.isNotEmpty ? id.toLowerCase() : null;
}

/// 這一幕的競技牌位與 RR；沒有資料或未定級時為 null。
RankSnapshot? currentRank(Map<String, dynamic> mmr, String? actId) {
  if (actId == null) return null;
  final seasonal = _seasonal(mmr);
  // MMR 的賽季 ID 可能是大寫。
  final info = (seasonal[actId] ??
      seasonal.entries
          .where((e) => e.key.toLowerCase() == actId.toLowerCase())
          .firstOrNull
          ?.value) as Map<String, dynamic>?;
  final tier = _int(info?['CompetitiveTier']);
  if (tier <= 0) return null;
  return RankSnapshot(tier: tier, rr: _int(info?['RankedRating']));
}

/// 歷史最高牌位：每季取 WinsByTier 中有勝場的最高 tier（沒有時用 CompetitiveTier），
/// 舊制換成新制後取最高；同分取較新的一季。沒有任何牌位時為 null。
PeakRank? peakRank(Map<String, dynamic> mmr, Map<String, SeasonRef> seasons) {
  PeakRank? best;
  DateTime? bestStart;
  for (final e in _seasonal(mmr).entries) {
    final info = e.value as Map<String, dynamic>?;
    if (info == null) continue;
    var raw = 0;
    final wins = info['WinsByTier'];
    if (wins is Map) {
      for (final w in wins.entries) {
        if (_int(w.value) > 0 && _int(w.key) > raw) raw = _int(w.key);
      }
    }
    if (raw == 0) raw = _int(info['CompetitiveTier']);
    if (raw <= 0) continue;
    final start = seasons[e.key.toLowerCase()]?.start;
    final tier = normalizeTier(raw, start);
    final newer =
        bestStart == null || (start != null && start.isAfter(bestStart));
    if (best == null || tier > best.tier || (tier == best.tier && newer)) {
      best = PeakRank(tier: tier, seasonId: e.key);
      bestStart = start;
    }
  }
  return best;
}

String seasonLabel(Map<String, SeasonRef> seasons, String seasonId) =>
    seasons[seasonId.toLowerCase()]?.name ?? '未知賽季';

/// 所有賽季的競技總場數（SeasonalInfoBySeasonID 的 NumberOfGames 加總）；
/// MMR 沒有競技資料時為 0。
int competitiveGames(Map<String, dynamic> mmr) => _seasonal(mmr)
    .values
    .whereType<Map<String, dynamic>>()
    .fold<int>(0, (s, info) => s + _int(info['NumberOfGames']));
