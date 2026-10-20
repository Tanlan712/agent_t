import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/storefront_mapper.dart';

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
}
