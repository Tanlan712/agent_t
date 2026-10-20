import '../models/current_shop.dart';

/// 特務幣（VP）的貨幣 ID。
const vpCurrencyId = '85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741';

int _vp(Object? cost) =>
    ((cost as Map<String, dynamic>?)?[vpCurrencyId] as num?)?.toInt() ?? 0;

String _itemId(Map<String, dynamic> offer) {
  final rewards = offer['Rewards'] as List<dynamic>? ?? const [];
  if (rewards.isNotEmpty) {
    final id = (rewards.first as Map<String, dynamic>)['ItemID'] as String?;
    if (id != null) return id;
  }
  return offer['OfferID'] as String;
}

Duration _seconds(Object? v) => Duration(seconds: (v as num?)?.toInt() ?? 0);

/// 把 Riot storefront 回應轉成 [CurrentShop]。
/// [resolveSkinUuid] 把 ItemID 對應回造型 uuid；對不到時應原樣回傳。
CurrentShop mapStorefront(
  Map<String, dynamic> json,
  String Function(String itemId) resolveSkinUuid,
  DateTime now,
) {
  final panel = json['SkinsPanelLayout'] as Map<String, dynamic>? ?? const {};
  final daily = [
    for (final o
        in (panel['SingleItemStoreOffers'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>())
      ShopEntry(skinUuid: resolveSkinUuid(_itemId(o)), price: _vp(o['Cost'])),
  ];

  final bonus = json['BonusStore'] as Map<String, dynamic>?;
  final night = [
    for (final b in (bonus?['BonusStoreOffers'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>())
      NightMarketEntry(
        skinUuid: resolveSkinUuid(_itemId(b['Offer'] as Map<String, dynamic>)),
        originalPrice: _vp((b['Offer'] as Map<String, dynamic>)['Cost']),
        discountedPrice: _vp(b['DiscountCosts']),
      ),
  ];

  final featured = json['FeaturedBundle'] as Map<String, dynamic>?;
  final bundles = featured?['Bundles'] as List<dynamic>?;
  final bundle = featured?['Bundle'] as Map<String, dynamic>? ??
      (bundles != null && bundles.isNotEmpty
          ? bundles.first as Map<String, dynamic>
          : null);
  final bundleCost = bundle == null
      ? 0
      : (_vp(bundle['TotalDiscountedCost']) > 0
          ? _vp(bundle['TotalDiscountedCost'])
          : _vp(bundle['TotalBaseCost']));

  return CurrentShop(
    daily: daily,
    dailyExpiresAt: daily.isEmpty
        ? null
        : now
            .add(_seconds(panel['SingleItemOffersRemainingDurationInSeconds'])),
    dailyUpdatedAt: daily.isEmpty ? null : now,
    nightMarket: night,
    nightMarketEndsAt: night.isEmpty
        ? null
        : now.add(_seconds(bonus?['BonusStoreRemainingDurationInSeconds'])),
    nightMarketUpdatedAt: night.isEmpty ? null : now,
    featuredBundle: bundle == null
        ? null
        : BundleEntry(
            bundleUuid: bundle['DataAssetID'] as String, price: bundleCost),
    featuredBundleUpdatedAt: bundle == null ? null : now,
  );
}
