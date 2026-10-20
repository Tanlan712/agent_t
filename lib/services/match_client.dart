import '../logic/match_mapper.dart';
import '../models/match_models.dart';
import '../models/riot_session.dart';
import 'riot_client.dart';

/// 對戰紀錄相關的 pd 端點（Riot 未公開 API）。
class MatchClient {
  final RiotClient _riot;

  MatchClient(this._riot);

  /// 回傳 [start] 起的 [count] 場與總場數。
  Future<(List<MatchRef>, int)> fetchHistory(
      RiotSession s, int start, int count) async {
    final json = await _riot.getPd(s, '/match-history/v1/history/${s.puuid}',
        query: {'startIndex': '$start', 'endIndex': '${start + count}'},
        label: '取得對戰紀錄');
    return (mapHistory(json), (json['Total'] as num?)?.toInt() ?? 0);
  }

  Future<Map<String, dynamic>> fetchMatchJson(RiotSession s, String matchId) =>
      _riot.getPd(s, '/match-details/v1/matches/$matchId', label: '取得對戰詳情');

  Future<Map<String, int>> fetchRrChanges(RiotSession s, int count) async {
    final json = await _riot.getPd(
        s, '/mmr/v1/players/${s.puuid}/competitiveupdates',
        query: {'startIndex': '0', 'endIndex': '$count'}, label: '取得牌位變化');
    return rrByMatch(json);
  }

  /// 實測 match-details 不含玩家名稱，改用 name-service 查詢；
  /// 回傳 puuid → `名稱#Tag`，名稱為空的玩家不列入。
  Future<Map<String, String>> fetchNames(
      RiotSession s, Iterable<String> puuids) async {
    final ids = puuids.toSet().toList();
    if (ids.isEmpty) return const {};
    final list = await _riot.putPdList(s, '/name-service/v2/players', ids,
        label: '取得玩家名稱');
    return {
      for (final e in list.cast<Map<String, dynamic>>())
        if ((e['GameName'] as String? ?? '').isNotEmpty)
          e['Subject'] as String: '${e['GameName']}#${e['TagLine'] ?? ''}',
    };
  }

  Future<RankInfo?> fetchRank(RiotSession s) async => mapRank(
      await _riot.getPd(s, '/mmr/v1/players/${s.puuid}', label: '取得牌位'));
}
