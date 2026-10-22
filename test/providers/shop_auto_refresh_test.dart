import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/models/current_shop.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/providers/shop_auto_refresh.dart';
import 'package:valorant_shop_tracker/providers/shop_provider.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';
import 'package:valorant_shop_tracker/storage/shop_storage.dart';

import '../catalog_helpers.dart';
import '../riot_fixtures.dart';

void main() {
  late DateTime clock;
  late List<http.Request> requests;
  late ShopAutoRefresher current;

  int storefrontCalls() =>
      requests.where((r) => r.url.path.contains('/storefront/')).length;

  Future<(RiotProvider, ShopProvider, ShopAutoRefresher)> setup(
    WidgetTester tester, {
    Duration dailyLeft = const Duration(seconds: 10),
    Duration? nightLeft,
    int storefrontStatus = 200,
  }) async {
    clock = DateTime(2026, 10, 22, 7, 59, 50);
    requests = [];
    final catalog = await loadedCatalog(tester);
    final prefs = await SharedPreferences.getInstance();
    final shop = ShopProvider(ShopStorage(prefs));
    await tester.runAsync(() => shop.replaceShop(CurrentShop(
          daily: const [ShopEntry(skinUuid: 'o', price: 1275)],
          dailyExpiresAt: clock.add(dailyLeft),
          nightMarket: nightLeft == null
              ? const []
              : const [
                  NightMarketEntry(
                      skinUuid: 'p', originalPrice: 1775, discountedPrice: 900)
                ],
          nightMarketEndsAt: nightLeft == null ? null : clock.add(nightLeft),
        )));
    final riot = RiotProvider(
        RiotClient(
            client: riotClient(
                requests: requests,
                storefrontV3Status: storefrontStatus,
                storefrontV2Status: storefrontStatus)),
        now: () => clock);
    await tester.runAsync(() => riot.login(fakeRedirect));
    requests.clear();
    final r = ShopAutoRefresher(riot, shop, catalog, now: () => clock);
    current = r;
    return (riot, shop, r);
  }

  /// 前進 [d]（時鐘與計時器一起），再讓網路請求完成。
  Future<void> advance(WidgetTester tester, Duration d) async {
    clock = clock.add(d);
    await tester.pump(d);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }

  testWidgets('每日商店到期後 30 秒自動同步一次', (tester) async {
    final (_, shop, _) = await setup(tester);
    await advance(tester, const Duration(seconds: 30));
    expect(storefrontCalls(), 0, reason: '還沒到 到期＋30 秒');
    await advance(tester, const Duration(seconds: 15));
    expect(storefrontCalls(), 1);
    // 同步後換成新的商店，到期時間往後。
    expect(shop.shop.dailyExpiresAt!.isAfter(clock), isTrue);
    await advance(tester, const Duration(minutes: 5));
    expect(storefrontCalls(), 1, reason: '新商店還沒到期，不再同步');
    current.dispose();
  });

  testWidgets('同步失敗（仍是舊商店）時 1 分鐘後重試，最多 3 次', (tester) async {
    await setup(tester, storefrontStatus: 500);
    await advance(tester, const Duration(seconds: 45));
    final first = storefrontCalls();
    expect(first, greaterThan(0));
    for (var i = 0; i < 5; i++) {
      await advance(tester, const Duration(minutes: 1));
    }
    // 第一次＋3 次重試（每次同步可能先試 v3 再試 v2，所以用倍數比較）。
    expect(storefrontCalls(), first * 4);
    current.dispose();
  });

  testWidgets('夜市結束後也自動同步', (tester) async {
    await setup(tester,
        dailyLeft: const Duration(hours: 5),
        nightLeft: const Duration(seconds: 10));
    await advance(tester, const Duration(seconds: 45));
    expect(storefrontCalls(), greaterThan(0));
    current.dispose();
  });

  testWidgets('登出後不自動同步', (tester) async {
    final (riot, _, _) = await setup(tester);
    riot.logout();
    await advance(tester, const Duration(seconds: 45));
    expect(storefrontCalls(), 0);
    current.dispose();
  });
}
