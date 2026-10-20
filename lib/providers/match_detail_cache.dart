import '../models/riot_session.dart';
import '../services/match_client.dart';

/// 單場詳情原始 JSON 的記憶體快取，由對戰紀錄、最近 5 場與玩家頁共用。
/// 同一場只請求一次；請求進行中又被要求時共用同一個 Future；失敗不快取。
class MatchDetailCache {
  final Map<String, Future<Map<String, dynamic>>> _entries = {};

  Future<Map<String, dynamic>> json(
      RiotSession s, String matchId, MatchClient client) {
    final cached = _entries[matchId];
    if (cached != null) return cached;
    final future = client.fetchMatchJson(s, matchId);
    _entries[matchId] = future;
    future.then((_) {}, onError: (Object _) {
      if (identical(_entries[matchId], future)) _entries.remove(matchId);
    });
    return future;
  }

  void clear() => _entries.clear();
}
