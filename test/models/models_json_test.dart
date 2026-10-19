import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/app_settings.dart';
import 'package:valorant_shop_tracker/models/bundle_info.dart';
import 'package:valorant_shop_tracker/models/current_shop.dart';
import 'package:valorant_shop_tracker/models/skin_catalog.dart';
import 'package:valorant_shop_tracker/models/skin_info.dart';
import 'package:valorant_shop_tracker/models/tier.dart';
import 'package:valorant_shop_tracker/models/wishlist_item.dart';

void main() {
  final t1 = DateTime(2026, 10, 19, 8, 0);
  final t2 = DateTime(2026, 10, 20, 8, 0);

  group('各模型 toJson/fromJson 來回一致', () {
    test('SkinInfo', () {
      final s = SkinInfo(
        uuid: 'a',
        name: '凌空之志 奧丁',
        weaponName: '奧丁',
        tier: Tier.deluxe,
        iconUrl: 'https://x/a.png',
      );
      final r = SkinInfo.fromJson(s.toJson());
      expect(r.uuid, 'a');
      expect(r.name, '凌空之志 奧丁');
      expect(r.weaponName, '奧丁');
      expect(r.tier, Tier.deluxe);
      expect(r.iconUrl, 'https://x/a.png');
    });

    test('SkinInfo 無圖示', () {
      final s = SkinInfo(uuid: 'a', name: 'n', weaponName: 'w', tier: Tier.ultra);
      expect(SkinInfo.fromJson(s.toJson()).iconUrl, isNull);
    });

    test('BundleInfo', () {
      final b = BundleInfo(uuid: 'b', name: 'RGX', iconUrl: 'https://x/b.png');
      final r = BundleInfo.fromJson(b.toJson());
      expect(r.uuid, 'b');
      expect(r.name, 'RGX');
      expect(r.iconUrl, 'https://x/b.png');
    });

    test('SkinCatalog', () {
      final c = SkinCatalog(
        skins: [SkinInfo(uuid: 'a', name: 'n', weaponName: 'w', tier: Tier.select)],
        bundles: [BundleInfo(uuid: 'b', name: 'B')],
        fetchedAt: t1,
      );
      final r = SkinCatalog.fromJson(c.toJson());
      expect(r.skins.single.uuid, 'a');
      expect(r.skins.single.tier, Tier.select);
      expect(r.bundles.single.name, 'B');
      expect(r.fetchedAt, t1);
    });

    test('CurrentShop 全空', () {
      final r = CurrentShop.fromJson(CurrentShop().toJson());
      expect(r.daily, isEmpty);
      expect(r.dailyExpiresAt, isNull);
      expect(r.dailyUpdatedAt, isNull);
      expect(r.nightMarket, isEmpty);
      expect(r.nightMarketEndsAt, isNull);
      expect(r.nightMarketUpdatedAt, isNull);
      expect(r.featuredBundle, isNull);
      expect(r.featuredBundleUpdatedAt, isNull);
    });

    test('CurrentShop 全滿', () {
      final shop = CurrentShop(
        daily: [ShopEntry(skinUuid: 'a', price: 1275)],
        dailyExpiresAt: t2,
        dailyUpdatedAt: t1,
        nightMarket: [
          NightMarketEntry(skinUuid: 'c', originalPrice: 1775, discountedPrice: 900),
        ],
        nightMarketEndsAt: t2,
        nightMarketUpdatedAt: t1,
        featuredBundle: BundleEntry(bundleUuid: 'b', price: 7100),
        featuredBundleUpdatedAt: t1,
      );
      final r = CurrentShop.fromJson(shop.toJson());
      expect(r.daily.single.skinUuid, 'a');
      expect(r.daily.single.price, 1275);
      expect(r.dailyExpiresAt, t2);
      expect(r.dailyUpdatedAt, t1);
      expect(r.nightMarket.single.skinUuid, 'c');
      expect(r.nightMarket.single.originalPrice, 1775);
      expect(r.nightMarket.single.discountedPrice, 900);
      expect(r.nightMarketEndsAt, t2);
      expect(r.nightMarketUpdatedAt, t1);
      expect(r.featuredBundle!.bundleUuid, 'b');
      expect(r.featuredBundle!.price, 7100);
      expect(r.featuredBundleUpdatedAt, t1);
    });

    test('CurrentShop clear 方法把區塊設回空', () {
      final shop = CurrentShop(
        daily: [ShopEntry(skinUuid: 'a', price: 1)],
        dailyExpiresAt: t2,
        dailyUpdatedAt: t1,
        nightMarket: [NightMarketEntry(skinUuid: 'c', originalPrice: 2, discountedPrice: 1)],
        nightMarketEndsAt: t2,
        nightMarketUpdatedAt: t1,
        featuredBundle: BundleEntry(bundleUuid: 'b', price: 1),
        featuredBundleUpdatedAt: t1,
      );
      final d = shop.clearDaily();
      expect(d.daily, isEmpty);
      expect(d.dailyExpiresAt, isNull);
      expect(d.dailyUpdatedAt, isNull);
      expect(d.nightMarket, isNotEmpty);
      final n = shop.clearNightMarket();
      expect(n.nightMarket, isEmpty);
      expect(n.nightMarketEndsAt, isNull);
      expect(n.daily, isNotEmpty);
      final b = shop.clearFeaturedBundle();
      expect(b.featuredBundle, isNull);
      expect(b.featuredBundleUpdatedAt, isNull);
    });

    test('WishlistItem', () {
      final r = WishlistItem.fromJson(WishlistItem(skinUuid: 'a', addedAt: t1).toJson());
      expect(r.skinUuid, 'a');
      expect(r.addedAt, t1);
    });

    test('AppSettings', () {
      final s = AppSettings(
        notifyEnabled: true,
        notifyHour: 21,
        notifyMinute: 30,
        highlightWishlist: false,
      );
      final r = AppSettings.fromJson(s.toJson());
      expect(r.notifyEnabled, true);
      expect(r.notifyHour, 21);
      expect(r.notifyMinute, 30);
      expect(r.highlightWishlist, false);
    });
  });

  test('Tier.fromDevName 對應', () {
    expect(Tier.fromDevName('Ultra'), Tier.ultra);
    expect(Tier.fromDevName('Select'), Tier.select);
    expect(Tier.fromDevName(null), isNull);
    expect(Tier.fromDevName('Unknown'), isNull);
    expect(Tier.premium.label, '尊爵');
  });

  test('AppSettings 預設值', () {
    final s = AppSettings();
    expect(s.notifyEnabled, false);
    expect(s.notifyHour, 8);
    expect(s.notifyMinute, 0);
    expect(s.highlightWishlist, true);
  });
}
