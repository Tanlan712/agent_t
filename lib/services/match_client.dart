import '../logic/match_mapper.dart';
import '../models/match_models.dart';
import '../models/riot_session.dart';
import 'riot_client.dart';

/// 對戰紀錄相關的 pd 端點（Riot 未公開 API）。
class MatchClient {
  final RiotClient _riot;

  MatchClient(this._riot);

  /// 實測：查他人紀錄一次超過 10 場會回 400，所以大範圍分段請求。
  static const maxHistoryRange = 10;

  /// 回傳 [puuid]（預設是自己）從 [start] 起的 [count] 場與總場數；
  /// [queue] 指定時只取該模式。
  Future<(List<MatchRef>, int)> fetchHistory(
      RiotSession s, int start, int count,
      {String? puuid, String? queue}) async {
    final refs = <MatchRef>[];
    var total = 0;
    for (var from = start; from < start + count; from += maxHistoryRange) {
      final to = from + maxHistoryRange < start + count
          ? from + maxHistoryRange
          : start + count;
      final json =
          await _riot.getPd(s, '/match-history/v1/history/${puuid ?? s.puuid}',
              query: {
                'startIndex': '$from',
                'endIndex': '$to',
                if (queue != null && queue.isNotEmpty) 'queue': queue,
              },
              label: '取得對戰紀錄');
      final page = mapHistory(json);
      refs.addAll(page);
      total = (json['Total'] as num?)?.toInt() ?? 0;
      // 已經到底就不再要下一段。
      if (page.length < to - from || to >= total) break;
    }
    return (refs, total);
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
    // 名稱只是補充資訊：格式不符的項目直接略過，不讓整頁失敗。
    return {
      for (final e in list)
        if (e is Map &&
            e['Subject'] is String &&
            e['GameName'] is String &&
            (e['GameName'] as String).isNotEmpty)
          e['Subject'] as String:
              '${e['GameName']}#${e['TagLine'] is String ? e['TagLine'] : ''}',
    };
  }

  /// 任一玩家的 MMR 原始資料（用來查他在某一季的牌位）。
  Future<Map<String, dynamic>> fetchMmrJson(RiotSession s, String puuid) =>
      _riot.getPd(s, '/mmr/v1/players/$puuid', label: '取得玩家牌位');

  Future<RankInfo?> fetchRank(RiotSession s) async => mapRank(
      await _riot.getPd(s, '/mmr/v1/players/${s.puuid}', label: '取得牌位'));
}
