import 'match_detail_cache.dart';
import 'match_history_provider.dart';

/// 其他玩家的分頁對戰紀錄：一個 puuid 一份，由玩家頁建立與釋放。
/// 摘要以該玩家為主，不取牌位與 RR。
class PlayerHistoryProvider extends MatchHistoryProvider {
  PlayerHistoryProvider(super.client, super.riot, MatchDetailCache cache,
      {required String puuid,
      super.pageSize = 20,
      super.maxConcurrent = 2,
      super.onDetails})
      : super(cache: cache, focusPuuid: puuid);
}
