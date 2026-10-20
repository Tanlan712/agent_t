import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/models/current_shop.dart';
import 'package:valorant_shop_tracker/providers/catalog_provider.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/providers/shop_provider.dart';
import 'package:valorant_shop_tracker/services/catalog_api.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';
import 'package:valorant_shop_tracker/storage/catalog_cache.dart';
import 'package:valorant_shop_tracker/storage/shop_storage.dart';

import '../fixtures.dart';
import '../riot_fixtures.dart';

void main() {
  group('區域', shardTests);
  group('審查修正', reviewFixTests);
  final now = DateTime(2026, 10, 20, 10);
  late ShopProvider shop;
  late CatalogProvider catalog;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    shop = ShopProvider(ShopStorage(prefs));
    catalog = CatalogProvider(
        CatalogApi(client: MockClient(fixtureHandler)), CatalogCache(prefs));
    await catalog.init();
  });

  RiotProvider provider(http.Client client) =>
      RiotProvider(RiotClient(client: client), now: () => now);

  test('貼錯網址：回傳提示且不送出請求', () async {
    final requests = <http.Request>[];
    final p = provider(riotClient(requests: requests));
    final error = await p.login('https://playvalorant.com/opt_in');
    expect(error, RiotProvider.badUrlMessage);
    expect(requests, isEmpty);
    expect(p.isLoggedIn, isFalse);
  });

  test('登入成功', () async {
    final p = provider(riotClient());
    expect(await p.login(fakeRedirect), isNull);
    expect(p.isLoggedIn, isTrue);
    expect(p.session!.displayName, 'Tester#TW1');
  });

  test('同步：商店、錢包、已擁有', () async {
    final p = provider(riotClient());
    await p.login(fakeRedirect);
    expect(await p.sync(shop: shop, catalog: catalog), isNull);
    expect(shop.shop.daily.first.skinUuid, 'skin-odin');
    expect(shop.shop.daily.length, 4);
    expect(shop.shop.featuredBundle!.bundleUuid, 'bundle-rgx');
    expect(p.wallet!.vp, 1500);
    expect(p.ownedSkinUuids, {'skin-odin', 'lvl-not-in-catalog'});
    expect(p.isOwned('skin-odin'), isTrue);
  });

  test('storefront 401：登出且商店不變', () async {
    final p = provider(riotClient(storefrontV3Status: 401));
    await p.login(fakeRedirect);
    final before =
        const CurrentShop(daily: [ShopEntry(skinUuid: 'keep', price: 1)]);
    await shop.replaceShop(before);
    final error = await p.sync(shop: shop, catalog: catalog);
    expect(error, RiotProvider.expiredMessage);
    expect(p.isLoggedIn, isFalse);
    expect(shop.shop.daily.single.skinUuid, 'keep');
  });

  test('token 過期後視為未登入', () async {
    var t = now;
    final p = RiotProvider(RiotClient(client: riotClient()), now: () => t);
    await p.login(fakeRedirect);
    t = now.add(const Duration(hours: 2));
    expect(p.isLoggedIn, isFalse);
  });

  test('登出清除 session 與資料', () async {
    final p = provider(riotClient());
    await p.login(fakeRedirect);
    await p.sync(shop: shop, catalog: catalog);
    p.logout();
    expect(p.session, isNull);
    expect(p.wallet, isNull);
    expect(p.ownedSkinUuids, isEmpty);
  });
}

void reviewFixTests() {
  final now = DateTime(2026, 10, 20, 10);

  test('token 過期後不再顯示已擁有與錢包', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final shop = ShopProvider(ShopStorage(prefs));
    final catalog = CatalogProvider(
        CatalogApi(client: MockClient(fixtureHandler)), CatalogCache(prefs));
    await catalog.init();
    var t = now;
    final p = RiotProvider(RiotClient(client: riotClient()), now: () => t);
    await p.login(fakeRedirect);
    await p.sync(shop: shop, catalog: catalog);
    expect(p.isOwned('skin-odin'), isTrue);
    t = now.add(const Duration(hours: 2));
    expect(p.isOwned('skin-odin'), isFalse);
    expect(p.wallet, isNull);
    expect(p.ownedSkinUuids, isEmpty);
  });

  test('重新登入時清掉前一個帳號的資料', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final shop = ShopProvider(ShopStorage(prefs));
    final catalog = CatalogProvider(
        CatalogApi(client: MockClient(fixtureHandler)), CatalogCache(prefs));
    await catalog.init();
    final p = RiotProvider(RiotClient(client: riotClient()), now: () => now);
    await p.login(fakeRedirect);
    await p.sync(shop: shop, catalog: catalog);
    await p.login(fakeRedirect);
    expect(p.isOwned('skin-odin'), isFalse);
    expect(p.wallet, isNull);
  });

  test('登入時連線失敗顯示登入失敗', () async {
    final p = RiotProvider(
        RiotClient(
            client:
                MockClient((_) async => throw http.ClientException('offline'))),
        now: () => now);
    final error = await p.login(fakeRedirect);
    expect(error, startsWith('登入失敗：'));
  });

  test('登入時 401 顯示登入資訊無效', () async {
    final p = RiotProvider(
        RiotClient(client: MockClient((_) async => http.Response('', 401))),
        now: () => now);
    expect(await p.login(fakeRedirect), RiotProvider.invalidLoginMessage);
    expect(p.isLoggedIn, isFalse);
  });
}

void shardTests() {
  test('login 傳入的區域在偵測失敗時生效', () async {
    final p = RiotProvider(RiotClient(client: riotClient(corsBlocked: true)),
        now: () => DateTime(2026, 10, 20, 10));
    expect(await p.login(fakeRedirect, fallbackShard: 'kr'), isNull);
    expect(p.session!.shard, 'kr');
  });
}
