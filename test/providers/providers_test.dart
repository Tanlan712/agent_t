
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/models/current_shop.dart';
import 'package:valorant_shop_tracker/models/skin_catalog.dart';
import 'package:valorant_shop_tracker/providers/catalog_provider.dart';
import 'package:valorant_shop_tracker/providers/settings_provider.dart';
import 'package:valorant_shop_tracker/providers/shop_provider.dart';
import 'package:valorant_shop_tracker/providers/wishlist_provider.dart';
import 'package:valorant_shop_tracker/services/catalog_api.dart';
import 'package:valorant_shop_tracker/storage/catalog_cache.dart';
import 'package:valorant_shop_tracker/storage/settings_storage.dart';
import 'package:valorant_shop_tracker/storage/shop_storage.dart';
import 'package:valorant_shop_tracker/storage/wishlist_storage.dart';

import '../fixtures.dart';

void main() {
  late SharedPreferences prefs;
  final now = DateTime(2026, 10, 19, 10);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('CatalogProvider', () {
    late int requests;
    late bool failing;
    late CatalogProvider provider;

    setUp(() {
      requests = 0;
      failing = false;
      final client = MockClient((req) {
        requests++;
        if (failing) return Future.value(http.Response('down', 503));
        return fixtureHandler(req);
      });
      provider = CatalogProvider(
        CatalogApi(client: client, now: () => now),
        CatalogCache(prefs),
      );
    });

    test('沒有快取時 init 下載並存入快取', () async {
      await provider.init();
      expect(provider.catalog!.skins.length, 2);
      expect(CatalogCache(prefs).load(), isNotNull);
      expect(provider.skinById('skin-odin')!.name, '凌空之志 奧丁');
      expect(provider.bundleById('bundle-rgx')!.name, 'RGX 11z Pro');
      expect(provider.weaponNames, ['奧丁']);
    });

    test('有快取時 init 不呼叫 API', () async {
      await CatalogCache(prefs)
          .save(SkinCatalog(skins: const [], bundles: const [], fetchedAt: now));
      await provider.init();
      expect(requests, 0);
      expect(provider.catalog, isNotNull);
    });

    test('有快取時 refresh 失敗 → usingStaleCache', () async {
      await provider.init();
      failing = true;
      await provider.refresh();
      expect(provider.usingStaleCache, isTrue);
      expect(provider.catalog!.skins.length, 2);
      expect(provider.error, isNull);
    });

    test('沒有快取又下載失敗 → error', () async {
      failing = true;
      await provider.init();
      expect(provider.catalog, isNull);
      expect(provider.error, '無法下載造型資料，請檢查網路後重試');
      expect(provider.isLoading, isFalse);
    });

    test('快取寫入失敗仍採用新目錄', () async {
      final p = CatalogProvider(
        CatalogApi(client: MockClient(fixtureHandler), now: () => now),
        _FailingSaveCache(prefs),
      );
      await p.init();
      expect(p.catalog!.skins.length, 2);
      expect(p.error, isNull);
      expect(p.usingStaleCache, isFalse);
    });
  });

  group('ShopProvider', () {
    List<ShopEntry> entries(List<String> ids) =>
        ids.map((id) => ShopEntry(skinUuid: id, price: 875)).toList();
    final expires = DateTime(2026, 10, 20, 8);

    test('每日不足 4 筆丟出 ArgumentError', () async {
      final p = ShopProvider(ShopStorage(prefs));
      expect(() => p.saveDaily(entries(['a', 'b', 'c']), expires, now),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message', '每日商店需要 4 個造型')));
    });

    test('重複造型丟出 ArgumentError', () async {
      final p = ShopProvider(ShopStorage(prefs));
      expect(() => p.saveDaily(entries(['a', 'a', 'c', 'd']), expires, now),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message', '同一造型不能重複')));
    });

    test('夜市不足 6 筆丟出 ArgumentError', () async {
      final p = ShopProvider(ShopStorage(prefs));
      final night = List.generate(
          5, (i) => NightMarketEntry(skinUuid: '$i', originalPrice: 2, discountedPrice: 1));
      expect(() => p.saveNightMarket(night, expires, now), throwsArgumentError);
    });

    test('儲存後重新建立 provider 仍讀得到', () async {
      final p = ShopProvider(ShopStorage(prefs));
      var notified = 0;
      p.addListener(() => notified++);
      await p.saveDaily(entries(['a', 'b', 'c', 'd']), expires, now);
      expect(notified, 1);
      final again = ShopProvider(ShopStorage(prefs));
      expect(again.shop.daily.map((e) => e.skinUuid), ['a', 'b', 'c', 'd']);
      expect(again.shop.dailyExpiresAt, expires);
      expect(again.shop.dailyUpdatedAt, now);
    });

    test('clearDaily 清空每日區塊', () async {
      final p = ShopProvider(ShopStorage(prefs));
      await p.saveDaily(entries(['a', 'b', 'c', 'd']), expires, now);
      await p.saveFeaturedBundle(const BundleEntry(bundleUuid: 'b', price: 7100), now);
      await p.clearDaily();
      expect(p.shop.daily, isEmpty);
      expect(p.shop.dailyExpiresAt, isNull);
      expect(p.shop.featuredBundle, isNotNull);
      expect(ShopProvider(ShopStorage(prefs)).shop.daily, isEmpty);
    });
  });

  group('WishlistProvider', () {
    test('同一造型不重複加入、可移除', () async {
      final p = WishlistProvider(WishlistStorage(prefs), now: () => now);
      await p.add('a');
      await p.add('a');
      expect(p.items.length, 1);
      expect(p.uuids, {'a'});
      expect(WishlistProvider(WishlistStorage(prefs)).contains('a'), isTrue);
      await p.remove('a');
      expect(p.contains('a'), isFalse);
    });
  });

  group('SettingsProvider', () {
    test('setResetTime 存檔', () async {
      final p = SettingsProvider(SettingsStorage(prefs));
      await p.setResetTime(9, 15);
      expect(p.settings.resetHour, 9);
      expect(SettingsStorage(prefs).load().resetHour, 9);
      expect(SettingsStorage(prefs).load().resetMinute, 15);
    });

    test('setHighlightWishlist 存檔', () async {
      final p = SettingsProvider(SettingsStorage(prefs));
      await p.setHighlightWishlist(false);
      expect(SettingsStorage(prefs).load().highlightWishlist, isFalse);
    });
  });
}

/// save 一律失敗的快取，模擬 localStorage 容量不足。
class _FailingSaveCache extends CatalogCache {
  _FailingSaveCache(super.prefs);

  @override
  Future<void> save(SkinCatalog catalog) async =>
      throw StateError('QuotaExceededError');
}
