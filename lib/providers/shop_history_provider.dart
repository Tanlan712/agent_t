import 'package:flutter/foundation.dart';

import '../logic/shop_history.dart';
import '../models/current_shop.dart';
import '../storage/shop_history_storage.dart';

/// 每次從 Riot 同步商店時記下每日商店與夜市（不另外送請求）。
class ShopHistoryProvider with ChangeNotifier {
  final ShopHistoryStorage _storage;
  final Map<String, ShopHistory> _loaded = {};

  ShopHistoryProvider(this._storage);

  ShopHistory historyOf(String puuid) =>
      _loaded[puuid] ??= _storage.load(puuid);

  Future<void> record(String puuid, CurrentShop shop) async {
    final before = historyOf(puuid);
    final next = recordShop(before, shop);
    if (identical(next, before)) return;
    _loaded[puuid] = next;
    notifyListeners();
    await _storage.save(puuid, next);
  }
}
