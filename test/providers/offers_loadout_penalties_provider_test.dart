import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/models/skin_info.dart';
import 'package:valorant_shop_tracker/models/tier.dart';
import 'package:valorant_shop_tracker/providers/catalog_provider.dart';
import 'package:valorant_shop_tracker/providers/offer_price_provider.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/providers/riot_resource.dart';
import 'package:valorant_shop_tracker/providers/shop_provider.dart';
import 'package:valorant_shop_tracker/services/catalog_api.dart';
import 'package:valorant_shop_tracker/services/riot_auth.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';
import 'package:valorant_shop_tracker/storage/catalog_cache.dart';
import 'package:valorant_shop_tracker/storage/offer_price_storage.dart';
import 'package:valorant_shop_tracker/storage/shop_storage.dart';

import '../fixtures.dart';
import '../riot_fixtures.dart';

const _odin = SkinInfo(
    uuid: 'skin-odin',
    name: '奧丁',
    weaponName: '奧丁',
    tier: Tier.deluxe,
    levelUuid: 'lvl-odin');

Future<ShopProvider> _shop() async =>
    ShopProvider(ShopStorage(await SharedPreferences.getInstance()));

Future<CatalogProvider> _catalog() async {
  final c = CatalogProvider(CatalogApi(client: MockClient(fixtureHandler)),
      CatalogCache(await SharedPreferences.getInstance()));
  await c.init();
  return c;
}

void main() {
  test('RiotClient：目前裝備（v3）、排隊懲罰都只用 GET，路徑正確並帶 pd 標頭', () async {
    final requests = <http.Request>[];
    final c = RiotClient(client: riotClient(requests: requests));
    final s = await c.createSession(
        parseRiotRedirect(fakeRedirect)!, DateTime(2026, 10, 22));
    expect((await c.fetchLoadout(s)).cardId, 'card-1');
    expect((await c.fetchPenalties(s)).penalties, isEmpty);
    final pd = requests.where((r) => r.url.host == 'pd.ap.a.pvp.net').toList();
    expect([
      for (final r in pd) '${r.method} ${r.url.path}'
    ], [
      'GET /personalization/v3/players/puuid-1/playerloadout',
      'GET /restrictions/v3/penalties',
    ]);
    for (final r in pd) {
      expect(r.headers['X-Riot-Entitlements-JWT'], 'fake-ent');
    }
  });

  group('OfferPriceProvider', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('同步商店時記下看到的價格並存進快取；不另外送定價請求', () async {
      final requests = <http.Request>[];
      final client = RiotClient(client: riotClient(requests: requests));
      final riot = RiotProvider(client);
      final prices = OfferPriceProvider(OfferPriceStorage(prefs),
          now: () => DateTime(2026, 10, 22, 12));
      riot.onStorefront = prices.record;
      expect(prices.priceOf(_odin), isNull);
      await riot.login(fakeRedirect);
      await riot.sync(shop: await _shop(), catalog: await _catalog());
      expect(prices.priceOf(_odin), 1275);
      expect(OfferPriceStorage(prefs).load()!.vp['lvl-noicon'], 2475);
      expect(requests.where((r) => r.url.path.contains('offers')), isEmpty);

      // 登出後、重新開頁仍可讀上次記下的價格。
      riot.logout();
      expect(OfferPriceProvider(OfferPriceStorage(prefs)).priceOf(_odin), 1275);
    });

    test('沒有新價格時不寫入；新價格蓋掉舊的', () async {
      final prices = OfferPriceProvider(OfferPriceStorage(prefs));
      await prices.record(const {});
      expect(prefs.getString(OfferPriceStorage.key), isNull);
      Map<String, dynamic> daily(int price) => {
            'SkinsPanelLayout': {
              'SingleItemStoreOffers': [
                {
                  'Cost': {'85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741': price},
                  'Rewards': [
                    {'ItemID': 'lvl-odin'}
                  ],
                },
              ],
            },
          };
      await prices.record(daily(1275));
      await prices.record(daily(1775));
      expect(prices.priceOf(_odin), 1775);
    });
  });

  group('RiotResource（目前裝備、排隊懲罰）', () {
    Future<(LoadoutProvider, PenaltyProvider, RiotProvider, List<http.Request>)>
        make({int loadoutStatus = 200, int penaltiesStatus = 200}) async {
      final requests = <http.Request>[];
      final client = RiotClient(
          client: riotClient(
              requests: requests,
              loadoutStatus: loadoutStatus,
              penaltiesStatus: penaltiesStatus,
              penalties: [
            {'QueueDelayEffect': {}},
          ]));
      final riot = RiotProvider(client);
      await riot.login(fakeRedirect);
      return (
        LoadoutProvider(riot, client, delay: (_) async {}),
        PenaltyProvider(riot, client, delay: (_) async {}),
        riot,
        requests,
      );
    }

    test('載入一次後快取；refresh 重抓；登出清空', () async {
      final (loadout, penalties, riot, r) = await make();
      await loadout.load();
      await loadout.load();
      await penalties.load();
      expect(loadout.value!.guns, hasLength(2));
      expect(penalties.value!.penalties.single.effects, ['排隊延遲']);
      int calls(String p) => r.where((e) => e.url.path == p).length;
      const lp = '/personalization/v3/players/puuid-1/playerloadout';
      expect(calls(lp), 1);
      await loadout.refresh();
      expect(calls(lp), 2);
      riot.logout();
      expect(loadout.value, isNull);
      expect(penalties.value, isNull);
    });

    test('失敗顯示錯誤，授權失敗時登出', () async {
      final (loadout, _, _, _) = await make(loadoutStatus: 500);
      await loadout.load();
      expect(loadout.error, contains('取得目前裝備'));
      expect(loadout.value, isNull);

      final (_, penalties, riot, _) = await make(penaltiesStatus: 403);
      await penalties.load();
      expect(riot.isLoggedIn, isFalse);
      expect(penalties.error, isNull);
    });
  });
}
