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

  Future<void> save(CurrentShop shop) => writePrefsJson(_prefs, _key, shop.toJson());
}
