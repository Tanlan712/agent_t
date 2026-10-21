import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/app_routes.dart';
import 'package:valorant_shop_tracker/models/current_shop.dart';
import 'package:valorant_shop_tracker/models/match_models.dart';
import 'package:valorant_shop_tracker/models/wishlist_item.dart';
import 'package:valorant_shop_tracker/providers/catalog_provider.dart';
import 'package:valorant_shop_tracker/providers/match_detail_cache.dart';
import 'package:valorant_shop_tracker/providers/match_history_provider.dart';
import 'package:valorant_shop_tracker/providers/match_reference_provider.dart';
import 'package:valorant_shop_tracker/providers/recent_form_loader.dart';
import 'package:valorant_shop_tracker/providers/collection_provider.dart';
import 'package:valorant_shop_tracker/providers/progress_provider.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/services/progress_reference_api.dart';
import 'package:valorant_shop_tracker/providers/seen_players_provider.dart';
import 'package:valorant_shop_tracker/providers/settings_provider.dart';
import 'package:valorant_shop_tracker/providers/shop_provider.dart';
import 'package:valorant_shop_tracker/providers/wishlist_provider.dart';
import 'package:valorant_shop_tracker/services/live_client.dart';
import 'package:valorant_shop_tracker/services/match_client.dart';
import 'package:valorant_shop_tracker/services/match_reference_api.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';
import 'package:valorant_shop_tracker/storage/match_reference_cache.dart';
import 'package:valorant_shop_tracker/theme/app_theme.dart';
import 'package:valorant_shop_tracker/storage/seen_players_storage.dart';
import 'package:valorant_shop_tracker/storage/settings_storage.dart';
import 'package:valorant_shop_tracker/storage/shop_storage.dart';
import 'package:valorant_shop_tracker/storage/wishlist_storage.dart';

import 'catalog_helpers.dart';
import 'match_fixtures.dart';
import 'riot_fixtures.dart';

/// 對戰頁面測試用的參考資料（預先寫入快取，不連網）。
const testMatchReference = MatchReference(
  agents: {
    'agent-$myPuuid': RefItem(name: '蓋克'),
    'agent-mate': RefItem(name: '菲德'),
  },
  maps: {'/Game/Maps/Ascent/Ascent': RefItem(name: '亞海懸城')},
  tiers: {
    0: RefItem(name: '牌階未定'),
    18: RefItem(name: '鑽石 2'),
    12: RefItem(name: '白金 1'),
    21: RefItem(name: '超凡 1'),
  },
);

/// 測試用的整組 providers，已預先寫入商店／願望清單資料。
class Harness {
  final CatalogProvider catalog;
  final ShopProvider shop;
  final WishlistProvider wishlist;
  final SettingsProvider settings;
  final RiotProvider riot;
  final MatchHistoryProvider matchHistory;
  final MatchReferenceProvider matchReference;
  final SharedPreferences prefs;
  final MatchClient matchClient;
  final MatchDetailCache matchCache;
  final SeenPlayersProvider seenPlayers;
  final LiveClient liveClient;
  late final CollectionProvider collection;
  late final ProgressProvider progress;
  late final RecentFormLoader recentForm =
      RecentFormLoader(matchClient, riot, matchCache);

  Harness(
      this.catalog,
      this.shop,
      this.wishlist,
      this.settings,
      this.riot,
      this.matchHistory,
      this.matchReference,
      this.prefs,
      this.matchClient,
      this.matchCache,
      this.seenPlayers,
      this.liveClient);

  static Future<Harness> create(
    WidgetTester tester, {
    CurrentShop shop = const CurrentShop(),
    List<String> wishlist = const [],
    CatalogProvider? catalog,
    http.Client? riotHttp,
    int matchPageSize = 10,
    DateTime Function()? now,
    ProgressReferenceApi? progressApi,
  }) async {
    final c = catalog ?? await loadedCatalog(tester);
    final prefs = await SharedPreferences.getInstance();
    await ShopStorage(prefs).save(shop);
    await WishlistStorage(prefs).save([
      for (final id in wishlist)
        WishlistItem(skinUuid: id, addedAt: DateTime(2026, 10, 1)),
    ]);
    final rc = RiotClient(client: riotHttp ?? riotClient());
    final riot = RiotProvider(rc, now: now ?? DateTime.now);
    final refCache = MatchReferenceCache(prefs);
    await refCache.save(testMatchReference);
    final reference = MatchReferenceProvider(
        MatchReferenceApi(client: riotHttp ?? riotClient()), refCache);
    await reference.init();
    final matchClient = MatchClient(rc);
    final matchCache = MatchDetailCache();
    final seenPlayers = SeenPlayersProvider(SeenPlayersStorage(prefs));
    final h = Harness(
      c,
      ShopProvider(ShopStorage(prefs)),
      WishlistProvider(WishlistStorage(prefs)),
      SettingsProvider(SettingsStorage(prefs)),
      riot,
      MatchHistoryProvider(matchClient, riot,
          cache: matchCache,
          pageSize: matchPageSize,
          onDetails: seenPlayers.recordAll),
      reference,
      prefs,
      matchClient,
      matchCache,
      seenPlayers,
      LiveClient(rc),
    );
    // 測試不真的等待退避。
    h.collection = CollectionProvider(riot, rc, delay: (_) async {});
    h.progress = ProgressProvider(riot, rc,
        progressApi ?? ProgressReferenceApi(client: riotHttp ?? riotClient()),
        delay: (_) async {});
    return h;
  }

  /// [useAppRoutes] 為 true 時改用 App 的路由表（`onGenerateAppRoute`），從 `/` 開始。
  Widget wrap({
    Widget? home,
    Map<String, WidgetBuilder> routes = const {},
    RouteFactory? onGenerateRoute,
    bool useAppRoutes = false,
    List<NavigatorObserver> observers = const [],
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: catalog),
        ChangeNotifierProvider.value(value: shop),
        ChangeNotifierProvider.value(value: wishlist),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: riot),
        ChangeNotifierProvider.value(value: collection),
        ChangeNotifierProvider.value(value: progress),
        Provider.value(value: matchClient),
        Provider.value(value: liveClient),
        Provider.value(value: matchCache),
        ChangeNotifierProvider.value(value: recentForm),
        ChangeNotifierProvider.value(value: seenPlayers),
        ChangeNotifierProvider.value(value: matchHistory),
        ChangeNotifierProvider.value(value: matchReference),
      ],
      child: useAppRoutes
          ? MaterialApp(
              theme: buildAppTheme(useGoogleFonts: false),
              onGenerateRoute: onGenerateAppRoute,
              navigatorObservers: observers,
            )
          : MaterialApp(
              theme: buildAppTheme(useGoogleFonts: false),
              home: home,
              routes: routes,
              onGenerateRoute: onGenerateRoute,
              navigatorObservers: observers,
            ),
    );
  }
}
