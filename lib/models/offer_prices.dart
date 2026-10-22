/// 造型的實際定價：從商店（storefront）回應裡看過的價格累積而成。
/// 實測（2026-10-22）`GET /store/v1/offers/` 與 v2 都回 404，所以沒有一次拿到全部價格的來源；
/// 每日商店、夜市原價與組合包內的單品價格都是 Riot 的實際定價，見過一次就記下來。
library;

/// 不是陣列（格式改變）時當成空的。
List<dynamic> _list(Object? v) => v is List ? v : const [];

class OfferPrices {
  static const vpCurrency = '85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741';
  static const _skinLevelType = 'e7c63390-eda7-46e0-bb7a-a6abdacd2433';

  /// 物品 ID（小寫，例如造型第一個等級的 uuid）→ VP 價格。
  final Map<String, int> vp;

  /// 最後一次記錄價格的時間。
  final DateTime fetchedAt;

  const OfferPrices({required this.vp, required this.fetchedAt});

  int? priceOf(String? itemId) =>
      itemId == null ? null : vp[itemId.toLowerCase()];

  /// 從 storefront 回應取出造型價格（物品 ID → VP）；格式不符的項目略過，不讓整份失敗。
  /// - 每日商店 `SingleItemStoreOffers[]` 與夜市 `BonusStoreOffers[].Offer` 的 `Cost`（原價）
  /// - 組合包 `Bundles[].Items[]` 裡造型等級的 `BasePrice`（單買的價格，不是組合包折扣價）
  static Map<String, int> fromStorefront(Map<String, dynamic> json) {
    final vp = <String, int>{};
    void add(Object? id, Object? price) {
      if (id is String && id.isNotEmpty && price is num && price > 0) {
        vp[id.toLowerCase()] = price.toInt();
      }
    }

    void offer(Object? o) {
      if (o is! Map<String, dynamic>) return;
      final cost = o['Cost'];
      final price = cost is Map ? cost[vpCurrency] : null;
      for (final r in _list(o['Rewards'])) {
        if (r is Map<String, dynamic>) add(r['ItemID'], price);
      }
    }

    final panel = json['SkinsPanelLayout'];
    if (panel is Map<String, dynamic>) {
      _list(panel['SingleItemStoreOffers']).forEach(offer);
    }
    final bonus = json['BonusStore'];
    if (bonus is Map<String, dynamic>) {
      for (final b in _list(bonus['BonusStoreOffers'])) {
        if (b is Map<String, dynamic>) offer(b['Offer']);
      }
    }
    final featured = json['FeaturedBundle'];
    if (featured is Map<String, dynamic>) {
      final bundles = [
        ..._list(featured['Bundles']),
        if (featured['Bundles'] == null) featured['Bundle'],
      ];
      for (final b in bundles) {
        if (b is! Map<String, dynamic>) continue;
        for (final it in _list(b['Items'])) {
          if (it is! Map<String, dynamic>) continue;
          final item = it['Item'];
          if (item is! Map<String, dynamic>) continue;
          if (it['CurrencyID'] != vpCurrency) continue;
          if ((item['ItemTypeID'] as Object?) != _skinLevelType) continue;
          add(item['ItemID'], it['BasePrice']);
        }
      }
    }
    return vp;
  }

  /// 加上新看到的價格（同一個物品以新的為準）。
  OfferPrices merge(Map<String, int> seen, DateTime now) =>
      OfferPrices(vp: {...vp, ...seen}, fetchedAt: now);

  factory OfferPrices.fromJson(Map<String, dynamic> json) => OfferPrices(
        vp: {
          for (final e in (json['vp'] as Map<String, dynamic>).entries)
            e.key: (e.value as num).toInt(),
        },
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );

  Map<String, dynamic> toJson() =>
      {'vp': vp, 'fetchedAt': fetchedAt.toIso8601String()};
}
