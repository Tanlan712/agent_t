import 'package:shared_preferences/shared_preferences.dart';

import '../models/current_shop.dart';
import 'prefs_json.dart';

class ShopStorage {
  static const _key = 'current_shop';

  final SharedPreferences _prefs;

  ShopStorage(this._prefs);

  CurrentShop load() => readPrefsJson(
        _prefs,
        _key,
        (json) => CurrentShop.fromJson(json as Map<String, dynamic>),
        const CurrentShop(),
      );

  Future<void> save(CurrentShop shop) =>
      writePrefsJson(_prefs, _key, shop.toJson());

  /// 多帳號：切走時保存該帳號最後看到的商店，切回來時先顯示它（不含 token）。
  static String accountKey(String puuid) => '${_key}_$puuid';

  CurrentShop? loadFor(String puuid) => readPrefsJson<CurrentShop?>(
        _prefs,
        accountKey(puuid),
        (json) => CurrentShop.fromJson(json as Map<String, dynamic>),
        null,
      );

  Future<void> saveFor(String puuid, CurrentShop shop) =>
      writePrefsJson(_prefs, accountKey(puuid), shop.toJson());

  Future<void> removeFor(String puuid) => _prefs.remove(accountKey(puuid));
}
