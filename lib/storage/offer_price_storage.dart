import 'package:shared_preferences/shared_preferences.dart';

import '../models/offer_prices.dart';
import 'prefs_json.dart';

/// 全物品定價的快取：所有玩家共用的公開價格，不含 token 或個人資料，登出後仍保留。
class OfferPriceStorage {
  static const key = 'offer_prices_v1';
  final SharedPreferences _prefs;

  OfferPriceStorage(this._prefs);

  OfferPrices? load() => readPrefsJson<OfferPrices?>(_prefs, key,
      (j) => OfferPrices.fromJson(j as Map<String, dynamic>), null);

  Future<void> save(OfferPrices prices) =>
      writePrefsJson(_prefs, key, prices.toJson());
}
