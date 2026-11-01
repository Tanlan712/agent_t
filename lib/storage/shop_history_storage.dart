import 'package:shared_preferences/shared_preferences.dart';

import '../logic/shop_history.dart';
import 'prefs_json.dart';

/// 商店歷史：各帳號分開，只存在這個瀏覽器／這支手機（不含 token）。
class ShopHistoryStorage {
  static const prefix = 'shop_history_v1';

  final SharedPreferences _prefs;

  ShopHistoryStorage(this._prefs);

  static String key(String puuid) => '${prefix}_$puuid';

  ShopHistory load(String puuid) => readPrefsJson(
        _prefs,
        key(puuid),
        (json) => ShopHistory.fromJson(json as Map<String, dynamic>),
        const ShopHistory(),
      );

  Future<void> save(String puuid, ShopHistory history) =>
      writePrefsJson(_prefs, key(puuid), history.toJson());

  Future<void> remove(String puuid) => _prefs.remove(key(puuid));
}
