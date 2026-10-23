import '../models/current_shop.dart';

/// 特務幣（VP）的貨幣 ID。
const vpCurrencyId = '85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741';

/// 王國幣（配件商店的獎章）的貨幣 ID。
const kingdomCurrencyId = '85ca954a-41f2-ce94-9b45-8ca3dd39a00d';

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
  // Bundles 是同時上架的所有組合包；沒有時用單一的 Bundle。
  final rawBundles = [
    for (final b in (featured?['Bundles'] as List<dynamic>? ?? const []))
      if (b is Map<String, dynamic>) b
  ];
  if (rawBundles.isEmpty && featured?['Bundle'] is Map<String, dynamic>) {
    rawBundles.add(featured!['Bundle'] as Map<String, dynamic>);
  }
  final fallbackSeconds = featured?['BundleRemainingDurationInSeconds'];
  final bundles = [
    for (final b in rawBundles)
      BundleEntry(
        bundleUuid: b['DataAssetID'] as String,
        price: _vp(b['TotalDiscountedCost']) > 0
            ? _vp(b['TotalDiscountedCost'])
            : _vp(b['TotalBaseCost']),
        endsAt: now
            .add(_seconds(b['DurationRemainingInSeconds'] ?? fallbackSeconds)),
      ),
  ];

  // 配件商店（AccessoryStore）：同一個 storefront 回應，用王國幣購買。
  final accessory = json['AccessoryStore'] as Map<String, dynamic>?;
  final accessories = [
    for (final a
        in (accessory?['AccessoryStoreOffers'] as List<dynamic>? ?? const []))
      if (a is Map<String, dynamic> && a['Offer'] is Map<String, dynamic>)
        if (_accessory(a['Offer'] as Map<String, dynamic>) case final e?) e,
  ];

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
    featuredBundle: bundles.firstOrNull,
    featuredBundles: bundles,
    featuredBundleUpdatedAt: bundles.isEmpty ? null : now,
    accessories: accessories,
    accessoryEndsAt: accessories.isEmpty
        ? null
        : now.add(
            _seconds(accessory?['AccessoryStoreRemainingDurationInSeconds'])),
  );
}

AccessoryEntry? _accessory(Map<String, dynamic> offer) {
  final rewards = offer['Rewards'] as List<dynamic>? ?? const [];
  if (rewards.isEmpty || rewards.first is! Map<String, dynamic>) return null;
  final r = rewards.first as Map<String, dynamic>;
  final type = r['ItemTypeID'] as String?;
  final id = r['ItemID'] as String?;
  if (type == null || id == null) return null;
  final cost = offer['Cost'] as Map<String, dynamic>? ?? const {};
  return AccessoryEntry(
    itemTypeId: type.toLowerCase(),
    itemId: id.toLowerCase(),
    price: (cost[kingdomCurrencyId] as num?)?.toInt() ??
        (cost.values.firstOrNull as num?)?.toInt() ??
        0,
  );
}
