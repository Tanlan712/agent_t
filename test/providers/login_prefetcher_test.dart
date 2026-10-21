import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/providers/catalog_provider.dart';
import 'package:valorant_shop_tracker/providers/shop_provider.dart';
import 'package:valorant_shop_tracker/services/catalog_api.dart';
import 'package:valorant_shop_tracker/storage/catalog_cache.dart';
import 'package:valorant_shop_tracker/storage/shop_storage.dart';
import 'package:valorant_shop_tracker/providers/collection_provider.dart';
import 'package:valorant_shop_tracker/providers/login_prefetcher.dart';
import 'package:valorant_shop_tracker/providers/progress_provider.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';

import '../fixtures.dart';
import '../progress_fixtures.dart';
import '../riot_fixtures.dart';

/// 記錄 pd 同時進行中的請求數。
class _Counting extends http.BaseClient {
  final http.Client inner = riotClient(entitlements: {
    ItemTypes.spray: ['spray-1'],
  });
  int inFlight = 0;
  int maxInFlight = 0;
  int pdRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final pd = request.url.host == 'pd.ap.a.pvp.net';
    if (pd) {
      pdRequests++;
      inFlight++;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    try {
      return await inner.send(request);
    } finally {
      if (pd) inFlight--;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ShopProvider, CatalogProvider)> shopAndCatalog(
      {bool loadCatalog = true}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final catalog = CatalogProvider(
        CatalogApi(client: MockClient(fixtureHandler)), CatalogCache(prefs));
    if (loadCatalog) await catalog.init();
    return (ShopProvider(ShopStorage(prefs)), catalog);
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  test('登入後依序預先讀取收藏與通行證，pd 同時最多 2 個請求', () async {
    final http = _Counting();
    final client = RiotClient(client: http);
    final riot = RiotProvider(client);
    final col = CollectionProvider(riot, client, delay: (_) async {});
    final prog =
        ProgressProvider(riot, client, FakeProgressApi(), delay: (_) async {});
    LoginPrefetcher(riot, col, prog);
    expect(col.owned, isEmpty);

    await riot.login(fakeRedirect);
    await settle();
    expect(col.owned[ItemTypes.spray], {'spray-1'});
    expect(prog.xp, isNotNull);
    expect(prog.contracts, isNotNull);
    expect(prog.ref, isNotNull);
    expect(http.maxInFlight, lessThanOrEqualTo(2));
  });

  test('同一個登入只預先讀取一次；之後開頁面不重抓', () async {
    final http = _Counting();
    final client = RiotClient(client: http);
    final riot = RiotProvider(client);
    final col = CollectionProvider(riot, client, delay: (_) async {});
    final prog =
        ProgressProvider(riot, client, FakeProgressApi(), delay: (_) async {});
    LoginPrefetcher(riot, col, prog);
    await riot.login(fakeRedirect);
    await settle();
    final n = http.pdRequests;
    riot.notifyListeners();
    await col.load();
    await prog.load();
    await settle();
    expect(http.pdRequests, n);
  });

  test('未登入時不送出請求', () async {
    final http = _Counting();
    final client = RiotClient(client: http);
    final riot = RiotProvider(client);
    LoginPrefetcher(riot, CollectionProvider(riot, client, delay: (_) async {}),
        ProgressProvider(riot, client, FakeProgressApi(), delay: (_) async {}));
    await settle();
    expect(http.pdRequests, 0);
  });

  test('登出後再登入會重新預先讀取', () async {
    final http = _Counting();
    final client = RiotClient(client: http);
    final riot = RiotProvider(client);
    final col = CollectionProvider(riot, client, delay: (_) async {});
    final prog =
        ProgressProvider(riot, client, FakeProgressApi(), delay: (_) async {});
    LoginPrefetcher(riot, col, prog);
    await riot.login(fakeRedirect);
    await settle();
    riot.logout();
    expect(col.owned, isEmpty);
    await riot.login(fakeRedirect);
    await settle();
    expect(col.owned[ItemTypes.spray], {'spray-1'});
    expect(prog.xp, isNotNull);
  });

  test('登入後（含重新開頁恢復登入）也先同步一次商店與錢包', () async {
    final http = _Counting();
    final client = RiotClient(client: http);
    final riot = RiotProvider(client);
    final (shop, catalog) = await shopAndCatalog();
    LoginPrefetcher(riot, CollectionProvider(riot, client, delay: (_) async {}),
        ProgressProvider(riot, client, FakeProgressApi(), delay: (_) async {}),
        shop: shop, catalog: catalog);
    await riot.login(fakeRedirect);
    await settle();
    expect(riot.wallet, isNotNull);
    expect(riot.wallet!.vp, 1500);
    expect(shop.shop.daily, hasLength(4));
    expect(http.maxInFlight, lessThanOrEqualTo(2));
  });

  test('造型目錄還沒載入時，等目錄好了再同步（商店才對得到造型）', () async {
    final http = _Counting();
    final client = RiotClient(client: http);
    final riot = RiotProvider(client);
    final (shop, catalog) = await shopAndCatalog(loadCatalog: false);
    LoginPrefetcher(riot, CollectionProvider(riot, client, delay: (_) async {}),
        ProgressProvider(riot, client, FakeProgressApi(), delay: (_) async {}),
        shop: shop, catalog: catalog);
    await riot.login(fakeRedirect);
    await settle();
    expect(riot.wallet, isNull);
    await catalog.init();
    await settle();
    expect(riot.wallet, isNotNull);
    expect(shop.shop.daily.first.skinUuid, 'skin-odin');
  });
}
