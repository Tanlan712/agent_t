import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/storefront_mapper.dart';
import 'package:agent_t/models/current_shop.dart';

import '../riot_fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 20, 10);
  String resolve(String id) =>
      const {
        'lvl-odin': 'skin-odin',
        'lvl-noicon': 'skin-noicon',
        'lvl-a': 'skin-a',
      }[id] ??
      id;

  test('每日商店：價格取 VP、到期時間、對不到的保留原 ID', () {
    final shop = mapStorefront(storefrontJson(), resolve, now);
    expect(shop.daily.map((e) => e.skinUuid),
        ['skin-odin', 'skin-noicon', 'skin-a', 'lvl-unknown']);
    expect(shop.daily.map((e) => e.price), [1275, 2475, 875, 1775]);
    expect(shop.dailyExpiresAt, now.add(const Duration(seconds: 3600)));
    expect(shop.dailyUpdatedAt, now);
  });

  test('夜市：原價、折扣價與結束時間', () {
    final shop = mapStorefront(storefrontJson(), resolve, now);
    expect(shop.nightMarket.length, 2);
    expect(shop.nightMarket.first.skinUuid, 'skin-odin');
    expect(shop.nightMarket.first.originalPrice, 1275);
    expect(shop.nightMarket.first.discountedPrice, 893);
    expect(shop.nightMarketEndsAt, now.add(const Duration(days: 1)));
  });

  test('精選組合包：DataAssetID 與折扣後總價', () {
    final shop = mapStorefront(storefrontJson(), resolve, now);
    expect(shop.featuredBundle!.bundleUuid, 'bundle-rgx');
    expect(shop.featuredBundle!.price, 7100);
  });

  test('多個精選組合包：全部保留，各自的剩餘時間', () {
    final json = storefrontJson();
    final featured = json['FeaturedBundle'] as Map<String, dynamic>;
    final first = featured['Bundle'] as Map<String, dynamic>;
    featured['Bundles'] = [
      first,
      {
        ...first,
        'ID': 'b2-offer',
        'DataAssetID': 'bundle-2',
        'TotalDiscountedCost': {vpCurrencyId: 0},
        'TotalBaseCost': {vpCurrencyId: 5000},
        'DurationRemainingInSeconds': 7200,
      },
    ];
    final shop = mapStorefront(json, resolve, now);
    expect(shop.featuredBundles.map((b) => b.bundleUuid),
        ['bundle-rgx', 'bundle-2']);
    expect(shop.featuredBundles.map((b) => b.price), [7100, 5000]);
    expect(shop.featuredBundles.first.endsAt,
        now.add(const Duration(seconds: 500000)));
    expect(shop.featuredBundles.last.endsAt,
        now.add(const Duration(seconds: 7200)));
    // 相容：featuredBundle 是第一個。
    expect(shop.featuredBundle!.bundleUuid, 'bundle-rgx');
  });

  test('只有 Bundle 時 featuredBundles 也有一個，含剩餘時間', () {
    final shop = mapStorefront(storefrontJson(), resolve, now);
    expect(shop.featuredBundles.single.bundleUuid, 'bundle-rgx');
    expect(shop.featuredBundles.single.endsAt,
        now.add(const Duration(seconds: 500000)));
  });

  test('沒有 BonusStore 時夜市為空', () {
    final shop =
        mapStorefront(storefrontJson(withNightMarket: false), resolve, now);
    expect(shop.nightMarket, isEmpty);
    expect(shop.nightMarketEndsAt, isNull);
  });

  test('只有 Bundles 陣列時取第一個', () {
    final json = storefrontJson();
    final bundle =
        (json['FeaturedBundle'] as Map<String, dynamic>).remove('Bundle');
    (json['FeaturedBundle'] as Map<String, dynamic>)['Bundles'] = [bundle];
    expect(mapStorefront(json, resolve, now).featuredBundle!.bundleUuid,
        'bundle-rgx');
  });

  test('配件商店：類型、物品（轉小寫）、王國幣價格與剩餘時間，存讀不變', () {
    final json = storefrontJson();
    json['AccessoryStore'] = {
      'AccessoryStoreOffers': [
        {
          'Offer': {
            'OfferID': 'o1',
            'Cost': {kingdomCurrencyId: 3000},
            'Rewards': [
              {
                'ItemTypeID': 'DD3BF334-87F3-40BD-B043-682A57A8DC3A',
                'ItemID': 'BUDDY-LVL-1',
                'Quantity': 1
              }
            ],
          },
          'ContractID': 'c1',
        },
        {
          'Offer': {
            'OfferID': 'o2',
            'Cost': {kingdomCurrencyId: 2000},
            'Rewards': [
              {
                'ItemTypeID': 'de7caa6b-adf7-4588-bbd1-143831e786c6',
                'ItemID': 'title-1'
              }
            ],
          },
        },
        {'Offer': {'OfferID': 'bad', 'Rewards': []}},
      ],
      'AccessoryStoreRemainingDurationInSeconds': 7200,
    };
    final shop = mapStorefront(json, resolve, now);
    expect(shop.accessories.map((a) => a.itemId), ['buddy-lvl-1', 'title-1']);
    expect(shop.accessories.first.itemTypeId,
        'dd3bf334-87f3-40bd-b043-682a57a8dc3a');
    expect(shop.accessories.map((a) => a.price), [3000, 2000]);
    expect(shop.accessoryEndsAt, now.add(const Duration(hours: 2)));
    final back = CurrentShop.fromJson(shop.toJson());
    expect(back.accessories.map((a) => a.itemId), ['buddy-lvl-1', 'title-1']);
    expect(back.accessoryEndsAt, shop.accessoryEndsAt);
    expect(back.clearDaily().accessories.length, 2);
  });

  test('沒有 AccessoryStore 時配件商店為空', () {
    final shop = mapStorefront(storefrontJson(), resolve, now);
    expect(shop.accessories, isEmpty);
    expect(shop.accessoryEndsAt, isNull);
  });
}
