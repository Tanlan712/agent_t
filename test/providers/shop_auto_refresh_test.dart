import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_t/models/current_shop.dart';
import 'package:agent_t/providers/riot_provider.dart';
import 'package:agent_t/providers/shop_auto_refresh.dart';
import 'package:agent_t/providers/shop_provider.dart';
import 'package:agent_t/services/riot_client.dart';
import 'package:agent_t/storage/shop_storage.dart';

import '../catalog_helpers.dart';
import '../riot_fixtures.dart';

/// 可以讓商店請求暫時失敗的 client（失敗時回 500）。
class _Gate extends http.BaseClient {
  final http.Client inner;
  final List<http.Request> log;
  bool failStorefront = false;
  _Gate(this.inner, this.log);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (failStorefront && request.url.path.contains('/storefront/')) {
      log.add(request as http.Request);
      return http.StreamedResponse(Stream.value(const []), 500);
    }
    return inner.send(request);
  }
}

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
    int dailyRemaining = 3600,
    http.Client Function(List<http.Request> requests)? clientFor,
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
            client: clientFor?.call(requests) ??
                riotClient(
                    requests: requests,
                    storefrontV3Status: storefrontStatus,
                    storefrontV2Status: storefrontStatus,
                    dailyRemaining: dailyRemaining)),
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

  testWidgets('Riot 還沒換新商店（剩餘時間 0）時，重試用完就停，30 分鐘內不再同步', (tester) async {
    await setup(tester, dailyRemaining: 0);
    await advance(tester, const Duration(seconds: 45));
    final first = storefrontCalls();
    expect(first, greaterThan(0));
    for (var i = 0; i < 10; i++) {
      await advance(tester, const Duration(minutes: 1));
    }
    // 第一次＋最多 3 次重試。
    expect(storefrontCalls(), lessThanOrEqualTo(first * 4));
    final afterRetries = storefrontCalls();
    for (var i = 0; i < 15; i++) {
      await advance(tester, const Duration(minutes: 1));
    }
    expect(storefrontCalls(), afterRetries);
    current.dispose();
  });

  testWidgets('重試前商店已經被別的同步更新，就不再同步', (tester) async {
    late _Gate gate;
    final (_, shop, _) = await setup(tester,
        clientFor: (r) => gate = _Gate(riotClient(requests: r), r));
    gate.failStorefront = true;
    await advance(tester, const Duration(seconds: 45));
    final first = storefrontCalls();
    expect(first, greaterThan(0));
    // 例如使用者手動同步成功：商店換新。
    await tester.runAsync(() => shop.replaceShop(CurrentShop(
          daily: const [ShopEntry(skinUuid: 'o', price: 1275)],
          dailyExpiresAt: clock.add(const Duration(hours: 23)),
        )));
    gate.failStorefront = false;
    for (var i = 0; i < 5; i++) {
      await advance(tester, const Duration(minutes: 1));
    }
    expect(storefrontCalls(), first);
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
