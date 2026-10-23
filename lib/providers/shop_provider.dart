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

  Future<void> saveFeaturedBundle(BundleEntry entry, DateTime now) => _update(
      _shop.copyWith(featuredBundle: entry, featuredBundleUpdatedAt: now));

  /// 以 Riot 同步結果整份取代，不套用手動輸入的筆數驗證。
  Future<void> replaceShop(CurrentShop shop) => _update(shop);

  Future<void> clearDaily() => _update(_shop.clearDaily());
  Future<void> clearNightMarket() => _update(_shop.clearNightMarket());
  Future<void> clearFeaturedBundle() => _update(_shop.clearFeaturedBundle());

  /// 換帳號：把目前的商店存到 [from] 名下，換成 [to] 上次的商店（沒有時清空，等同步）。
  /// 登出（[to] 為 null）時保留畫面上的商店，刪除 [from] 的備份。
  Future<void> switchAccount(String? from, String? to) async {
    if (to == null) {
      if (from != null) await _storage.removeFor(from);
      return;
    }
    if (from != null) await _storage.saveFor(from, _shop);
    final saved = _storage.loadFor(to);
    if (saved != null) {
      await _update(saved);
    } else if (from != null) {
      await _update(const CurrentShop());
    }
  }

  /// 刪除帳號時一併刪除它的商店備份。
  Future<void> forgetAccount(String puuid) => _storage.removeFor(puuid);

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
