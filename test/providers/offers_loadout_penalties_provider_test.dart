import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/models/skin_info.dart';
import 'package:valorant_shop_tracker/models/tier.dart';
import 'package:valorant_shop_tracker/providers/offer_price_provider.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/providers/riot_resource.dart';
import 'package:valorant_shop_tracker/services/riot_auth.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';
import 'package:valorant_shop_tracker/storage/offer_price_storage.dart';

import '../riot_fixtures.dart';

const _odin = SkinInfo(
    uuid: 'skin-odin',
    name: '奧丁',
    weaponName: '奧丁',
    tier: Tier.deluxe,
    levelUuid: 'lvl-odin');

void main() {
  test('RiotClient：定價、目前裝備、排隊懲罰都只用 GET，路徑正確並帶 pd 標頭', () async {
    final requests = <http.Request>[];
    final c = RiotClient(client: riotClient(requests: requests));
    final s = await c.createSession(
        parseRiotRedirect(fakeRedirect)!, DateTime(2026, 10, 22));
    final now = DateTime(2026, 10, 22, 12);
    expect((await c.fetchOffers(s, now)).priceOf('lvl-odin'), 1275);
    expect((await c.fetchLoadout(s)).cardId, 'card-1');
    expect((await c.fetchPenalties(s)).penalties, isEmpty);
    final pd = requests.where((r) => r.url.host == 'pd.ap.a.pvp.net').toList();
    expect([
      for (final r in pd) '${r.method} ${r.url.path}'
    ], [
      'GET /store/v1/offers/',
      'GET /personalization/v2/players/puuid-1/playerloadout',
      'GET /restrictions/v3/penalties',
    ]);
    for (final r in pd) {
      expect(r.headers['X-Riot-Entitlements-JWT'], 'fake-ent');
    }
  });

  group('OfferPriceProvider', () {
    late SharedPreferences prefs;
    var now = DateTime(2026, 10, 22, 12);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      now = DateTime(2026, 10, 22, 12);
    });

    Future<(OfferPriceProvider, RiotProvider, List<http.Request>)> make(
        {int status = 200, bool login = true}) async {
      final requests = <http.Request>[];
      final client = RiotClient(
          client: riotClient(requests: requests, offersStatus: status));
      final riot = RiotProvider(client);
      if (login) await riot.login(fakeRedirect);
      final p = OfferPriceProvider(riot, client, OfferPriceStorage(prefs),
          now: () => now, delay: (_) async {});
      return (p, riot, requests);
    }

    int offerCalls(List<http.Request> r) =>
        r.where((e) => e.url.path == '/store/v1/offers/').length;

    test('登入後載入並存進快取；未登入不送請求', () async {
      final (idle, _, r0) = await make(login: false);
      await idle.load();
      expect(offerCalls(r0), 0);
      expect(idle.priceOf(_odin), isNull);

      final (p, _, r) = await make();
      await p.load();
      expect(p.priceOf(_odin), 1275);
      expect(offerCalls(r), 1);
      expect(OfferPriceStorage(prefs).load()!.vp['lvl-odin'], 1275);
    });

    test('24 小時內不重抓；超過或 force 才重抓；登出後仍可讀快取', () async {
      final (p, riot, r) = await make();
      await p.load();
      now = now.add(const Duration(hours: 23));
      await p.load();
      expect(offerCalls(r), 1);
      await p.load(force: true);
      expect(offerCalls(r), 2);
      now = now.add(const Duration(hours: 25));
      await p.load();
      expect(offerCalls(r), 3);

      riot.logout();
      final (fresh, _, _) = await make(login: false);
      expect(fresh.priceOf(_odin), 1275);
    });

    test('失敗時保留舊價格並顯示錯誤；授權失敗時登出', () async {
      final (ok, _, _) = await make();
      await ok.load();
      now = now.add(const Duration(days: 2));
      final (bad, _, _) = await make(status: 500);
      expect(bad.priceOf(_odin), 1275);
      await bad.load();
      expect(bad.priceOf(_odin), 1275);
      expect(bad.error, contains('取得定價'));

      final (auth, riot, _) = await make(status: 401);
      await auth.load();
      expect(riot.isLoggedIn, isFalse);
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
      const lp = '/personalization/v2/players/puuid-1/playerloadout';
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
