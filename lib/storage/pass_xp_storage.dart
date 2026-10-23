import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_json.dart';

/// 通行證每日經驗紀錄：每個帳號、每份通行證、每天最後一次看到的累積經驗。
/// 只存在這個瀏覽器／這支手機，最多保留 120 天。
class PassXpStorage {
  static const _prefix = 'pass_xp_v1';
  static const maxDays = 120;

  final SharedPreferences _prefs;

  PassXpStorage(this._prefs);

  static String key(String puuid, String contractId) =>
      '${_prefix}_${puuid}_$contractId';

  Map<String, int> load(String puuid, String contractId) =>
      readPrefsJson<Map<String, int>>(
        _prefs,
        key(puuid, contractId),
        (json) => {
          for (final e in (json as Map<String, dynamic>).entries)
            e.key: (e.value as num).toInt(),
        },
        const {},
      );

  /// 記下 [day] 的累積經驗（同一天覆蓋），回傳更新後的紀錄。
  Future<Map<String, int>> record(
      String puuid, String contractId, String day, int totalXp) async {
    final map = {...load(puuid, contractId), day: totalXp};
    final keys = map.keys.toList()..sort();
    for (final k
        in keys.take(keys.length > maxDays ? keys.length - maxDays : 0)) {
      map.remove(k);
    }
    await writePrefsJson(_prefs, key(puuid, contractId), map);
    return map;
  }
}
