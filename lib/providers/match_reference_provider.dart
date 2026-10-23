import 'package:flutter/foundation.dart';

import '../logic/combat_stats.dart' show currentActId;
import '../models/match_models.dart';
import '../services/match_reference_api.dart';
import '../storage/match_reference_cache.dart';

/// 特務、地圖、牌位的顯示資料；下載失敗時以佔位顯示，不阻擋畫面。
class MatchReferenceProvider with ChangeNotifier {
  final MatchReferenceApi _api;
  final MatchReferenceCache _cache;
  final DateTime Function() _now;
  MatchReference? _reference;

  MatchReferenceProvider(this._api, this._cache,
      {DateTime Function() now = DateTime.now})
      : _now = now;

  MatchReference? get reference => _reference;

  /// 先用快取；快取裡沒有涵蓋現在的幕（下一幕已開始，或之前賽季下載失敗）時重新下載，
  /// 下載失敗就繼續用舊快取。
  Future<void> init() async {
    final cached = _cache.load();
    if (cached != null) {
      _reference = cached;
      notifyListeners();
      if (currentActId(cached.seasons, _now()) != null) return;
    }
    try {
      final fresh = await _api.fetch();
      _reference = fresh;
      await _cache.save(fresh);
    } catch (e) {
      debugPrint('對戰參考資料下載失敗：$e');
    }
    notifyListeners();
  }

  static RefItem _fallback(String id) => RefItem(
      name:
          id.length > 8 ? id.substring(0, 8).toLowerCase() : id.toLowerCase());

  RefItem agent(String uuid) =>
      _reference?.agents[uuid.toLowerCase()] ?? _fallback(uuid);

  /// 所有可玩特務（uuid 小寫 → 名稱）；遠端選角的下拉選單用。
  Map<String, RefItem> get agents => _reference?.agents ?? const {};

  /// 所有地圖（mapUrl → 名稱）；自訂對戰選地圖用。
  Map<String, RefItem> get maps => _reference?.maps ?? const {};

  RefItem map(String mapUrl) =>
      _reference?.maps[mapUrl] ?? _fallback(mapUrl.split('/').last);

  RefItem tier(int tier) =>
      _reference?.tiers[tier] ?? const RefItem(name: '未定級');
}
