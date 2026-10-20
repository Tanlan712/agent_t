import 'package:flutter/foundation.dart';

import '../models/current_shop.dart';
import '../storage/shop_storage.dart';

class ShopProvider with ChangeNotifier {
  static const dailyCount = 4;
  static const nightMarketCount = 6;

  final ShopStorage _storage;
  CurrentShop _shop;

  ShopProvider(this._storage) : _shop = _storage.load();

  CurrentShop get shop => _shop;

  Future<void> saveDaily(
    List<ShopEntry> entries,
    DateTime expiresAt,
    DateTime now,
  ) {
    _validate(entries.map((e) => e.skinUuid), dailyCount, '每日商店需要 4 個造型');
    return _update(_shop.copyWith(
      daily: List.unmodifiable(entries),
      dailyExpiresAt: expiresAt,
      dailyUpdatedAt: now,
    ));
  }

  Future<void> saveNightMarket(
    List<NightMarketEntry> entries,
    DateTime endsAt,
    DateTime now,
  ) {
    _validate(entries.map((e) => e.skinUuid), nightMarketCount, '夜市需要 6 個造型');
    return _update(_shop.copyWith(
      nightMarket: List.unmodifiable(entries),
      nightMarketEndsAt: endsAt,
      nightMarketUpdatedAt: now,
    ));
  }

  Future<void> saveFeaturedBundle(BundleEntry entry, DateTime now) =>
      _update(_shop.copyWith(featuredBundle: entry, featuredBundleUpdatedAt: now));

  /// 以 Riot 同步結果整份取代，不套用手動輸入的筆數驗證。
  Future<void> replaceShop(CurrentShop shop) => _update(shop);

  Future<void> clearDaily() => _update(_shop.clearDaily());
  Future<void> clearNightMarket() => _update(_shop.clearNightMarket());
  Future<void> clearFeaturedBundle() => _update(_shop.clearFeaturedBundle());

  void _validate(Iterable<String> uuids, int count, String countMessage) {
    final list = uuids.toList();
    if (list.length != count) throw ArgumentError(countMessage);
    if (list.toSet().length != list.length) throw ArgumentError('同一造型不能重複');
  }

  Future<void> _update(CurrentShop next) async {
    _shop = next;
    await _storage.save(next);
    notifyListeners();
  }
}
