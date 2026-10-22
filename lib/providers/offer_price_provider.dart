import 'package:flutter/foundation.dart';

import '../models/offer_prices.dart';
import '../models/skin_info.dart';
import '../storage/offer_price_storage.dart';

/// 造型的實際定價：每次從 Riot 同步商店時，把看到的價格記下來，存在這個瀏覽器
/// （所有玩家共用的公開價格，不含個人資料）。不另外送 Riot 請求。
class OfferPriceProvider with ChangeNotifier {
  final OfferPriceStorage _storage;
  final DateTime Function() _now;

  OfferPrices? _prices;

  OfferPriceProvider(this._storage, {DateTime Function() now = DateTime.now})
      : _now = now,
        _prices = _storage.load();

  OfferPrices? get prices => _prices;

  /// 造型的 VP 定價（用第一個造型等級查）；還沒在商店看過時回傳 null。
  int? priceOf(SkinInfo? skin) => _prices?.priceOf(skin?.levelUuid);

  /// 記錄一次 storefront 回應裡的價格；沒有新價格時不寫入。
  Future<void> record(Map<String, dynamic> storefront) async {
    final seen = OfferPrices.fromStorefront(storefront);
    if (seen.isEmpty) return;
    final old = _prices;
    final merged = old == null
        ? OfferPrices(vp: seen, fetchedAt: _now())
        : old.merge(seen, _now());
    _prices = merged;
    notifyListeners();
    await _storage.save(merged);
  }
}
