/// 全物品的實際定價（`GET /store/v1/offers/`，格式依社群文件，見 docs/api-fields.md）。
library;

/// 不是陣列（格式改變）時當成空的。
List<dynamic> _list(Object? v) => v is List ? v : const [];

class OfferPrices {
  static const vpCurrency = '85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741';

  /// 物品 ID（小寫，例如造型第一個等級的 uuid）→ VP 價格。
  final Map<String, int> vp;

  /// 從 Riot 取得的時間；用來決定多久重抓一次。
  final DateTime fetchedAt;

  const OfferPrices({required this.vp, required this.fetchedAt});

  int? priceOf(String? itemId) =>
      itemId == null ? null : vp[itemId.toLowerCase()];

  /// 只取 VP 價格大於 0 的 offer；格式不符的項目略過，不讓整份失敗。
  factory OfferPrices.fromRiot(Map<String, dynamic> json, DateTime now) {
    final vp = <String, int>{};
    for (final offer in _list(json['Offers'])) {
      if (offer is! Map<String, dynamic>) continue;
      final cost = offer['Cost'];
      final price = cost is Map ? cost[vpCurrency] : null;
      if (price is! num || price <= 0) continue;
      for (final reward in _list(offer['Rewards'])) {
        if (reward is! Map<String, dynamic>) continue;
        final id = reward['ItemID'];
        if (id is String && id.isNotEmpty) {
          vp.putIfAbsent(id.toLowerCase(), () => price.toInt());
        }
      }
    }
    return OfferPrices(vp: vp, fetchedAt: now);
  }

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
