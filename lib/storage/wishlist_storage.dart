import 'package:shared_preferences/shared_preferences.dart';

import '../models/wishlist_item.dart';
import 'prefs_json.dart';

class WishlistStorage {
  static const _key = 'wishlist';

  final SharedPreferences _prefs;

  WishlistStorage(this._prefs);

  List<WishlistItem> load() => readPrefsJson(
        _prefs,
        _key,
        (json) => (json as List<dynamic>)
            .map((e) => WishlistItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        <WishlistItem>[],
      );

  Future<void> save(List<WishlistItem> items) =>
      writePrefsJson(_prefs, _key, items.map((e) => e.toJson()).toList());
}
